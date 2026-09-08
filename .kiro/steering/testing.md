---
inclusion: fileMatch
fileMatchPattern: ["remotive_car/tests/**", "remotive_car/models/**/tests/**"]
---

# Proving behaviour with tests

Two layers, both already set up in the repo:

1. **Unit tests** per model: `remotive_car/models/<ecu>/python/tests/`, run with
   Pure logic only, no broker. **`uv` is not installed on the day-2 box**, so run it in a container:
   ```bash
   cd remotive_car/models/<ecu>/python
   docker run --rm -v "$PWD":/w -w /w python:3.13-slim \
     sh -c "pip install -q uv==0.9.2 && uv run --frozen pytest -q"
   ```
   (`bcm` has 39 tests, `bms` 24; both sub-second apart from the ticker timing tests.)
2. **Integration tests** against the running topology: `remotive_car/tests/pytest/`, run with
   `docker compose -f remotive_car/build/<name>/docker-compose.yml --profile tester up --build --abort-on-container-exit`
   The `tester` profile is the CI entry point: it exits non-zero when a test fails. Add
   `--abort-on-container-exit tester` so the run stops with it. **Always prove a new test can fail** —
   stub out the behaviour, confirm red, restore.
   Android/adb tests are marked `@pytest.mark.android` and need the Cuttlefish instance.

## Integration test pattern (`#[[file:remotive_car/tests/pytest/test_simulate_driver.py]]`)

```python
from remotivelabs.broker import BrokerClient, RestbusSignalConfig
from remotivelabs.topology.control import ControlClient, ControlRequest
from remotivelabs.topology.behavioral_model import PingRequest
from remotivelabs.topology.testing.frames import capture_frames

async def test_left_turn_telltale(broker_client: BrokerClient):
    # 1. stimulate: change what the SCCM *mock* transmits (namespace = <ECU>-<Channel>)
    await broker_client.restbus.update_signals(
        ("SCCM-DriverCan0", [RestbusSignalConfig.set(name="TurnStalk.TurnSignal", value=1)])
    )
    # 2. observe on any ECU's view of a bus and wait for the expected signal values
    async with capture_frames((broker_client, "GWM-BodyCan0"), ["ClusterTelltales"]) as cap:
        await cap.wait_for_frame("ClusterTelltales", {"ClusterTelltales.LeftTurnTelltale": 1}, timeout=2)
        # blinking: await cap.wait_for_signal_values("ClusterTelltales", "ClusterTelltales.LeftTurnTelltale", values=[1, 0, 1], timeout=5)

async def test_bcm_answers_ping(broker_client: BrokerClient):
    async with ControlClient(broker_client) as cc:
        resp = await cc.send("BCM", PingRequest(), timeout=1.0)
        assert resp.status == "ok"
```

- The `broker_client` fixture (see the existing test file) connects to `--broker_url` and resets
  SCCM signals afterwards; reuse it and reset anything you change.
- `capture_frames(...)` gives `next()`, `wait_for_frame(frame, {sig: value}, timeout)`,
  `wait_for_frames(...)`, `wait_for_signal_values(frame, signal, values=[...], timeout)`.
- Custom control commands: `await cc.send("BCM", ControlRequest(type="emergency_mode", argument="emergency"))`.
- Simulating a dead/degraded ECU from a test: stop its model container from the host
  (`docker compose ... stop bcm`) or, inside the model, add a control command that calls
  `await ns.restbus.stop()` / `.start()`. Prefer the control-command route so the test can run
  inside the `tester` container without Docker access. `ControlClient.send` raises
  `asyncio.TimeoutError` when a model does not answer.
- Add `@req COMP_REQ_...` comments above tests if you also add requirements to `remotive_car/docs/`
  (Sphinx-Needs traceability); optional for the hackathon.

## Behave (Gherkin)

`remotive_car/tests/behave/features/*.feature` + `steps/example_steps.py`; run via profile `behave`.
Good for demo-friendly wording ("When the BCM stops responding, then the cluster shows a warning").
