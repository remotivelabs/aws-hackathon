---
inclusion: always
---

# RemotiveCar – ECUs, buses and signals (verified against the repo)

Platform: `#[[file:remotive_car/platform/remotive-car.platform.yaml]]` (+ `someip.platform.yaml`).

## Buses

| Channel | Type | Database | Members (from DBC senders/receivers) |
|---|---|---|---|
| DriverCan0 | CAN 500k/8M FD | `platform/databases/driver_can.dbc` | SCCM (tx) → BCM |
| BodyCan0 | CAN 500k/8M FD | `platform/databases/body_can.dbc` | BCM, PAM, TCU, GWM (tx) → DIM, FLCM, RLCM, GWM, HVAC |
| ChassisCan0 | CAN | `platform/databases/chassis_can.dbc` | ABS, BMS, PCM (tx) → GWM, DIM |
| RearLightLIN | LIN | `platform/databases/rearlight.ldf` | RLCM (master) ↔ RL, DEVS2 |
| SOMEIP | Ethernet 172.31.0.0/24 | `platform/databases/someip.fibex.xml` | GWM (172.31.0.18) ↔ IHU (172.31.0.12) |

## ECUs

| ECU | Role | hello_world instance | android instance |
|---|---|---|---|
| SCCM | Steering column: stalks, pedals, buttons → DriverCan0 | mock (drive it from tests/Jupyter) | playback model |
| BCM | Body controller: turns SCCM input into lamp requests, gear, steering info → BodyCan0 | python model `models/bcm` | python model |
| GWM | Gateway: BodyCan0/ChassisCan0 → SOME/IP events; SOME/IP HVAC → `HVACControl` on BodyCan0 | python model `models/gwm` | python model |
| IHU | Head unit (SOME/IP) | python model `models/ihu` (no UI) | Cuttlefish Android container |
| DIM | Driver Information Module / instrument cluster | `{}` broker only – **unimplemented ECU** | not included |
| HVAC | Climate | `{}` broker only – **unimplemented ECU** | `{}` |
| FLCM, RLCM, RL | Front/rear light control, rear light (LIN) | `{}` / python models `models/rlcm`, `models/rl` | not included |
| PAM, TCU, ABS | Proximity, GNSS location, wheel speed | mocks | TCU/ABS playback models |
| BMS | Battery management: pack voltage/current, SoC, power, charge port → ChassisCan0 | python model `models/bms` (via `includes:`, so absent from the `ecus:` block) | playback model |
| PCM | Powertrain control: motor speed and torque → ChassisCan0 | not included | playback model |

In the **android** instance, SCCM/ABS/TCU/BMS/PCM are *playback models* (containers `sccm`, `abs`,
`tcu`, `bms`, `pcm`), not mocks: each subscribes to VSS signals from the recording and writes them
into its own restbus. Code: `remotive_car/instances/android/playback/local/<ecu>.py`. IHU has **no
broker** there — `cuttlefish.instance.yaml` replaces the `models/ihu` model with the Cuttlefish
container, which consumes SOME/IP directly. DIM has no model in either instance — a plain broker in
`hello_world`, absent altogether in `android` — even though the DBCs put it on BodyCan0 and name it
receiver of the BMS/PCM frames on ChassisCan0 — so it is a real ECU on this car that nobody has
implemented, and useful raw material for anyone who wants to build one.

## Frames and signals

DriverCan0 (sender SCCM): `HazardLightButton.HazardLightButton`, `TurnStalk.TurnSignal` (0 off, 1 left, 2 right),
`SteeringAngle.SteeringAngle`, `LightStalk.LightMode` (0 off, 1 DRL, 2 low) + `LightStalk.HighBeam`,
`BrakePedalPositionSensor.BrakePedalPosition`, `AcceleratorPedalPositionSensor.AcceleratorPedalPosition`,
`GearShiftPaddles.GearShiftUp/GearShiftDown`.

BodyCan0:
- BCM → `DaylightRunningLightControl.{Left,Right}DaylightRunningLightRequest`,
  `LowBeamLightControl.{Left,Right}LowBeamLightRequest`, `HighBeamLightControl.{Left,Right}HighBeamLightRequest`,
  `TurnLightControl.{Left,Right}TurnLightRequest` (these toggle – BCM blinks them),
  `BrakeLightControl.{Left,Right}BrakeLightRequest`, `SteeringWheelInfo.SteeringWheelPosition`,
  `AcceleratorPedalInfo.AcceleratorPedalPosition`, `GearInfo.GearLeverPosition` (0 reverse, 1 drive)
- PAM → `ProximityInfo.ProximityDistance`
- TCU → `LocationFrame.Longitude/Latitude/Heading`
- GWM → `HVACControl.LeftTemperature/RightTemperature` (16–30 °C, 0.1 °C) – receiver HVAC
- Frame IDs 100–104, 106–109, 200, 300 are taken; **105 is free**, and DIM has no frames yet.
  **ID 110 is poisoned** — stale
  `BA_ "GenSigStartValue" SG_ 110 VehicleSpeed 0;` and `BA_ "GenMsgCycleTime" BO_ 110 50;` lines for a
  frame that does not exist. Free: 111–199, 201–299, 301+.

ChassisCan0 — four frames, all receivers include DIM except `UISpeedFrame`. Used IDs are 123, 140, 141
and 150, so **142–149 and 151+ are free**:

| ID | Frame | Sender | Cycle | Signals |
|---|---|---|---|---|
| 123 `07B` | `UISpeedFrame` | ABS | 200 ms | `uispeed` (m/s, 0.01) → GWM |
| 140 `08C` | `BatteryMeasurement` | BMS | 20 ms | `BatteryVoltage` (V, 0.01), `BatteryCurrent` (A, 0.1) → GWM, DIM |
| 141 `08D` | `BatteryStatus` | BMS | 100 ms | `StateOfCharge` (%, 0.1, 10-bit), `BatteryPower` (kW, 0.1) → GWM, DIM |
| 150 `096` | `MotorInfo` | PCM | 20 ms | `MotorSpeed` (rpm, 0.25), `MotorTorque` (Nm, 0.1) → GWM, DIM, BMS |

**Reserved values / SNA.** The BMS and PCM signals declare `VAL_ ... 65534 "Error" 65535 "SNA"`
(1022/1023 for the 10-bit `StateOfCharge`), and their `GenSigStartValue` **is** SNA — so the restbus
transmits "unknown" until real data arrives. Both models take
`SNA_ON_MISSING_INPUT_TIMEOUT` (3 s in the android instance) and a `_watchdog` writes SNA back into
every signal they own when VSS input stops. ABS has no such fallback: stop it and `UISpeedFrame`
keeps transmitting the last real speed. Write reserved values by DBC name:
`RestbusSignalConfig.set(name=..., value="SNA")`.

**Control commands** (`ControlClient.send(target_ecu=..., request=ControlRequest(type=..., argument=...))`):

| ECU | Command | Argument |
|---|---|---|
| BMS | `set_batterystatus_stateofcharge` | number 0..100 |
| BCM | `emergency_mode` | `emergency` / `normal` |
| any model | `PingRequest`, `RebootRequest` | — |

SOME/IP (fibex): GWM provides `TurnlightIndicator.TurnlightControlEvent`, `LocationService.LocationEvent`,
`SpeedService.SpeedEvent`, `GearService.GearEvent`; IHU provides `HVACService.CompartmentControl`
(`LeftTemperature`, `RightTemperature`).

## VSS: the recorded drive (android instance only)

The recording brings its **own channel and platform file**, merged in via
`instances/android/local_playback.instance.yaml` → `recordings/platform/topology.platform.yaml`:

```yaml
channels: { VSS: { type: can, database: ./databases/vss_6.0_extract.yaml } }
ecus:     { TCU:, ABS:, SCCM:, BMS:, PCM: }        # each with channels: VSS:
```

So the brokers expose `topology-VSS` and `<ECU>-VSS`, and the host gets a SocketCAN device `vvss`.
VSS is *not* a vehicle bus — it is a transport for recorded data. Each signal sits alone in an 8-byte
frame, IDs assigned in file order, payload = the raw value in its VSS datatype (IEEE double for
`Vehicle.Speed` at `0x00E` and the locations, plain ints for pedals `0x002`/`0x003` and steering
angle `0x004`). No factors, no bit packing.

`container: playback` (profile `playback`) replays `recordings/tesla.recordingsession.yaml`: one VSS
CSV plus four mp4s named `front`, `rear`, `left`, `right`, 60 s long, repeating. Control it with
`remotive broker playback status|pause|play /tesla.recordingsession.yaml`.

Unit conversions happen in the playback models, not in the recording: e.g. `abs.py` divides
`Vehicle.Speed` (km/h) by 3.6 for `UISpeedFrame.uispeed` (m/s).

## 3D visualisation

`remotive_car/common/3d_car/3d_car.instance.yaml` adds container `3d-car` (profile `3dcar`,
host port 3000). Its mapping `#[[file:remotive_car/common/3d_car/3d_car_mapping.yaml]]` routes
`topology-<Channel>` broker signals to a **fixed** set of 3D inputs. The image supports exactly:

`Speed`, `Gear`, `SteeringAngle`, `Throttle`, `Brake`, `TurnStalkPosition`,
`Left/Right{Front,Rear}DirectionIndicator`, `Left/Right{Front,Rear}DaytimeRunningLightIndicator`,
`Left/RightFrontLowBeamIndicator`, `Left/RightRearLowBeamIndicator`, `Left/RightHighBeamIndicator`,
`Left/RightBrakeIndicator`, `MotorPower` and `BatterySoC` (both already mapped from BMS'
`BatteryStatus`, `MotorPower` through a `transform: {type: linear, ...}`), and the dashboard
tell-tales `LeftDirectionButtonIndicator`, `RightDirectionButtonIndicator`, `HazardButtonIndicator`,
`LowBeamButtonIndicator`, `AutoBeamButtonIndicator`. Treat the mapping file, not this list, as the
authority on what the image accepts.

New 3D inputs cannot be invented; to visualise new behaviour, map new bus signals onto these
inputs (the dashboard tell-tales are the natural "instrument cluster"). No rebuild needed: the file
is bind-mounted and served live at `http://localhost:3000/mapping.yaml`, so an **in-place** edit
needs only a browser reload. If the file is *replaced* (`git checkout`, or an editor that saves
atomically) the mount still serves the old inode — then `up -d --force-recreate 3d-car`; a plain
`restart` does not help.

## Instances you will use

- `remotive_car/instances/hello_world/main.instance.yaml` – all ECUs, no Android. Profiles:
  `3dcar`, `jupyter` (http://localhost:8888/lab?token=remotivelabs, notebook drives SCCM), `tester`, `behave`.
- `remotive_car/instances/android/main.instance.yaml` + `instances/android/cuttlefish.instance.yaml`
  (+ compose overlay `instances/android/cuttlefish.compose.yaml`) – BCM/GWM models, HVAC broker,
  Cuttlefish IHU, recorded drive playback (profile `playback`). Needs KVM. **This is the Part 1 car.**
- `remotive_car/instances/fmu/main.instance.yaml` – `hello_world`'s shape but BCM is an **FMU**
  (`models/bcm/fmu/bcm/model/BCM.fmu` via `models/bcm_fmu_gwm_ihu.instance.yaml`) instead of the Python
  model, and BMS/PCM are mocks rather than models. Same platform, so the buses are identical.

Those three are what a **clean box** has. A participant doing LAB.md Part 2 will usually add a fourth,
smaller one of their own — see `.kiro/steering/go-creative-coaching.md`.

## Existing tests to copy from

- `remotive_car/tests/pytest/test_simulate_driver.py` – drive SCCM mock, assert frames on FLCM/RLCM/RL.
- `remotive_car/tests/pytest/android/test_hvac.py` – tap Android UI via adb, assert `HVACControl` on `HVAC-BodyCan0`.
- `remotive_car/tests/behave/features/*.feature` – Gherkin scenarios for turn signals.
- Unit tests for state machines: `remotive_car/models/bcm/python/tests/`.
