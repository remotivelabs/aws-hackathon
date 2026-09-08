---
inclusion: fileMatch
fileMatchPattern: ["remotive_car/models/**", "remotive_car/instances/**", "remotive_car/platform/**"]
---

# Writing an ECU behavioral model (pattern used by BCM/GWM)

Reference implementations: `#[[file:remotive_car/models/bcm/python/bcm/__main__.py]]`,
`#[[file:remotive_car/models/gwm/python/gwm/__main__.py]]`.

## Layout for a new ECU `dim`

```
remotive_car/models/dim.bm.instance.yaml      # instance fragment
remotive_car/models/dim/python/pyproject.toml # copy from bcm, rename package
remotive_car/models/dim/python/uv.lock        # generate with `uv lock` - see note below, uv is NOT on the box
remotive_car/models/dim/python/dim/__init__.py
remotive_car/models/dim/python/dim/__main__.py
remotive_car/models/dim/python/dim/log.py     # copy from bcm
remotive_car/models/dim/python/tests/         # pytest unit tests for pure logic
```

`pyproject.toml` essentials (mirror bcm): `dependencies = ["structlog==25.4.0", "remotivelabs-topology~=0.22.0", ...]`,
`[tool.uv.build-backend] module-root = "" / module-name = ["dim"]`, `[tool.ruff] extend = "../../../../ruff.toml"`.
The shared `remotive_car/Dockerfile` stage `model` runs `uv sync --locked`, so `uv.lock` must exist and match.

> **`uv` and `ruff` are not installed on the day-2 box** (verified 2026-09-18). Run them in a
> throwaway container instead — this also works for a model whose `pyproject.toml` you just edited:
>
> ```bash
> cd remotive_car/models/<ecu>/python
> docker run --rm -v "$PWD":/w -w /w python:3.13-slim \
>   sh -c "pip install -q uv==0.9.2 && uv lock"          # or: uv run --frozen pytest -q
> ```
>
> For ruff, `pip install -q ruff==0.11.10` and mount the repo's config at `/ruff.toml`. File ownership
> is preserved. **Always `ruff format --check` after editing model python** — the formatter has
> opinions about line breaks in handler-registration lists.

Instance fragment `remotive_car/models/dim.bm.instance.yaml`:

```yaml
schema: remotive-topology-instance:0.17
platform:
  includes: [../platform/remotive-car.platform.yaml]
ecus:
  DIM:
    models:
      dim:
        type: container
        container:
          build:
            args: [MODEL_PATH=dim/python]
            target: model
            dockerfile: ../Dockerfile
          command: python -m dim
```

Then add `- ../../models/dim.bm.instance.yaml` to `includes:` of the main instance and **remove**
`DIM: {}` from its `ecus:` block if present (a model and a plain entry for the same ECU conflict).

## Skeleton

```python
import asyncio
import structlog
from remotivelabs.broker import BrokerClient, Frame
from remotivelabs.topology.behavioral_model import BehavioralModel
from remotivelabs.topology.cli.behavioral_model import BehavioralModelArgs
from remotivelabs.topology.control import ControlRequest, ControlResponse
from remotivelabs.topology.namespaces import filters
from remotivelabs.topology.namespaces.can import CanNamespace, RestbusConfig
from .log import configure_logging

logger = structlog.get_logger(__name__)

class DIM:
    ecu_name = "DIM"
    body_ns = "DIM-BodyCan0"                     # must be <ECU>-<Channel>

    def __init__(self, avp: BehavioralModelArgs) -> None:
        self._client = BrokerClient(url=avp.url, auth=avp.auth)
        # restbus: cyclically transmit every BodyCan0 frame DIM is sender of in the DBC
        self.body_can = CanNamespace(
            DIM.body_ns, self._client,
            restbus_configs=[RestbusConfig([filters.SenderFilter(ecu_name=DIM.ecu_name)],
                                           delay_multiplier=avp.delay_multiplier)],
        )
        self.bm = BehavioralModel(
            DIM.ecu_name,
            namespaces=[self.body_can],
            broker_client=self._client,
            input_handlers=[
                self.body_can.create_input_handler([filters.FrameFilter("TurnLightControl")], self.on_turn_lights),
            ],
            control_handlers=[("set_mode", self.on_set_mode)],   # optional custom control command
            input_filters=[filters.E2eSignalsFilter(exclude=True)],
            on_change=True,   # False => every cyclic frame is delivered (needed for timeout supervision)
        )

    async def __aenter__(self):
        await self._client.connect(); await self.bm.start(); return self
    async def __aexit__(self, *exc):
        await self.bm.stop(); await self._client.disconnect()
    def __await__(self):
        return self.bm.run_forever().__await__()

    async def on_turn_lights(self, frame: Frame) -> None:
        left = frame.signals["TurnLightControl.LeftTurnLightRequest"]
        await self.body_can.restbus.update_signals(("ClusterTelltales.LeftTurnTelltale", left))

    async def on_set_mode(self, request: ControlRequest) -> ControlResponse:
        logger.info("control", argument=request.argument)
        return ControlResponse(status="ok")

async def main(avp: BehavioralModelArgs):
    async with DIM(avp) as dim:
        await dim

if __name__ == "__main__":
    args = BehavioralModelArgs.parse()
    configure_logging(level=args.loglevel)
    asyncio.run(main(args))
```

Rules of thumb:
- One `CanNamespace` per bus the ECU is on; give a `RestbusConfig` only for buses it transmits on.
- Handlers receive the whole `Frame`; read `frame.signals["Frame.Signal"]`.
- Write outputs through `restbus.update_signals((name, value), ...)`; never publish raw frames.
- Periodic work: `asyncio.create_task` a loop with `asyncio.sleep`, start it in `__aenter__`, cancel in `__aexit__`.
- **Initialise any state a handler touches *before* `await self.bm.start()`** — `start()` subscribes,
  so an input frame can reach a handler on the next line. `playback/local/pcm.py` and `bms.py` get
  this wrong and die with `AttributeError` when they lose the race.
- Reserved values (`SNA`, `Error`) are written by DBC name, not by raw code:
  `RestbusSignalConfig.set(name="BatteryStatus.StateOfCharge", value="SNA")`. Prefer this over a
  frozen last value when an input goes away — see `bms.py`'s `_watchdog`.
- SOME/IP: `SomeIPNamespace("GWM-SOMEIP", client_id=99, broker_client=...)`; send with
  `await ns.notify(SomeIPEvent(name=..., service_instance_name=..., parameters={...}))`; receive with
  `ns.create_input_handler([filters.SomeIPEventFilter(service_instance_name=..., event_name=...)], cb)`.
- Built-in control requests every model answers: `PingRequest` and `RebootRequest`. The client is an
  **async context manager** — `async with ControlClient(client) as cc: await cc.send("DIM",
  PingRequest(), timeout=1.0)`. Calling `.send()` on a bare `ControlClient(client)` raises
  `InvalidStateError` ("transport must be started"), surfacing as a confusing `TypeError`.
- Keep pure logic (state machines, thresholds, ramps) in separate modules with unit tests, like `bcm/state_machines/`.

## Adding a frame to a DBC

Append to `remotive_car/platform/databases/body_can.dbc` (free IDs: 111–199, 301+; ID 110 has
stale `BA_` attribute lines for a non-existent `VehicleSpeed` frame – avoid it or clean them up):

```
BO_ 111 ClusterTelltales: 2 DIM
 SG_ LeftTurnTelltale : 0|1@1+ (1,0) [0|1] ""  GWM
 SG_ RightTurnTelltale : 1|1@1+ (1,0) [0|1] ""  GWM
 SG_ MalfunctionWarning : 2|1@1+ (1,0) [0|1] ""  GWM
```

and, in the attribute section at the end of the file, one `BA_ "GenSigStartValue" SG_ 111 <Signal> 0;`
per signal and `BA_ "GenMsgCycleTime" BO_ 111 50;` (ms; existing BCM frames use 50, `HVACControl` 500).
Rebuild afterwards; the receivers you list get the frame in their broker's `interfaces.json`.
