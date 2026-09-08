# AWS hackathon – Kiro + RemotiveTopology + RemotiveCar

Material for the hands-on session. The lab has two halves: **Part 1 — Understand the platform**
(seven exercises, **optional**, a menu rather than a checklist) and **Part 2 — Go creative** (an open
brief where the participant builds a feature and makes every design decision). The only step a
participant genuinely needs from Part 1 is Exercise 1, starting the car, because Part 2 needs it
running. Part 2 is where the session is going and should get most of the time.

## Start here — participant, three steps

You work from **day-1** (this machine, where you cloned this repo) and run the car on **day-2** (an
EC2 box from a prebuilt AMI). Day-1 sets the box up and nothing more; everything in the lab happens
on day-2.

**Prerequisites on day-1:** AWS CLI configured, an EC2 key pair saved at `~/.ssh/my-key.pem`, and the
**"Open Remote - SSH"** extension installed in Kiro (`Cmd+Shift+X`, then reload the window). Details
and the `create-key-pair` command are in
[`participant/INSTRUCTIONS.md`](participant/INSTRUCTIONS.md).

### 1. Set up day-2, from Kiro on day-1

Open this folder in Kiro and say:

> **I'm on the day1 one machine setup day2.**

Kiro runs [`participant/start-day2.sh`](participant/start-day2.sh), which launches or starts your box
from the AMI, copies this whole folder to `~/aws-hackathon` on it, installs the service-account token
and the Kiro context, and verifies all of it. It prints seven numbered steps; read the `[warn]` lines
if there are any. Same thing by hand: `./participant/start-day2.sh` (`--help` for options).

It stops there on purpose. **No lab step ever runs from day-1** — no topology build, no
`docker compose up` — so the car is started where its containers, buses and logs are.

### 2. Connect to day-2 with Remote-SSH

1. In a terminal, `ssh remotive-hackathon` — **leave it open.** It forwards Studio, the broker, the 3D
   car, Android and adb to `localhost` on day-1, and nothing on day-2 is reachable any other way.
2. In Kiro: `Cmd+Shift+P` (macOS) / `Ctrl+Shift+P` → **Open Remote-SSH: Connect to Host** →
   `remotive-hackathon`. A new window opens on the box.
3. In that window, open the folder **`~/remotivelabs-topology-examples`**. That is the car, and its
   `.kiro` symlink is what gives the Kiro there the context for this box.

### 3. Open the lab and start prompting

In the **day-2** window, open `~/aws-hackathon/participant/LAB.md` — `File → Open File…`, or add
`~/aws-hackathon` to the workspace as a second folder if you would rather have both trees in the
sidebar.

Then talk to that Kiro rather than copying commands. A good first message:

> start the car and show me what is running

Part 1 is an optional menu of exercises; Exercise 1, starting the car, is the only one that matters,
because Part 2 needs it running. **Part 2 is the destination** — an open brief where you build a
feature and make every design decision. If something misbehaves,
[`participant/TROUBLESHOOTING.md`](participant/TROUBLESHOOTING.md) has the symptom tables, or just ask
Kiro: on day-2 it can inspect the containers and logs itself.

---

The rest of this file is for whoever maintains the material. The repo is split by audience:

```
.kiro/steering/   always-on + file-matched context for Kiro (this box and the running car,
                  RemotiveTopology, RemotiveCar, models, tests, the Part 2 coaching playbook, and
                  the day-1 setup playbook)
                  (no .kiro/specs — the earlier per-task specs were retired and deleted, superseded
                  by LAB.md Part 2)

participant/      what a hackathon participant needs
  INSTRUCTIONS.md   launch the public AMI, run the steps, access the services, update
  LAB.md            the lab: Part 1 (optional exercises) + Part 2 (the brief) + Appendix
  start-day2.sh     the one command on DAY-1: launch/start the box, copy this folder, run setup,
                    verify — and stop before anything in the lab
  setup-day2.sh     one sourced command on the box: auth + Kiro context + self-check
  ssh_config        ready-made SSH config (VS Code / Kiro Remote-SSH + Studio/broker/Jupyter tunnels)
  update.sh         installed on the AMI as remotive-hackathon-update (repo clone + RemotiveCLI [+bus, images])

organizer/        organizer-only: how the participant AMI is built and operated
  provision.sh          installs everything into the image (Docker, CLI, RemotiveBus, Wireshark, repo)
  99-remotive-motd.sh   login banner baked into the AMI
  build-ami.sh          launches a builder (nested virt), provisions, creates the AMI
  README.md             build + launch reference
  OPEN_ITEMS.md         follow-ups (multi-region, cost, etc.)
  HANDOVER.md           authoring worklog — read `## Current state` first before changing lab docs
```

**Three editing rules that are easy to break.** First, `participant/LAB.md` Part 2 is a *brief* — five
requirements and three hints, no steps, no frame IDs, no routing advice. The mentoring material lives in
`.kiro/steering/go-creative-coaching.md`, which is agent-facing; do not fold it into the lab. Second,
the always-loaded steering must describe a **clean box** — a fresh upstream clone of the examples repo —
so no frame, signal, command or instance invented for Part 2 may be stated there as an existing platform
fact; it both lies about the participant's box and gives away the answer. Third, **no worked solution
ships with this material**: the feature has been built once to prove the brief is solvable, and then
removed on purpose. If a session rebuilds it, remove it again afterwards.
`organizer/HANDOVER.md` carries the check for the second rule.

Participants launch a prebuilt public AMI (see `participant/INSTRUCTIONS.md`) — they do not
need this repo's build tooling.

## How this folder reaches the participant's box

The **whole folder** is `rsync`ed from day-1 to `~/aws-hackathon` on the day-2 box, then
`participant/setup-day2.sh` is sourced once. That script activates the service account and
symlinks `~/remotivelabs-topology-examples/.kiro -> ~/aws-hackathon/.kiro`, which is what puts the
steering in the workspace where the participant edits code.

`participant/start-day2.sh` wraps that whole chain into one command run **on day-1** — launch or
start the box, copy, `setup-day2.sh`, verify — and stops there. **Day-1 runs nothing from the lab**;
the car is built and started from the Kiro window connected to day-2. `.kiro/steering/day1-setup.md`
holds that boundary for the agent, and `hackathon-lab.md` opens with a which-machine-am-I-on table,
because the always-loaded steering is otherwise entirely about day-2.

Consequences worth keeping in mind when editing this repo:

- This folder is the **single source of truth** for steering and lab material. Edit here,
  `rsync` again — nothing is copied into the examples checkout.
- The examples repo stays **unmodified**: the symlink is the only entry we add, and it is hidden via
  that repo's local `.git/info/exclude` (as `.kiro`, no trailing slash — git does not match a
  symlink against a directory pattern). `remotive.yaml` and `.remotive/` also show up untracked
  there, but those are the RemotiveCLI's own, created by `remotive topology workspace init`.
- Nothing here needs an AMI rebuild. The image only has to ship Docker, the CLI, RemotiveBus,
  can-utils and the examples repo.

## Verified facts (2026-09-07, local arm64 Linux, Docker 29.7, compose v5.5, KVM)

- `remotive topology build` with `can_over_udp` + `vlan_using_bridge` produces plain Docker
  bridge networks; SOME/IP stays `172.31.0.0/24` with fixed IPs (GWM .18, IHU .12) because the
  Android guest is configured for `172.31.0.12`.
- `remotivelabs/remotivelabs-cuttlefish:16.0.0_r4-1` is multi-arch (amd64 + arm64), 7.4 GB.
  Boots on arm64 with KVM in ~50 s at 4 vCPU / 4 GB.
- On plain bridge networks the stock container's `init.sh` fails to bridge the guest
  (`Cannot find device "someip"`); it can be fixed without touching the image by naming the
  endpoint (`com.docker.network.endpoint.ifname=someip`). The delivered Android path instead
  uses the example repo's own `instances/android/cuttlefish.compose.yaml`.
- Two Cuttlefish containers on one kernel fail with the stock image (`Port 6600 Bind failed`,
  both use vsock CID 3); a second instance needs a distinct `CUTTLEFISH_INSTANCE_NUM` (CID 4,
  adb 6521, `cvd-mtap-02`, guest on `someip0`). Not needed for the single-topology hackathon flow.
- Docker refuses a second network with the same subnet within one daemon
  (`Pool overlaps with other one on this address space`). Consequence: **one running RemotiveCar
  topology per Docker daemon**, regardless of Cuttlefish.
- Kiro IDE downloads: macOS (arm/intel), Windows x64, Linux `.deb`/`.tar.gz` (Ubuntu 24+ etc.).
  Kiro CLI: Linux glibc 2.34+ / musl; `curl -fsSL https://cli.kiro.dev/install | bash`.
  Steering: `.kiro/steering/*.md` with
  `inclusion: always | fileMatch (+fileMatchPattern) | auto (+name/description) | manual`,
  file refs `#[[file:path]]`. Specs would be `.kiro/specs/<feature>/{requirements,design,tasks}.md`.
  Workspace MCP: `.kiro/settings/mcp.json`.

## Hosting recommendation

The delivered approach is a **prebuilt public AMI** (built by `organizer/build-ami.sh`): each
participant launches their own instance with nested virtualization enabled and runs the four
steps in `participant/INSTRUCTIONS.md`. This gives per-participant isolation and side-steps the
one-topology-per-Docker-daemon limit (each participant has their own daemon).

Part 2 needs no Android — a small instance with 3D car + Jupyter + tests is enough, and is faster to
iterate on — so that half works on any instance type. Part 1 runs the Android car, whose
Cuttlefish container additionally needs `/dev/kvm`: the AMI's launch command enables it via
`--cpu-options NestedVirtualization=enabled` on a c8i/m8i/r8i type.

## Comparison with `remotivelabs-ecu-simulations/private/topology-partition`

Already there: Terraform for a single GCP VM with nested virt (`c4-standard-8`, arm64 metal
commented out), Ansible roles for Docker (MTU 1400), RemotiveBus, WireGuard + VXLAN bridge to
split one topology across two machines, and `topology-up.yaml` that builds the partitioned
instances and starts Cuttlefish with `cuttlefish.compose.yaml` (`modprobe vhost_vsock vhost_net`,
`REMOTIVE_CLOUD_AUTH_TOKEN` from `remotive cloud auth print-access-token`).
Not there: anything AWS, more than one Cuttlefish per host, per-participant isolation, Kiro.
The RemotiveBus/VXLAN partitioning is not needed for the hackathon; the UDP/bridge settings files
replace it. Reuse the Ansible `docker` role idea (Docker + `vhost_*` modules) for the AWS image.

## Local smoke test

Build and run the topology directly from a checkout of `remotivelabs-topology-examples`
(same commands the AMI/MOTD use):

```bash
remotive topology build \
  -f remotive_car/instances/android/main.instance.yaml \
  -f remotive_car/instances/android/cuttlefish.instance.yaml \
  remotive_car/build
docker compose -f remotive_car/build/remotive_car_android/docker-compose.yml \
  -f remotive_car/instances/android/cuttlefish.compose.yaml \
  --profile playback --profile 3dcar up --build
```

## Open points

- Kiro IDE on Linux arm64 is not offered; the dev machine used here is arm64.
- `remotive_car/platform/databases/body_can.dbc` carries stale attributes for a removed frame 110
  (`VehicleSpeed`), so **ID 110 is poisoned** — a new frame there inherits a start value and cycle time
  for a signal that does not exist. On BodyCan0, 105 and 111+ are free.
- Part 2 has never been walked end to end by an actual participant. The feature has been built (by an
  agent, then removed), and the flow has been walked by the author, but nobody has arrived at the design
  from the brief cold. That is open item #11 in `organizer/HANDOVER.md` and the highest-value thing to
  do next.

The full numbered list of open items is in `organizer/HANDOVER.md` (`## Pending`) — this section is only
the long-lived ones.
