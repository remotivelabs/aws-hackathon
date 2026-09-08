# Troubleshooting

Everything that can go wrong on the day-2 box, in one place. `INSTRUCTIONS.md` covers setup,
`LAB.md` the exercises — both link here.

Fastest first move for anything unexplained: ask Kiro. It knows this box, the instance and the
tooling, and it can look at the containers and logs for you.

## Setup and connection

| Symptom | Cause and fix |
|---|---|
| `remotive cloud auth whoami` prompts for login | The `REMOTIVE_CLOUD_*` variables are not set. Re-run `source ~/aws-hackathon/participant/setup-day2.sh`. |
| A URL does not load on your own machine | The SSH session carrying the tunnels is closed. Reconnect with `ssh remotive-hackathon`. Nothing on day-2 is reachable except port 22. |
| `remotive topology build` says "No workspace detected" | Run `remotive topology workspace init` in `~/remotivelabs-topology-examples` once. |
| Kiro seems unaware of the car — wrong instance, doesn't know the buses | The `.kiro` symlink is missing. Check `ls -l ~/remotivelabs-topology-examples/.kiro`, re-run the setup script, then start a new Kiro session. |
| `git status` in the examples repo shows `.kiro` or a dashboard | The local exclude entries are missing. Re-run the setup script; it appends `.kiro`, `dashboards` and `*.dashboard.json` to `.git/info/exclude` (no trailing slashes — git will not match a symlink against a directory pattern). |

## Running the car

| Symptom | Cause and fix |
|---|---|
| Everything exited at once, `Exited (143)` | `Ctrl+C` in the terminal running the car — 143 is SIGTERM. Ask Kiro to start it again, and keep other commands in a separate terminal. |
| Android never boots, `ihu` never reports `healthy` | No KVM. The instance must be launched with `--cpu-options NestedVirtualization=enabled` on c8i/m8i/r8i. Check with `ls /dev/kvm`. |
| Containers exit with "dependency ... failed to start" | The cloud token is missing — each broker verifies the subscription at startup. Re-run the setup script, then start the car again. |
| First start seems to hang | The Cuttlefish image is ~7 GB and pulls once. Later starts take about 90 seconds, most of it Android booting. |
| `docker compose up` fails on overlapping subnets | Another topology is still running. One topology per Docker daemon: bring the other one `down` first. |
| The car looks frozen — no speed, nothing moving | The recording is not playing. The `playback` profile must be on: `--profile playback --profile 3dcar`. |

## Watching signals

| Symptom | Cause and fix |
|---|---|
| `candump -t d` shows ~4 ms instead of the cycle time | The delta is against the previous frame of *any* ID. Filter inside candump: `candump -t d 'vchassiscan0,07B:7FF'`. |
| `candump any` prints every frame several times | Expected. Each container attaches a `vxcan*` peer to the bus, so you see the named device plus one line per peer. Use a single device instead. |
| `frame-distribution` fails on `topology-SOMEIP` | That counter is for CAN namespaces. Use `remotive broker signals subscribe` for SOME/IP events. |
| A signal name is not accepted | Signals are `<Frame>.<Signal>` and namespaces are `topology-<Channel>` or `<ECU>-<Channel>`. List them with `remotive broker signals namespaces` and `remotive broker signals list --name-starts-with <Frame>`. |

## RemotiveStudio and dashboards

| Symptom | Cause and fix |
|---|---|
| Panels stay empty | Studio is not talking to the broker. Settings (gear, bottom left) → Connections should read `localhost:50051`. |
| No videos offered in the video panel | The `playback` container is not running, so there is no recording session to take them from. |
| `Save As` will not leave the examples repo | Correct, by design — Studio saves inside its workspace. Save into `dashboards/`, which is a symlink to `~/aws-hackathon/participant/dashboards`. |
| A chart is flat | You may be in a quiet stretch of the drive. Speed always moves; the indicator only during turns. |
| The Files sidebar has no platform files | Studio was started without the repo as its workspace. Restart it: `remotive studio ~/remotivelabs-topology-examples --no-browser`. |
| "Capture channel in Wireshark" is missing | Only the desktop app has it, and Wireshark must be installed on day-1. See `LAB.md` → *Optional: Studio on your own machine*. |
| System monitoring says it is not enabled | The topology was generated without metrics. That is the default here; regenerate with metrics if you want those dashboards. |

## Android head unit

| Symptom | Cause and fix |
|---|---|
| Browser refuses `https://localhost:8443` | Self-signed certificate — accept it explicitly. |
| The 3D car page shows a dead embedded head-unit view | Stale session in that tab. Reload it. |
| `adb` cannot connect | Use the forwarded port from day-1: `adb connect localhost:6520`. `adb` is not installed on the box itself. |
