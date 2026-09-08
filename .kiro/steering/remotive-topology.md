---
inclusion: always
---

# RemotiveTopology – how the tooling works

RemotiveTopology turns YAML descriptions of a vehicle into a `docker-compose.yml`. Docs:
https://docs.remotivelabs.com/docs/remotive-topology

## Build and run

```bash
# One-time per checkout: register the workspace, or `build` refuses with "No workspace detected".
# Do NOT reach for the --no-workspace flag it suggests — that also stops Studio resolving the
# workspace. Writes remotive.yaml + .remotive/ into the repo; that is expected.
remotive topology workspace init

# Generate build/<instance name>/docker-compose.yml (runs the generator in Docker)
remotive topology build \
  -f remotive_car/instances/hello_world/main.instance.yaml \
  -f remotive_car/settings/can_over_udp.settings.instance.yaml \
  -f remotive_car/settings/vlan_using_bridge.settings.instance.yaml \
  remotive_car/build

# Run it (profiles are optional add-ons)
docker compose -f remotive_car/build/remotive_car_hello_world/docker-compose.yml \
  --profile 3dcar --profile jupyter up --build

# Run the test containers instead of an interactive session
docker compose -f remotive_car/build/remotive_car_hello_world/docker-compose.yml \
  --profile tester up --build --abort-on-container-exit
```

- Several `-f` files are merged; later files add to earlier ones. `includes:` inside a file are
  resolved relative to that file.
- The two `settings/*.settings.instance.yaml` files make CAN run over UDP and SOME/IP over a plain
  Docker bridge, so no `remotivebus` host service is needed. Always include them unless the host
  has RemotiveBus installed.
- `${VAR:-default}` strings in instance YAML are passed through to the generated compose file.
- Output is always `remotive_car/build/<name>/docker-compose.yml` where `name:` comes from the
  first instance file. Never edit generated files.

## File types

| Schema | Purpose | Example |
|---|---|---|
| `remotive-topology-platform:0.17` | Channels (CAN/LIN/Ethernet), signal databases, SOME/IP endpoints | `remotive_car/platform/remotive-car.platform.yaml` |
| `remotive-topology-instance:0.17` | Which ECUs run, how (model / mock / plain broker), extra containers, settings | `remotive_car/instances/hello_world/main.instance.yaml` |
| `remotive-topology-mapping:0.1` | Route broker signals to a target such as the 3D car | `remotive_car/common/3d_car/3d_car_mapping.yaml` |

### Platform: which ECU sits on which CAN bus is derived from the DBC

An ECU is attached to a CAN channel if it is the **sender** of a frame (`BO_ <id> <Frame>: <len> <ECU>`)
or listed as a **receiver** of a signal (`SG_ ... <unit> <RX1>, <RX2>`) in that channel's DBC.
To make an ECU transmit a new frame, add a `BO_`/`SG_` block with that ECU as sender to the DBC,
then rebuild. The broker's restbus will send it cyclically with `GenSigStartValue` defaults.

### Instance: the `ecus:` block

```yaml
ecus:
  DIM: {}            # broker only, no behaviour (frames it sends are static restbus defaults)
  PAM:
    mock: {}         # ECUMock: cyclically sends every frame PAM is sender of, no logic
  BCM:
    models:
      bcm:
        type: container
        container:
          build:
            args: [MODEL_PATH=bcm/python]   # -> models/bcm/python is COPY'd into the image
            target: model
            dockerfile: ../Dockerfile       # remotive_car/Dockerfile, stage "model"
          command: python -m bcm
          environment: [FOO=bar]
  IHU:
    container:       # arbitrary image standing in for the ECU (Cuttlefish does this)
      image: remotivelabs/remotivelabs-cuttlefish:16.0.0_r4-1
      ports: ["8443:8443"]
      volumes: ["./cuttlefish/state:/root/state"]

containers:          # helper containers that are not ECUs
  tester:
    profiles: [tester]
    build: { target: tester, dockerfile: ../Dockerfile }
    volumes: [".:/app"]
    working_dir: /app
    command: "pytest --broker_url=http://topology-broker.com:50051 -s -vv"
    depends_on: [bcm]

settings:
  can:
    default_driver: udp
```

Model fragments live in `remotive_car/models/<ecu>.bm.instance.yaml` and are pulled into a main
instance via `includes:`. Adding a new model = new fragment + one `includes:` line.

### Writing a minimal instance (verified 2026-09-18)

A small instance off an existing platform is the fastest way to iterate: include only the model
fragments you need, declare mocks for the inputs you want to drive, and let the resolver prune the
rest. Three model fragments plus one mock gives about 12 containers against the full car's 20, and a
~25 s cold start because there is no Cuttlefish to boot.

Three things that bite:

- **Do not include `tests/tester.instance.yaml`.** It (and `behave.instance.yaml`) hard-code
  `depends_on` for hello_world's services — `pcm-mock`, `DIM-broker.com`, `RLCM-broker.com`, `ihu` and
  more — so the generated compose references services that do not exist. Write your own tester
  fragment: container `tester`, `build: {target: tester, dockerfile: ../../Dockerfile}`,
  `volumes: ["../../tests:/app"]`, and a `depends_on` naming only your services. Relative volume paths
  are rewritten correctly relative to the generated compose file.
- **Including GWM drags in SOME/IP.** The GWM model always opens `SomeIPNamespace("GWM-SOMEIP")`, so
  the Ethernet channel is created even with no IHU. Verified harmless: GWM starts and runs normally
  with a provider and no consumer, no errors in its log.
- **The 3D mapping tolerates absent senders.** `3d_car_mapping.yaml` references `UISpeedFrame`,
  `LocationFrame` and `ProximityInfo`, whose senders (ABS, TCU, PAM) a minimal instance omits. Frame
  definitions still exist in the namespaces, so the mapping resolves and those inputs simply never
  update — `3d-car` logs no errors.

### What `{}` and `mock: {}` actually generate (verified against the emitted compose)

These are **not** the same thing, and `{}` never becomes a mock:

| Declared | Emitted services |
|---|---|
| `HVAC: {}` | only `HVAC-broker.com` (`remotivebroker-server`). Nothing else. Transmits nothing — the restbus is set up by a model or mock, so with neither there is no cyclic traffic at all. |
| `SCCM: {mock: {}}` | `SCCM-broker.com` **plus** a second container `sccm-mock` running `python -m remotivelabs.topology.cli.mock -n SCCM-DriverCan0=SCCM` against `REMOTIVE_BROKER_URL=http://SCCM-broker.com:50051` |

In `hello_world` the two kinds sit in one block and are easy to misread: `SCCM`, `PAM`, `TCU`, `ABS`,
`PCM` are mocks (→ `sccm-mock`, `pam-mock`, `tcu-mock`, `abs-mock`, `pcm-mock`); `DIM`, `FLCM`, `HVAC`
are plain brokers. `grep -cE '^  (dim|flcm|hvac)(-mock)?:'` on the generated compose returns 0. If a
tool appears to label a broker-only ECU as a "mock", the generator disagrees — trust the compose file.

**`{}` is a floor, not a lock.** `hello_world` declares `RL: {}`, yet the resolved instance gives RL a
full model (`python -m rl`), because `models/rl_rlcm.instance.yaml` is in its `includes:` and an
include's `models:` overrides the bare entry. So do not assume `{}` guarantees "no behaviour" — and
conversely, when adding a model for an ECU that is declared `{}`, resolve the instance to check
whether the entry actually needs removing rather than assuming either way.

**`show instance` is only as complete as the files you pass it.** Resolving
`instances/android/main.instance.yaml` alone reports IHU as a Python model with
`MODEL_PATH=ihu/python`; the running car has the Cuttlefish container, because the second `-f`
(`cuttlefish.instance.yaml`) overrides it. Pass every `-f` the build uses or the answer is honest
about the file and wrong about the topology.

The resolver also **prunes ECUs no instance file mentions**. `chassis_can.dbc` has
`BU_: ABS BMS PCM GWM DIM`, but DIM appears nowhere in the resolved `android` output — no broker, no
container. Membership is derived from the DBC only for ECUs the instance actually declares.

## Runtime naming (important for code and tests)

- Every ECU gets a broker container `<ECU>-broker.com`; models talk to their own broker via
  `REMOTIVE_BROKER_URL=http://<ECU>-broker.com:50051` (set by the generator).
- The **topology broker** `topology-broker.com:50051` sees every bus. Host port **50051**
  (via `topology-api`). Tests and Jupyter connect here.
- Namespace names are `<ECU>-<Channel>`, e.g. `BCM-BodyCan0`, `GWM-SOMEIP`, `SCCM-DriverCan0`.
  On the topology broker the bus-wide view is `topology-<Channel>` (used by the 3D mapping).
- The two kinds are **different perspectives, not different data**: `<ECU>-<Channel>` is how that
  ECU sees the bus — the part of the database it needs — and is what behavioral models and mocks
  use, including every restbus write (an ECU can only transmit through its own namespace).
  `topology-<Channel>` is the full view of the bus, for observers: Studio, the 3D car, tests.
  No ECU in a real car has that view.
- Signal names are `<Frame>.<Signal>`, e.g. `TurnLightControl.LeftTurnLightRequest`.
- Restbus: the broker transmits every frame an ECU is sender of, cyclically, at the DBC's
  `GenMsgCycleTime`. A model changes the transmitted values with `restbus.update_signals(...)`; tests
  can poke a mock ECU's restbus the same way through the topology broker.
- **The restbus is set up by the model or mock**, through `RestbusConfig` in its `CanNamespace` — it
  is not something the broker starts on its own. Consequences worth remembering: an ECU declared as
  `ECU: {}` transmits nothing at all, and if a model *dies*, its broker keeps transmitting the last
  values forever (frames on cycle, values frozen — no timeout, no complaint). Verified on the box:
  killing `abs` leaves `UISpeedFrame` arriving 5/s at a constant 12.31 m/s, and Android reports it as
  `AVAILABLE`.

## Python library `remotivelabs-topology` (~=0.22)

Verified import paths used by this repo:

```python
from remotivelabs.broker import BrokerClient, Frame, RestbusSignalConfig
from remotivelabs.topology.behavioral_model import BehavioralModel, PingRequest, RebootRequest
from remotivelabs.topology.cli.behavioral_model import BehavioralModelArgs   # .url .auth .delay_multiplier .loglevel
from remotivelabs.topology.control import ControlClient, ControlRequest, ControlResponse
from remotivelabs.topology.namespaces import filters                          # FrameFilter, SenderFilter, E2eSignalsFilter, SomeIPEventFilter, SomeIPRequestFilter
from remotivelabs.topology.namespaces.can import CanNamespace, RestbusConfig
from remotivelabs.topology.namespaces.some_ip import SomeIPNamespace, SomeIPEvent
from remotivelabs.topology.testing.frames import capture_frames
```

`BehavioralModel(name, broker_client, namespaces=[...], input_handlers=[...],
control_handlers=[("cmd", handler)], input_filters=[...], on_change=True)`.
With `on_change=True` (default) a handler only fires when a signal in the frame changed; set
`on_change=False` if you need every cyclic frame (e.g. for timeout supervision).

Details and full patterns: see the steering file `python-models.md` (loaded when editing models)
and `testing.md` (loaded when editing tests).
