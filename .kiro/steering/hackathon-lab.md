---
inclusion: always
---
# The box you are on and the car that runs on it

**Check which machine you are on before running anything — everything below describes day-2.**

| Workspace root | You are on | What you may run |
|---|---|---|
| `~/remotivelabs-topology-examples` (contains `remotive_car/`) | **day-2**, the box | everything in this file |
| `aws-hackathon` itself, on the participant's own machine (no `remotive_car/`) | **day-1** | **nothing from the lab.** Read `.kiro/steering/day1-setup.md` — the only day-1 action is `./participant/start-day2.sh` |

Day-1 has no Docker topology, no brokers, no SocketCAN devices and no car, so every command here
would fail or, worse, start something nobody can see. Do not run lab steps over SSH from day-1
either. When the user says *"I'm on the day-1 machine, set up day-2"*, that is
`.kiro/steering/day1-setup.md`, not this file.

This is the hackathon **day-2 box**: one EC2 instance per participant, running the RemotiveCar
topology in Docker. The participant reaches it over SSH from their own machine (day-1) and works
in `~/remotivelabs-topology-examples` through Remote-SSH. It is set up from day-1 by
`participant/start-day2.sh`, which launches or starts the box, copies `~/aws-hackathon` onto it and
runs `setup-day2.sh` there — and deliberately stops before anything in the lab.

The lab script is `~/aws-hackathon/participant/LAB.md`. Follow it when the participant works through an
exercise. Setup instructions are `participant/INSTRUCTIONS.md`.

**"Start the lab" means: get the car running.** Nothing else. Run the four commands in *The active
instance* below — `git pull`, `workspace init` (only if `remotive.yaml` is missing), `build`, then
`up -d` — and report what came up. A clean box has one car and no competing instance, so there is
nothing to hunt for first: no stashed work to restore, no leftover instance to bring `down`, no
conflicting networks. If `docker ps` already shows the 20 containers, say so and skip the rest rather
than restarting them. Then offer the Part 1 menu and Part 2, and let the participant choose — do not
start walking exercises unasked.

The lab has **two parts**, and they need opposite handling from you.

**Part 1 — Understand the platform** (exercises 1–7) is **optional and a menu**, not a checklist. It is
guided where it is used: follow the script, run the commands, answer the "ask Kiro" prompts. But do not
march a participant through it by default — offer the exercises that serve what they want, and say
plainly that skipping is fine.

**The floor is Exercise 1: get the car running.** Part 2 needs it and nothing else from Part 1 is a
prerequisite. If someone wants to go straight to building, help them start the car and move on. A good
short subset when someone wants a taste first is 1, 3 and 6 — start, observe, modify.

**Part 2 — Go creative** is a *brief*, not a walkthrough — five requirements and three hints, with
every design decision left to the participant. **Before coaching Part 2, read
`.kiro/steering/go-creative-coaching.md`.** It holds the option space with trade-offs, the traps that
cost real time and verification recipes. That file is agent-facing: never paste it at a participant,
and do not volunteer frame IDs or a finished design unprompted. There are **no mandatory steps in
Part 2** and route selection is theirs. **No solution is stored anywhere** — you and the participant
build it together, in their repo, from the brief.

Seven exercises in Part 1, all against the one running car: **1** start it and look at it four ways, **2** build
a Studio dashboard and scrub the drive from its **playback seekbar** (dragging it moves the whole
car; pausing it shows BMS/PCM falling back to SNA while ABS freezes — exercise 7 met early),
**3** four views of the same traffic (`candump`, decoded signals,
frame-distribution, SOME/IP `tcpdump`), **4** read the platform and instance files, **5** trace speed
from the recording to the Android speedometer, **6** change the car at three depths (3D mapping → DBC
cycle time → model logic), **7** break an ECU on purpose (frozen restbus, SNA fallback, control-channel
ping). Exercises 1–5 are read-only against the examples repo; 6 and 7 edit it, each with a revert.

Two entries in that checkout are **symlinks** into `~/aws-hackathon`, created by
`participant/setup-day2.sh`: `.kiro` (this steering) and `dashboards` (participant artifacts).
`~/aws-hackathon` is the single source of truth — edit the steering there.

## The active instance: Cuttlefish + 3D car + recorded drive

Everything in the lab runs this one instance — Android head unit, 3D car and a recorded Tesla drive
playing back. Not `hello_world`.

```bash
cd ~/remotivelabs-topology-examples

git pull                                     # start every session on the latest examples

remotive topology workspace init             # one-time per checkout; answer 'y' to consent

remotive topology build \
  -f remotive_car/instances/android/main.instance.yaml \
  -f remotive_car/instances/android/cuttlefish.instance.yaml \
  remotive_car/build

docker compose \
  -f remotive_car/build/remotive_car_android/docker-compose.yml \
  -f remotive_car/instances/android/cuttlefish.compose.yaml \
  --profile playback --profile 3dcar up --build          # add -d to background it
```

**`workspace init` is required, and `--no-workspace` is the wrong way out.** Without a workspace
`build` refuses outright (`No workspace detected`) and helpfully suggests `--no-workspace` — do not
take it. That flag disables build caching *and* leaves the checkout unregistered, so Studio cannot
resolve the workspace or attach to the running instance. Run the init instead. It writes
`remotive.yaml` and `.remotive/` into the examples repo: untracked, covered by nothing in
`.gitignore`, and an expected exception to the "read-only against the examples repo" rule — not
something to revert. Once it exists, Studio starts with a bare `remotive studio --no-browser`; the
path argument is no longer needed. Output paths must also stay inside the workspace, so building to
`/tmp` fails with `E024: Trying to access file outside of workspace`.

The full canonical sequence is in the box's **MOTD**, printed on every SSH login — read it before
inventing commands. It covers auth, init, build, `up`, and Studio.

`up` runs in the foreground and **holds that terminal** — `Ctrl+C` there stops the entire car (every
container exits with 143). Keep the car in its own terminal and run everything else (`candump`, the
CLI, Studio) in another one, and say so when starting it for a participant. If a participant reports
that everything died at once, this is almost always why: check `docker ps -a` for `Exited (143)` and
offer to start it again.

**An attached `up` cannot be detached after the fact — verified the hard way.** Running
`docker compose ... up -d` alongside a foreground `up` looks like it works (it reports every container
`Healthy` and exits 0) but it changes nothing: the original process still owns them, and killing it
takes the whole car down with `Exited (143)`. There is no rescue; just `up -d` again afterwards, which
starts them properly detached (~80 s to `ihu` healthy). **If you are an agent starting the car, start it
detached with `up -d` in the first place** — a foreground `up` in a session-managed terminal dies with
the session and takes the car with it.

Same command with `down` instead of `up --build` to stop. Compose project: `remotive_car_android`.
Service names for `docker compose logs -f <svc>`: `bcm gwm abs bms pcm sccm tcu ihu playback
3d-car topology-api topology-broker.com <ECU>-broker.com`.

No `can_over_udp` / `vlan_using_bridge` settings files here: this box runs **RemotiveBus**
(`remotivebusd.service`), so CAN is real SocketCAN. Do not add those settings — they would break
the `candump` exercises and the Android networking.

### What a clean box actually has

**A participant starts with a fresh upstream clone**, so the only buildable instances are `android`
(the Part 1 car, above), `hello_world` and `fmu`. Nothing from Part 2 exists yet: no extra frames, no
extra control commands, no smaller instance. That is the correct starting state — everything Part 2
needs is built during the session, so never describe a Part 2 signal, frame or instance as if it were
already on the car.

A participant working Part 2 will usually build a small instance of their own, which is the fourth one
you will see. Read `.kiro/steering/go-creative-coaching.md` before helping with that; it covers the
option space, the traps and how to prove the thing works.

**One topology per daemon still applies** — whatever is running must come `down` before another starts.

Auth: `REMOTIVE_CLOUD_AUTH_TOKEN` comes from `~/.ssh/environment` (installed by
`participant/setup-day2.sh`), so it is present in every SSH session including the ones you run
commands in. `remotive topology build` and the brokers both need it.

## Where to look at what is running

Ports are published on the box; the security group allows only SSH, so the participant reaches
them through SSH tunnels and opens them as `localhost` **on day-1**:

| What | day-1 URL |
|---|---|
| 3D car | `http://localhost:3000` — `c` cycles the camera views |
| Android head unit (Cuttlefish) | `https://localhost:8443` (self-signed cert). Organic Maps is installed on the device (`cuttlefish/apks/organicmaps.apk`); started from the launcher it follows the driven route |
| Topology broker / API | `localhost:50051` |
| adb | `adb connect localhost:6520` |
| RemotiveStudio | `http://localhost:57123` |

Start Studio from the repo so the Files sidebar has the platform and instance files, and let it pick
up the running broker by itself. Once `workspace init` has been run there is no need to pass the path
— that is what registering the workspace bought you:

```bash
cd ~/remotivelabs-topology-examples
remotive studio --no-browser
```

Studio serves on `127.0.0.1:57123` and configures its broker URL from the workspace. If a dashboard
panel shows no live data, check Settings → Connections — it should point at the topology broker on
`localhost:50051`.

**Deep links into Studio** — use these when pointing a participant at a file, and in `LAB.md`:

```
http://localhost:57123/files?path=<url-encoded>&viewMode=<mode>&view=topology&topologySubView=graph
http://localhost:57123/files?path=%2Fremotive_car%2Finstances%2Fandroid%2Fmain.instance.yaml&viewMode=instance&view=topology&topologySubView=graph
```

The complete query schema, read off `BVt()` in the bundle:

| Param | Values |
|---|---|
| `path` | required, URL-encoded from the repo root (`%2F` per `/`) |
| `viewMode` | `instance` · `platform` (also `*.dbc`/`*.ldf`) · `text` · `dashboard` |
| `view` | `topology` · `signals` |
| `topologySubView` | `graph` · `tree` · `yaml` — **`tree` is the default**, so always name `graph` explicitly |
| `entityId` | `ecu:<Name>` or `channel:<Name>`, e.g. `entityId=ecu%3AGWM` |
| `signalSubView` | `table` |
| `signalScope`, `signalFilters` | filter state for the Signals tab |

**`topologySubView` defaults to `tree`, which is the trap.** A link with only `viewMode=platform`
lands on the tree, not the graph — every link written before this was discovered had that bug. The
graph is the appealing view and the one to use for the running instance early on.

Video, audio and image files get no view modes at all. File-type detection is server-side, so `.xml`
(the FIBEX) is unconfirmed — omit `viewMode` there. Links need Studio running and the participant's
tunnel up; say so rather than letting a dead link confuse them.

**Source files should link into the editor, not Studio.** Model code has nothing for Studio to render,
and exercises 6 and 7 exist to edit it. Use a filesystem-relative markdown link from the doc:

```markdown
[`remotive_car/instances/android/playback/local/abs.py`](../../remotivelabs-topology-examples/remotive_car/instances/android/playback/local/abs.py)
```

Kiro resolves relative links against the file's own location, so this works whichever folder is open.
It does assume `~/aws-hackathon` and `~/remotivelabs-topology-examples` are siblings, which
`setup-day2.sh` arranges. Rule of thumb: **platform and instance files → Studio (to look at);
source files → editor (to change).**

**Two separate UI controls — do not conflate them.**

1. **`⋮` menu → View Mode** picks the *viewer*. For a database: **Text** / **Platform**. For an
   instance file: **Text** / **Instance**. This is what the URL's `viewMode` selects.
2. **Inside the graph viewer, a toolbar**: **Topology** / **Signals** tabs, plus three layout buttons
   tooltipped **As tree**, **As graph**, **As YAML** (`YAt` in the bundle).

So there are two routes to text, and they are not equivalent: `View Mode → Text` shows the file as
written on disk (raw DBC, raw YAML), while **As YAML** renders Studio's own resolved YAML — for an
instance that means every `include:` already followed, the same content `show instance` prints. Use
`Text` when the question is about file syntax, **As YAML** when it is about the resolved result.

**Match the view to the question, and link accordingly.** `platform` and `instance` are *graphs* — they
show structure and deliberately omit values. Addresses, ports, VLANs, cycle times, factors and raw
syntax are only in `text`. So a step that asks a participant to account for `16000`, or to read a
`BO_`/`SG_`/`BA_` line, must link with `viewMode=text` or it lands on a picture with none of the
numbers in it. Steps about *which file is authoritative* are fine on the graph.

Studio can only **save dashboards inside its workspace**, i.e. into the examples repo. Use the
`dashboards/` entry at the repo root — `setup-day2.sh` makes it a symlink to
`~/aws-hackathon/participant/dashboards`, so `Save As` there keeps the file with the hackathon
folder. Dashboards are `*.dashboard.json`; they stay drafts until `Save As`.

Participant docs: `participant/LAB.md` (the exercises), `participant/TROUBLESHOOTING.md` (all
symptom tables — send people there instead of inlining fixes in the lab), `participant/INSTRUCTIONS.md`
(setup).

**Whenever Studio comes up, mention the desktop app as an optional extra.** It runs on the
participant's own machine (`remotive studio --desktop`, needs the CLI and the service-account token
there) and opens this repo over SSH via the `remotive-studio-hackathon` host in
`participant/ssh_config` — a forward-free copy of the same host, so it does not collide with the
tunnel session. Its payoff over the browser: a channel's menu offers **Capture channel in
Wireshark** (plus *Open in Signal View* and *Live channel preview*), which launches Wireshark on
day-1 with a generated RemotiveLabs profile that decodes frames by name and sender. Screenshot teaser in
`participant/LAB.md` § 1.3, full walkthrough in that file's *Optional: Studio on your own machine*
section. It is optional; nothing in the lab depends on it. One prerequisite to state up front:
Wireshark installed on the participant's own machine. The integration itself is on by default in
current Studio — no setting to enable.

## Which tool answers which question

Match the tool to the question instead of defaulting to one of them:

| Question | Tool |
|---|---|
| Who sends this frame, who receives it, which bus is it on, what is in this instance | the **platform and instance files** (`platform/*.platform.yaml`, `platform/databases/*.dbc`, `instances/**/*.instance.yaml`) and `remotive topology show instance <file>` for the resolved result |
| What value does this signal have right now | `remotive broker signals subscribe --signal <ns>:<Frame.Signal>` |
| How often is this frame actually sent | `remotive broker signals frame-distribution --namespace <ns>` (counts per second, e.g. `{'frameId': 123, 'count': '5'}` = 5/s = the 200 ms cycle time) |
| What is on the wire, byte for byte | `candump <device>` |
| What does it look like over time, or all at once | RemotiveStudio (topology views, dashboards) and the 3D car |

Source questions are answered by reading the files, not by watching traffic — the DBC is what
decides who transmits what, so that is where the answer lives. Live tools tell you what is
*happening*, which is a different question.

## Two ways to look at traffic without a UI

**Frames, raw, on the host** — can-utils is installed and RemotiveBus gives the box real SocketCAN
devices: `vdrivercan0`, `vbodycan0`, `vchassiscan0`, `vvss`, plus a `vxcan*` peer per container
(which is why `candump any` shows each frame several times).

```bash
candump vchassiscan0                       # live chassis bus
candump -n 200 vchassiscan0 | grep ' 07B ' # UISpeedFrame (123) only
```

**Decoded signals, from the broker** — the RemotiveCLI talks to the topology broker
(`--url` defaults to `http://localhost:50051`, which is it). Use this whenever the question is
about a *signal* rather than a frame: it gives names and physical values instead of bytes.

```bash
remotive broker signals namespaces                       # topology-BodyCan0, ABS-ChassisCan0, ...
remotive broker signals list --name-starts-with UISpeed  # frame id, sender, receivers, cycle time,
                                                         # unit, factor — straight from the databases
remotive broker signals subscribe \
  --signal topology-ChassisCan0:UISpeedFrame.uispeed \
  --signal topology-BodyCan0:TurnLightControl.LeftTurnLightRequest   # NAMESPACE:SIGNAL, repeatable
remotive broker signals frame-distribution --namespace topology-ChassisCan0  # frames per second
```

`--on-change-only` cuts cyclic repeats; `--x-plot` draws a rough terminal chart. Related commands
worth knowing: `remotive broker signals publish` (inject a value), `remotive broker restbus`
(add/start/update/stop cyclic frames from the CLI) and `remotive broker playback` (control the
recording session that is driving the car).

## Restarting things without breaking the car

Learned by doing it wrong on this box:

- **Never recreate a single `<ECU>-broker.com`.** The brokers form a cluster (Horde registry);
  recreating one can take neighbours down with it — a `Can.NamespaceServer` / `no process` crash in
  the logs and several containers `Exited (1)`. After a DBC or platform change, rebuild and then
  `up -d` the whole topology. If containers are already down, `up -d` again brings them back.
- **If `topology-broker.com` restarts, the recording session is lost.** `remotive broker playback
  status` returns `[]`, the car stands still, and signals go flat. Fix: `docker compose ... restart
  playback`. If the broker got into a worse state (health 200 but the signals API times out), a full
  `down` + `up -d` is faster than guessing; Android needs 1–2 min to boot again.
- **Model containers are cheap to rebuild:** `up -d --build <bcm|abs|gwm|...>` picks up edited Python
  in ~11 s and touches nothing else. That is the loop to use for model work.
- The `_last_values` startup race in `playback/local/pcm.py` and `bms.py` is **fixed upstream** (pull
  of 2026-09-17). If a checkout predates it, `096`/`08D` go missing and the model shows `Exited (1)`
  with `AttributeError: ... no attribute '_last_values'` — `git pull`, or `up -d pcm` as a stopgap.
- **A full teardown is the reliable reset.** `down --remove-orphans` (both `-f` files, all profiles),
  then rebuild and `up`. With images cached, Cuttlefish prints `Cuttlefish is started and ready to
  use` in ~45 s and all 20 containers come up healthy. Prefer this over chasing a half-broken
  topology.

## Diagnostics recipes that work here

```bash
# Resolved instance: channels, host devices, which ECU runs what (positional path, no -f)
remotive topology show instance remotive_car/instances/android/main.instance.yaml

# SOME/IP on the wire: GWM 172.31.0.18 -> IHU 172.31.0.12, UDP 16000
sudo tcpdump -i any -n -x udp port 16000
#   payload starts 0066 03ea = service 102 / event 1002 = SpeedService.SpeedEvent, FLOAT32 big-endian
#   0065 03e9 = LocationEvent (28 B), 0064 03e9 = TurnlightControlEvent (18 B)

# What Android made of it
docker exec remotive_car_android-ihu-1 bash -lc \
  'PATH=$PATH:/root/bin adb shell cmd car_service get-property-value PERF_VEHICLE_SPEED'
```

Control-channel ping — the fastest "is this ECU alive" check, independent of any bus. Run it from
inside any model container, which already has the library. **`ControlClient` must be used as an async
context manager**, otherwise it raises an unhelpful `InvalidStateError`/`TypeError`:

```bash
docker exec -i remotive_car_android-bcm-1 python - <<'EOF'
import asyncio
from remotivelabs.broker import BrokerClient
from remotivelabs.topology.control import ControlClient
from remotivelabs.topology.behavioral_model import PingRequest

async def main():
    async with BrokerClient("http://BCM-broker.com:50051") as c, ControlClient(c) as cc:
        for ecu in ["BCM", "GWM", "ABS", "BMS", "PCM", "HVAC"]:
            try:
                print(f"{ecu:5} -> {await cc.send(ecu, PingRequest(), timeout=2.0)}")
            except Exception as e:
                print(f"{ecu:5} -> {type(e).__name__}")

asyncio.run(main())
EOF
```

On a healthy car every model answers `ControlResponse(status='ok')` and **HVAC times out** — it is
`HVAC: {}`, a broker with no model, so nothing answers. A stopped model times out the same way while
its frames keep flowing.

Two CLI facts worth not rediscovering: `remotive topology show services` and `show ethernet` accept
**ARXML only**, so they are useless against this FIBEX — read `someip.platform.yaml` and the FIBEX
directly, or use `show platform`. And `signals subscribe` is **change-driven**: a frozen value makes
it print nothing even while `frame-distribution` shows the frame arriving on cycle. That difference
is the point of the degraded-ECU exercise, not a bug.

## Facts learned the hard way (2026-09-17)

- **SOME/IP signals are named `<Service>.Event.<EventName>.<Param>`** in a broker namespace, e.g.
  `remotive broker signals subscribe --signal IHU-SOMEIP:SpeedService.Event.SpeedEvent.Speed`. Handy
  for proving the gateway works without `tcpdump`.
- **The 3D car proxies the Android screen to the host named `ihu`**:
  `3d_car.instance.yaml` sets `CUTTLEFISH_PROXY_TARGET=${CUTTLEFISH_PROXY_TARGET:-https://ihu:8443}`.
  Any instance where the Android container is *not* called `ihu` needs that variable overridden, or
  the in-dash screen 502s with `ihu could not be resolved`.
- **Cuttlefish images are ~7 GB each.** Both `16.0.0_r4-1` and `15.0.0-4` are now on disk. On a box
  far from the AMI's region, that pull dominates everything — pre-pull before a session, or rebuild
  the environment in a closer region.
- `docker restart` keeps a stale bind mount if the file was *replaced* on the host; `up -d
  --force-recreate <svc>` is what picks up a `git checkout`.
- **`docker ps` may show one or two extra containers with random names** (e.g. `bold_saha`) running
  `remotivelabs/remotive-topology:0.33 /entrypoint.sh show…`. Those are transient helpers RemotiveStudio
  spawns while resolving the workspace — not part of the car. The car is 20 containers.

## Facts learned the hard way (2026-09-17, second session)

- **A rebuilt box may have an empty Docker image cache.** `docker images` came back with nothing at
  all — no Cuttlefish, no `3d-car`, not even `remotivelabs/remotive-topology`. First start therefore
  includes a ~7.2 GB Cuttlefish pull (disk went 4.7 G → 12 G). Check `docker images` before promising
  a participant a quick start, and kick the pull off in the background while doing the build.
- **`git pull` first, every session.** The AMI's checkout can lag the fix it needs. This box shipped
  `dcca9b9` (2026-09-11) and needed `d9319e7` for the `_last_values` startup race in
  `playback/local/{pcm,bms}.py` — the pull moves `await self.bm.start()` to *after* the state init.
  Symptom if skipped: `pcm`/`bms` die with `AttributeError` and frames `096`/`08D` never appear.
  Pulling latest is also why the `3d-car` tag in `3d_car.instance.yaml` does not need tracking here.
- **Playback pause is a free degraded-ECU demo**, and exercise 2 now uses it. With the recording
  paused, VSS input stops and three ECUs on ChassisCan0 diverge while *all frames keep flowing on
  cycle*: `BatteryStatus.StateOfCharge` → `1023` (10-bit SNA), `MotorInfo.MotorSpeed` → `65535` (SNA),
  and `UISpeedFrame.uispeed` **freezes** at the last real value because ABS has no watchdog. `play`
  restores everything. Verified end to end.
- **Seeking moves the whole car.** `remotive broker playback seek --offset <µs>
  /tesla.recordingsession.yaml` re-derives every playback model: VSS 56.56 km/h → CAN 15.71 m/s →
  Android VHAL 15.89 m/s all followed one drag. Offsets are microseconds; the drive is 60 s, repeating.
- **`signals subscribe` output is easy to lose in a pipe.** `timeout N remotive broker signals
  subscribe ... | grep ...` often prints nothing because grep buffers and the timeout kills it first.
  Redirect to a file, then grep the file.
- **Verified healthy-start numbers**, useful as a smoke test: `frame-distribution` on
  `topology-ChassisCan0` gives `{123: 5, 140: 50, 141: 10, 150: 50}` per second, and 20/20 containers
  up with `ihu` reaching `healthy` about 90 s after `up`.

## If you are editing the lab material itself

Only relevant when the *organizer* asks for changes to the lab; ignore it during a participant
session. The material lives in `~/aws-hackathon`: `participant/` for what a participant reads,
`.kiro/steering/` for what you read, `organizer/` for the AMI tooling and
`organizer/HANDOVER.md` for the authoring worklog — read that one before changing `LAB.md` or these
files, and add what you changed to it afterwards. Two standing rules: Part 2 in `LAB.md` stays a brief
with no steps, and always-loaded steering describes a **clean box** rather than whatever happens to be
on this one.

## Ground rules for the lab

- **Part 1 exercises 1–5 are read-only against `~/remotivelabs-topology-examples`**: run it, read it,
  visualise it, but do not create or modify files there. Artifacts belong under
  `~/aws-hackathon/participant/` — reachable from the repo as the `dashboards/` symlink. Exercises 6
  and 7 edit the repo, each with a revert alongside the change.
- **Part 2 writes to the examples repo for real**, and that is intended — it is where the participant
  builds something. **Work on `main`; there is one branch and no need for another.** `git status` there
  is the safety net, and `git diff` is how work leaves the box. Remember the repo is **ephemeral**:
  nothing in it survives a rebuilt box, so anything worth keeping belongs in `~/aws-hackathon`.
- Never edit anything under `remotive_car/build/` — `remotive topology build` regenerates it.
- **One topology per Docker daemon.** A second instance fails on overlapping subnets, so stop the
  running one (`down`) before starting another.
- The topology may already be up. Check with `docker compose ps` or `docker ps` before rebuilding,
  and prefer showing the participant what is running over restarting it.
