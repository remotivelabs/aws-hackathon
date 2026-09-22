# Lab authoring — worklog and handover

Last updated 2026-09-21 (seventh session). Read this before continuing work on `participant/LAB.md` or
the steering files — it is organizer-facing, and nothing in a participant session needs it.

## Seventh session, 2026-09-21 — us-west-1 is the default region

**Both AMIs now exist and are public in three regions**, and `us-west-1` is what day-1 launches into
unless told otherwise.

- **Copied us-east-1 → us-west-1** and published both: x86_64 `ami-0175ecdc439312e2f`
  (`remotive-topology-hackathon-day2-20260919-clean`) and arm64 `ami-04d85e46b4b3d6623`
  (`remotive-topology-hackathon-arm64-20260920-194721`). Snapshots `snap-09b76085cb9152385` and
  `snap-042afce1e599fe298` are public too — an AMI without a public snapshot cannot actually be
  launched by anyone else.
- **The guardrail is per-region, and that is the trap.** `ImageBlockPublicAccess` was
  `block-new-sharing` in all three regions, so `modify-image-attribute` failed with
  `OperationNotPermitted` until it was disabled in us-west-1. Disabled, published, re-enabled —
  the dance already written down in `OPEN_ITEMS.md` §1, now confirmed a second time. All three
  regions verified back at `block-new-sharing`. Note the existing public AMIs in us-east-1 and
  eu-central-1 predate the setting; it only blocks *new* sharing, which is why they stayed public.
- **Key pairs are regional, and this bites the region default.** `my-key` did not exist in
  us-west-1, so the new default would have died at `run-instances`. The public half of the
  existing `~/.ssh/my-key.pem` was imported there; the imported-style (MD5-of-DER-pubkey)
  fingerprint `1e:3b:78:…:74` now matches in both eu-central-1 and us-west-1, so one private key
  works everywhere. Added as step 3 of the `OPEN_ITEMS.md` §1 recipe.
- **Instance types checked, not assumed.** us-west-1 offers `c8i.4xlarge` (x86 default, nested
  virt for Android) and `c7g.metal` (the Arm-on-Arm track), so neither path loses a region.
- **Files changed:** `participant/start-day2.sh` (default region, `ami_for_region`, the
  no-AMI-for-region error), `participant/INSTRUCTIONS.md` (AMI table, Arm overrides, the
  "defaults to" sentence, and the manual-equivalent steps 1–2 plus the teardown command),
  `.kiro/steering/day1-setup.md` (a new "Which region?" row and the AMI row),
  `organizer/OPEN_ITEMS.md` (current-AMI header, §1 turned from a flag into a reusable recipe,
  §3 guardrail note) and `organizer/ARM64_AMI_BUILD_REPORT.md` (region rows).
- **Verified:** `bash -n` on the script, `ami_for_region us-west-1` returns the new ID, and
  `describe-images` shows `Public=True` for both copies.

Also this session, unrelated to regions: `LAB.md` lost its trailing `Status of this lab` section
**and** the `Ground rules change here` section that preceded *Getting unstuck* (commit `f9888bb`).
The status section was facilitator prose duplicated elsewhere, but the ground-rules section was
**participant-facing** and carried the only instruction telling a participant to copy work off the
ephemeral box (`git diff > ~/aws-hackathon/my-feature.patch`) and that one topology runs per Docker
daemon. Those two facts are now in no participant document — worth restoring in the Part 2 opener.

## Current state

Left at the end of the sixth session, 2026-09-19. The material is **participant-ready**, and it
deliberately contains no Part 2 solution.

- **Nothing of the Part 2 feature exists any more, in this repo or on the box.** The organizer's call:
  no stashed answer, the participant and Kiro solve it live. Removed this session — the reference patch
  under `organizer/reference/`, the git stash that held the feature in the examples tree, its
  generated build directory, its two resolved-instance cache entries in `.remotive/`,
  its five Docker images, and the byte-compiled caches and `.venv`s left behind under
  `remotive_car/models/` (root-owned, so they needed `sudo`). Verified after: `grep -r` for the feature
  names finds nothing in either tree, `git stash list` is empty, and `remotive_car/build/` holds only
  `remotive_car_android`. A box-local copy was parked at `~/part2-reference-archive/` during the
  cleanup; it dies with the box, and day-1's git clone is the authoritative history if anyone ever wants
  it back.
- **One branch.** Part 2 is worked on `main` in `~/remotivelabs-topology-examples`. Every "consider a
  branch" instruction is gone from `LAB.md` and the steering; `git status` and `git diff` are the safety
  net and the way work leaves the box.
- **"Start the lab" now means exactly one thing: get the car running.** `git pull`, `workspace init`
  if `remotive.yaml` is missing, `build`, `up -d`, report what came up. No leftover instance to bring
  `down`, no networks to un-collide, no stash to restore — that whole class of caveat went away with
  the cleanup, and `hackathon-lab.md` now says so where an agent will read it.
- **This worklog moved from the repo root to `organizer/`**, and always-loaded steering no longer tells
  every agent to read it first. That pointer was dropping a 750-line authoring log into participant
  sessions; `hackathon-lab.md` now mentions it only in an "if you are editing the lab material" note.
- **Box state: the Part 1 android car is up, detached, 20/20 containers**, profiles `playback` and
  `3dcar`, started in the fifth session and still running through this one. Studio is **not** running —
  `cd ~/remotivelabs-topology-examples && remotive studio --no-browser`; the workspace is already
  initialised, so no path argument and no `workspace init`.
- **Cuttlefish took ~4.5 minutes to reach healthy on that cold start, not the ~90 s recorded
  elsewhere.** `adb devices` said `no devices/emulators found` for the first ~3.5 min even after the
  log claimed `Device connected`, then came good on its own. Worth knowing before declaring the head
  unit broken.
- **The examples repo is at `d9319e7`**, clean apart from the expected untracked `.remotive/` and
  `remotive.yaml`. `~/aws-hackathon` is still not a git repo on the box — by design, see #5.

**Three framing decisions that are easy to accidentally undo:**

1. **Part 1 is optional**; the only thing a participant must do is Exercise 1, start the car. Part 2 is
   the destination. Stated in `LAB.md` three times over, in the facilitator note, and in all three
   agent-facing files. Do not restore language that reads like a checklist.
2. **Always-loaded steering describes a clean box**, never this one. No Part 2 frame, signal, control
   command or instance name belongs in it — naming them both lies about a participant's box and hands
   over the answer. The guard command at the end of the *steering-vs-clean-box trap* entry in *Done*
   still applies; run it after any steering edit.
3. **No worked solution ships.** `go-creative-coaching.md` coaches the decision space, the traps and
   the verification, and stops there. If a future session builds the feature again to check something,
   remove it afterwards.

## Box setup facts (learned 2026-09-17, still true)

Kept because they are about *setting the box up*, not about one session. The second session started
from a **freshly rebuilt box**, which surfaced two facts the earlier worklog did not have:

- **Docker image cache was completely empty** — no Cuttlefish, no `3d-car`, not even
  `remotivelabs/remotive-topology`. First start included a ~7.2 GB Cuttlefish pull (disk 4.7 G → 12 G).
  So "both images are now on disk" in the steering describes intent, not a guarantee; check
  `docker images` first and background the pull while building.
- **The checkout lagged.** It shipped `dcca9b9` (2026-09-11) and needed `git pull` → `d9319e7` to get
  the `_last_values` fix in `playback/local/{pcm,bms}.py`. Confirmed the fix is the reordering of
  `await self.bm.start()` to after the state init. `git pull` is now step one in the steering.
- `remotive topology workspace init` was **not** yet run on this checkout, so `build` refused. See
  *Done* below; this is now documented rather than worked around.

After setup: examples repo on `main` at `d9319e7`, clean apart from untracked `.remotive/` and
`remotive.yaml`. Car up on the known-good instance (`instances/android/main.instance.yaml` +
`cuttlefish.instance.yaml` + `cuttlefish.compose.yaml`, profiles `playback` and `3dcar`), 20/20
containers, `ihu` healthy ~90 s after `up`. Studio on `127.0.0.1:57123`, started with a bare
`remotive studio --no-browser` from the repo.

Verified live this session: `playback` PLAYBACK_PLAYING; ChassisCan0 `123`@5, `140`@50, `141`@10,
`150`@50; `Vehicle.Speed` 59.60 km/h → `UISpeedFrame.uispeed` 16.56 m/s (the `/3.6` in `abs.py`);
SOME/IP `172.31.0.18 → 172.31.0.12` with 20-byte SpeedEvent and 28-byte LocationEvent; Android
`PERF_VEHICLE_SPEED = 7.11 METER_PER_SEC`; 3D car, Android UI, broker API and Studio all answering.

**One new operational finding, learned by causing it.** The car had been started with a foreground
`up --build` inside a session-managed terminal. Trying to hand it off cleanly at end of session,
`docker compose ... up -d` was run first — it reported every container `Healthy` and exited 0, which
*looks* like a successful detach but is not: the original foreground process still owned the
containers, and stopping that process took the entire car down with `Exited (143)`. A second `up -d`
brought it back properly detached, `ihu` healthy in ~80 s, playback resumed on its own. Two rules out
of it, now in the steering: an attached `up` cannot be detached after the fact, and **an agent should
start the car with `up -d` from the beginning** rather than a foreground `up` that dies with the
session. (The lab's own instruction to participants — keep the car in its own terminal — is still
right for a human at a keyboard.)

## Done

### This session (2026-09-19, seventh) — Studio graph for the participant's own instance

Small, single-purpose change at the author's request: Part 2 produces a new or modified instance, and
nothing pointed the participant at Studio to look at it.

- **`LAB.md` Part 2, third hint extended** (no new bullet, no steps): the new instance most likely lives
  next to `hello_world` as `remotive_car/instances/<your-name>/main.instance.yaml`, and it is worth
  opening **as a graph** to check that the ECUs, buses and containers declared are the ones that came
  out. Points back to §1.3 for the URL pattern rather than repeating it. Part 2 stays a brief.
- **`go-creative-coaching.md` §3, one new trap-adjacent bullet** ahead of the DBC-rebuild one: offer the
  graph early, with the `viewMode=instance&view=topology&topologySubView=graph` shape, the reminder that
  `topologySubView` defaults to `tree`, the "pass every `-f`" caveat, and `As YAML` / `show instance`
  for resolved text.
- No design, frame ID, signal or instance name added anywhere; the LAB hint uses a `<your-name>`
  placeholder. Always-loaded steering untouched, so the clean-box guard is unaffected.

**Also this session — the arm64 "Arm on Arm" track.** `INSTRUCTIONS.md` § *The day-2 AMI* gained an
optional track, framed on the fact that car silicon is Arm, so Graviton makes host and target match.
Then the AMI was actually rebuilt for it:

- **`build-ami.sh` takes `ARCH=amd64|arm64`.** x86 behaviour is unchanged. For arm64 it resolves the
  arm64 Ubuntu SSM parameter, defaults to `c7g.4xlarge`, and drops `--cpu-options
  NestedVirtualization=enabled` — Intel-only, and it fails the `run-instances` call on Graviton.
- **`provision.sh` is arch-aware**: `kvm_intel` only on x86_64, and its required packages no longer sit
  behind a `|| true` that could hide a base-tooling failure until PART 2.
- **Built and published**: `ami-01837a4e45a10e866` (us-east-1) and `ami-05ac1fbdea026b519`
  (eu-central-1), same image via `copy-image`, both public with public snapshots. 13.84 GiB of real data,
  cold Docker cache. The 2026-09-18 `ami-0b4c4739e522f410c` is deprecated.
- **Publishing needs the account-level guard dropped**: Image Block Public Access was at
  `block-new-sharing` in both regions; disabled, published, re-enabled, verified back on.
- **Unverified on purpose** — the organizer chose to skip the on-box check for now. Nothing has been
  launched from either image. That check is the open item; see `ARM64_AMI_BUILD_REPORT.md`.
- **One AWS-CLI trap worth keeping**: on the authoring machine `AWS_PROFILE` is not set in fresh shells,
  so `aws` falls back to a `[default]` profile that uses the newer `aws login` flow and reports
  *"Your session has expired"* even right after `aws sso login`. Pass
  `AWS_PROFILE=PowerUserAccess-380142015251` explicitly; it looks exactly like a credential-expiry
  problem and is not.

### This session (2026-09-19, sixth) — de-polluted for a participant start

The organizer's brief: the Part 2 feature must not leak into Part 1 or into the material a participant
starts from, there is to be **no stashed solution** (Kiro and the participant solve it live), there is
**one branch**, and *"start the lab"* must mean nothing more than starting the car.

**Removed, everywhere:**

- `organizer/reference/` — the re-appliable patch, the new files, `apply.sh`, its README — moved off the
  repo to `~/part2-reference-archive/` on the box while the cleanup was verified. It dies with the box;
  day-1's git clone is the history if anyone wants it.
- The examples-repo git stash that held the feature (archived first as a patch in the same place, then
  `git stash drop`). Also its generated build directory, its two resolved-instance entries in
  `.remotive/instances/`, its five Docker images, and the byte-compiled caches, `.pytest_cache`,
  `.ruff_cache` and `.venv`s it left under `remotive_car/models/` — those were root-owned from container
  runs and needed `sudo`. Three of them (`nodeids`, two `.pyc`) contained the feature's names.
- Every pointer to the reference: `hackathon-lab.md`, `product.md`, `LAB.md`'s status section, `README.md`.
- Every remaining feature name in agent-facing prose. `go-creative-coaching.md`'s §6 worked reference is
  replaced by *Shape and scale* — how big the job is and how to pace it, with no design in it — and the
  verification recipes now use placeholders instead of the reference's frames and notebook.

**Changed:**

- **`hackathon-lab.md` now defines "start the lab"**: `git pull`, `workspace init` if needed, `build`,
  `up -d`, report what came up, then offer the menu. It explicitly says there is nothing to hunt for
  first — no stash, no competing instance, no colliding networks — because that is now true.
- **One branch.** `LAB.md` Part 2 says work on `main` and shows `git status` instead of `git checkout -b`;
  the steering ground rule says the same.
- **This worklog moved to `organizer/`** and its `## Resume here` became `## Current state`. Always-loaded
  steering no longer tells every agent to read it first — that pointer was pulling a 700-line authoring
  log into participant sessions. `hackathon-lab.md` mentions it only under *If you are editing the lab
  material itself*.
- **Stale retired-task references cleaned out of `LAB.md`** — "hackathon task 1/2/3" in the intro
  screenshot notes, §4.2's DIM paragraph and exercise 7's closing table. They now read as raw material
  and as a lead-in to Part 2.
- **Exercise 1.1's terminal callout was wrong for the normal case.** It described a foreground `up`
  owning the terminal, but Kiro starts the car detached; it now covers both and says a detached car
  cannot be adopted by a later foreground `up`.
- **Two operational facts preserved rather than lost with the reference**, now traps in
  `go-creative-coaching.md`: a stopped instance can leave networks behind and the next `up` fails on
  `same bridge name` (invisible in `docker ps`), and an instance with BMS but no PCM shows SoC as SNA.
  Pending #14 closed by absorption; #11 rewritten around "nobody has arrived at the design cold".
- **The clean-box guard is no longer a regex.** With the names gone from the repo there is nothing to
  grep for, so the check is now "every frame, signal, command and instance named in always-loaded
  steering must exist in a fresh clone", with the `git show HEAD:` commands to prove it.

**Verified after the cleanup:** `remotive topology build` still succeeds for the android instance; the car
is untouched at 20/20 containers with none unhealthy, `topology-ChassisCan0` at the known-good
`{123: 5, 140: 50, 141: 10, 150: 50}` and playback `PLAYBACK_PLAYING`; the examples repo is on `main` at
`d9319e7`, clean apart from `.remotive/` and `remotive.yaml`, with an empty stash list; a sweep of every
`participant/`, `organizer/` and `.kiro/` path mentioned in any `.md` or `.sh` finds no dangling
reference beyond the known prose ones (`.kiro/specs`, `.kiro/settings/mcp.json`, `organizer/archive/`,
and this file's own history entry for `organizer/reference/`).

- `participant/LAB.md` (~1060 lines): exercises 1–7 written and every command executed on the box.
  3 = four views of the same traffic (candump / decoded signals / frame-distribution / SOME-IP
  tcpdump), 4 = read the platform, 5 = trace the speedometer end to end, 6 = change the car at three
  depths, 7 = break an ECU on purpose. Intro carries the protocol-accuracy paragraph.
- **Bring your own ECU** section added at the end of exercise 4: the four kinds of ECU already in the
  car, the FMU swap (`models/bcm.fmu.instance.yaml`, `instances/fmu/main.instance.yaml`,
  `tests/tester_fmu.instance.yaml`), real hardware, and a pointer to the Arm digital-twin post
  (highlight only, not part of the lab).
- Wireshark "enable it in Settings" prerequisite removed everywhere (`LAB.md`, `INSTRUCTIONS.md`,
  `TROUBLESHOOTING.md`, steering) — it is on by default now.
- Steering refreshed: BMS/PCM on ChassisCan0 with the four-frame table and the SNA convention, the VSS
  playback channel, `MotorPower`/`BatterySoC` in the 3D mapping, the restbus correction (a plain
  `ECU: {}` transmits nothing; a dead model leaves frames frozen), `ControlClient` must be an async
  context manager, and state must be initialised before `bm.start()`.
- `_last_values` race notes updated to "fixed upstream" in `LAB.md` and steering.

### This session (2026-09-17, second)

- **`LAB.md` exercise 2 gained §2.4 "Drag the seekbar"**, placed after the time-series panel so there
  is a video and a chart to watch while scrubbing. Renumbered 2.4→2.5 (frame distribution) and
  2.5→2.6 (save), fixed the `(2.5)` back-reference in 2.1, bumped the exercise to ~15 min, and fixed
  `Topplogy Runtime` → `Topology Runtime`. Two points made, both verified on the box:
  - Dragging the seekbar moves **the car**, not the dashboard: the recording is upstream of five
    playback models, so a seek to 3 s carried VSS 56.56 km/h → CAN 15.71 m/s → Android VHAL
    15.89 m/s together. CLI equivalents documented (`status`/`seek`/`pause`/`play`, offsets in µs).
  - **Pausing hands the participant exercise 7 five exercises early.** All frames keep arriving on
    cycle, but `BatteryStatus.StateOfCharge` → `1023` (10-bit SNA), `MotorInfo.MotorSpeed` → `65535`
    (SNA), and `UISpeedFrame.uispeed` **freezes** — BMS/PCM have the
    `SNA_ON_MISSING_INPUT_TIMEOUT=3` watchdog, ABS has none. `play` restores everything.
- **Steering now documents `remotive topology workspace init` as required**, in both
  `hackathon-lab.md` and `remotive-topology.md`, with an explicit "do not take the `--no-workspace`
  flag the error suggests" — it disables caching *and* leaves the checkout unregistered so Studio
  cannot resolve it or attach to the running instance. Also recorded: the init writes `remotive.yaml`
  + `.remotive/` into the examples repo and that is an **expected exception** to the read-only rule;
  build output must stay inside the workspace (`/tmp` → `E024`); and the MOTD carries the canonical
  sequence and should be read before inventing commands. `git pull` added as the first step.
- **Studio start command corrected** in `hackathon-lab.md`: `cd` + bare `remotive studio
  --no-browser`, since passing the path is unnecessary once the workspace is registered.
- **`{}` vs `mock: {}` semantics written up in `remotive-topology.md`**, verified against the emitted
  compose after a question from the author. `{}` emits *only* `<ECU>-broker.com`; `mock: {}` emits the
  broker **plus** a `<ecu>-mock` container running `remotivelabs.topology.cli.mock`. `{}` never becomes
  a mock in either instance. In `hello_world` the mocks are SCCM/PAM/TCU/ABS/PCM and the plain brokers
  are DIM/FLCM/HVAC. If a tool labels a broker-only ECU as a mock, the generator disagrees.
- Two related resolver gotchas recorded in the same place:
  - **`{}` is a floor, not a lock.** `hello_world` declares `RL: {}` yet RL gets a full model, because
    `models/rl_rlcm.instance.yaml` is in its `includes:` and the include wins. Directly relevant to
    task 1: do not assume `DIM: {}` must be removed — resolve and check.
  - **`show instance` is only as complete as the `-f` files passed.** Resolving
    `android/main.instance.yaml` alone reports IHU as a Python model; the running car has Cuttlefish,
    because the second `-f` overrides it. The resolver also prunes ECUs no instance mentions, which is
    why DIM is absent from the `android` output despite being in `chassis_can.dbc`'s `BU_`.
- Exercise-2 summary line in `hackathon-lab.md` now mentions the seekbar and the pause behaviour.
- New **"Facts learned the hard way (2026-09-17, second session)"** block in `hackathon-lab.md`: empty
  image cache, `git pull` first, the pause demo, seek moving the whole car, the healthy-start smoke-test
  numbers, and the `timeout ... | grep` buffering trap with `signals subscribe` (redirect to a file).
- **Clickable Studio file links added to `LAB.md`.** The full query schema, read off `BVt()` in
  `/assets/index-*.js`: `path`, `viewMode`, `view`, `topologySubView`, `entityId`, `signalSubView`,
  `signalScope`, `signalFilters`.

  ```
  http://localhost:57123/files?path=<url-encoded>&viewMode=<mode>&view=topology&topologySubView=graph
  ```

  `viewMode` (from `Nlt()`/`Flt`): `instance`, `platform` (platform files **and** signal databases —
  DBC/LDF), `dashboard`, `text` (every textual type, always available). `signal-database` exists as a
  label but is never offered. Video, audio and image files get no view modes. File-type detection is
  **server-side**, so it cannot be enumerated from the bundle.

  `view` is `topology`/`signals`; `topologySubView` is `graph`/`tree`/`yaml` via `ZAt()`; `entityId`
  takes `ecu:<Name>` or `channel:<Name>` via `dCt()`.

  **`topologySubView` defaults to `tree` — found late, after the author asked why the links did not go
  straight to the graph.** Every link written before that landed on the tree while the prose told the
  participant to click **As graph**. All graph-intent links now name it explicitly; verified none are
  left (`viewMode=(platform|instance)` with no `topologySubView` returns nothing).

  Where the links went: the convention is explained once in §1.3 where Studio starts (including the
  URL pattern, so participants can build their own, and the caveat that links need Studio running and
  the tunnel up); §3.4 now attributes port 16000 / the two IPs to `someip.platform.yaml` and the
  service and event ids, FLOAT32 type and byte order to `someip.fibex.xml`, with the *where vs what*
  split spelled out; §4.1 links both `-f` files and repeats the "resolution is only as complete as the
  files you name" caveat; §4.2 links `chassis_can.dbc`; §4.3 links both Ethernet files; §4.4 links the
  platform file and adds the point that it contains **no** ECU list — the graph's ECUs are derived from
  the DBCs; and the *What each file is authoritative for* table is now a link index covering all four
  databases, both Ethernet files, the platform file, three instance files and the recording's platform.
  All 11 linked paths verified to exist on disk.
- **§3.4's two links point at `viewMode=text`, deliberately, and say why.** A platform file opens as a
  *graph*, which shows the network's shape but none of its numbers — no addresses, no port, no VLAN —
  so the section that asks the participant to account for `16000` and the two IPs has to land in the
  raw view. Same for the FIBEX and its service/event ids and parameter types. A short callout explains
  the toolbar toggle and that the graph and the raw file answer different questions. **Scoped to 3.4
  only** per the author when first added; §4.2 followed in the same session for the same reason.
- **The viewer UI is now pinned down, after I described it wrongly twice.** There are **two** controls:
  the **`⋮`** menu → **View Mode**, which picks the viewer (**Text** / **Platform** for a database,
  **Text** / **Instance** for an instance file, and what the URL's `viewMode` selects); and, inside the
  graph viewer, a toolbar with **Topology** / **Signals** tabs plus three layout buttons tooltipped
  **As tree**, **As graph**, **As YAML** (`YAt` in the bundle).
  - My first description called it a toolbar toggle — wrong, corrected in §1.3, §3.4 and §4.2.
  - My second claim, that "there is no YAML label in the bundle", was **also wrong** and the author was
    right: it is `tooltip:"As YAML"`, which my grep for a bare `label:"YAML"` missed. Both routes now
    documented.
  - They are **not equivalent**, which the lab now says: `View Mode → Text` shows the file as written on
    disk, while **As YAML** renders Studio's resolved YAML (for an instance, all `includes:` followed —
    the same content `show instance` prints). §4.2 spells this out, because reading DBC *syntax* needs
    `Text` specifically.
- **§4.2 switched to `viewMode=text`** for `chassis_can.dbc`, with an explanation that a DBC opens as a
  graph and the raw syntax needs `Text`. It forward-references 4.4, which legitimately wants `Platform`
  — so the menu gets used twice for the same file, which is the point.
- **The ASCII art in *What you are looking at* is replaced by a Studio screenshot**,
  `participant/media/remotive-car-android-graph.png` (3444×1972, supplied by the author): the running
  `android` instance as a Studio topology graph. Reasons it is a better opener than the diagram it
  replaced, all now drawn out in the prose next to it:
  - It is **generated from the instance file**, not hand-maintained, and the participant can reproduce
    it in 1.3 via the link plus **Topology** → **As graph**.
  - **Node colour encodes the kind of ECU** — magenta behavioral model, green bare RemotiveBroker, blue
    container. So `HVAC` renders green while everything else is magenta, which is a *visual* statement
    of the `{}`-vs-model distinction from earlier this session, and a natural lead-in to task 2. `IHU`
    carries the container icon.
  - **GWM appears on three rows** with a `3` badge and dashed "same ECU, another channel" links, which
    is the gateway concept without needing a paragraph.
  - **DIM is visibly absent**, which sets up task 1 and exercise 4.2.
  - The five buses are rows, so bus membership is readable at a glance; a small table maps them.
  The prose keeps what the ASCII art carried that the graph does not: that `playback` feeds the `VSS`
  row, and that the five ECUs on that row are what turn recorded signals into real CAN traffic.
  Alongside the screenshot the intro links the same instance three ways — `topologySubView=graph`,
  `=tree` and `=yaml` — the last being the resolved instance, which is what `show instance` prints in
  exercise 4, so the intro and 4.1 now point at the same artefact from both ends.
- **`entityId` demonstrated in §4.4** with `ecu:GWM` and `channel:ChassisCan0`, as the answer to "the
  graph is busy, take me to one thing". Note the colon must be encoded (`ecu%3AGWM`).
- **The database links in the index table were switched from `platform` to `text`.** That row is about
  frames, senders, receivers, layout and cycle time — none of which the graph shows. Consistent with
  §4.2 now.
- **Source files link into the editor, not Studio.** `LAB.md` now has two kinds of link, and §1.3 says
  which is which: platform and instance files go to Studio to be *looked at*; source files go to Kiro to
  be *changed*. Model code has nothing to render in Studio, and exercises 6 and 7 are entirely about
  editing it. Implemented as filesystem-relative markdown links —
  `[...](../../remotivelabs-topology-examples/remotive_car/...)` — which Kiro resolves against the file's
  own location, so they work whichever folder is open. Eight links, all verified to resolve:
  `playback/local/abs.py` (×2, exercise 5 hop 2 and 6.3), `models/gwm/python/gwm/__main__.py`,
  `bcm/state_machines/turn_signals.py`, `bcm/__main__.py`, `platform/databases/chassis_can.dbc` (6.2,
  the one file that is edited rather than read), `common/3d_car/3d_car_mapping.yaml` (6.1) and
  `recordings/tesla.recordingsession.yaml` (2.2). See pending #9 for the sibling-directory caveat.
- **Deliberately not changed**, per the author: the `3d-car` image tag note (pulling latest at the
  start of every session makes it moot) and the "both Cuttlefish images are now on disk" line at
  `hackathon-lab.md`, left as-is with the caveat captured here and in the new facts block instead.

### This session (2026-09-18, third) — LAB.md Part 2 built end to end

The lab was split into two halves and the second half's feature was implemented, verified and captured.

**`LAB.md` is now two parts.** `# Part 1 — Understand the platform` over the unchanged exercises 1–7,
with an intro framing the aim as being able to answer *what is on this bus, who put it there, which
file decided that, and how would I prove it*. `# Part 2 — Go creative` replaced the old 33-line *Then
build something* section. A `# Appendix` H1 was added so the trailing sections stop reading as Part 2
subsections. Part 2 is deliberately **56 lines**: the five requirements verbatim, the three hints
verbatim, the changed ground rule (this part writes to the repo for real; `git status` is the safety
net; suggest a branch), and "ask Kiro for options and trade-offs rather than answers". **No routing
guidance, no frame IDs, no sub-exercises, no verification commands** — the design decisions are the
exercise.

**The coaching material went into steering instead.** New
`.kiro/steering/go-creative-coaching.md` (238 lines, `inclusion: auto` with a `description` covering
the Part 2 topics, plus an explicit pointer from the always-loaded `hackathon-lab.md` in case auto
does not fire). It opens by saying it is agent-facing and must not be pasted at a participant, then:
coaching stance; the decision space as options with trade-offs (routing, stimulus, where the decision
lives, latching, signal width); the traps that cost real time; verification recipes; an incremental
ladder framed as something to offer only to someone with no foothold. (It originally ended with a
worked reference; that section is now about scale and pacing instead — no stored answer.)

**The feature itself was built and verified on `main` in the examples repo, then removed again** — see
*Current state*. It was a new small instance (12 containers, ~25 s cold start, its own tester fragment),
one new frame on the chassis bus carrying charger status from BMS, a mirrored frame on the body bus via
GWM, a control command to plug the charger in, a set/clear trigger pair in the BCM turn-signal state
machine with an edge-driven evaluator, an end-to-end pytest suite, unit tests for BCM and BMS, and a
Jupyter notebook for hand-driving it.

**Deliberately not recorded here, and not anywhere else:** the frame IDs, signal names, command name,
instance name and file names it used. They are the exercise. What is worth carrying forward is the
*shape* — recorded in `go-creative-coaching.md` §6 as scale and pacing, not as a design.

**What the build taught, and is worth keeping:**

- **One design bug, and it is the one a participant will hit.** The first implementation cancelled a
  *driver-initiated* hazard when the pedal was released, because the rising edge latched its own flag
  while the hazard was already on. Fixed by capturing the hazard state at the rising edge and returning
  early on both edges if the driver already had them on. This is §2d in the coaching file.
- **Verified cold**: 12/12 containers, 3D car HTTP 200, Jupyter HTTP 302, end-to-end suite green with
  exit 0, both unit suites green, notebook executed headlessly with no cell errors, and failure proven
  by stubbing the decision out (red, exit 1). So the brief is solvable and demoable within a session.
- **The interactive path was human-verified end to end** by the author on 2026-09-18 — notebook drives
  the charger and the pedal, hazard flashes visibly on the 3D car at :3000.

**One participant-facing addition from that session**: Part 2's ground rules now say the box is
disposable and show how to get work off it (`git diff > ~/aws-hackathon/my-feature.patch` plus a
reminder to check `git status` for new files).

**Part 1 is explicitly optional**, added after the first draft read as though it were a checklist. The
header now says the lab has two halves "and only one of them is the destination"; Part 1's intro opens
"Optional, and pick as you please" and names **Exercise 1 (start the car) as the only one that
matters**, because Part 2 needs a running car and nothing else from Part 1 is a prerequisite; a short
subset (1, 3, 6 — start, observe, modify) is suggested for anyone who wants a taste first; and Part 2
opens "This is the part that matters … if you skipped the rest, start here." Mirrored into the
facilitator note in *Status of this lab*, into `product.md` and `hackathon-lab.md` ("do not march a
participant through it by default"), and into the coaching playbook ("do not assume a participant
worked through it, and do not send them back to it before helping — fill in what they need as it comes
up, that is cheaper than a detour").

**Specs retired, then deleted.** `.kiro/specs/{instrument-cluster,hvac-climate,degraded-component-warning}`
were first moved to `organizer/archive/specs-superseded/`, then **deleted outright** at the author's
request at the end of the session — they were superseded by the Part 2 brief and there was no reason to
carry 29 KB of retired material into the new repo's history. `organizer/archive/` is gone. DIM and HVAC
remain genuinely unimplemented and fair game, but as **raw material rather than a spec**: whoever picks
one up decides what it should do, the same way Part 2 works. Every reference reconciled: `product.md`'s "three hackathon tasks" section rewritten around the two-part
session; `remotive-car.md`'s "(task 1)"/"(task 2)" annotations neutralised to "unimplemented ECU";
`hackathon-lab.md`'s ground rules rewritten for the Part 1/Part 2 split; `README.md`'s tree updated.
`participant/` now contains zero references to the retired tasks.

**Factual steering corrections**, all from things that bit during the work:

- `remotive-car.md` claimed **BMS is "not included" in `hello_world`** — wrong, it runs a real model via
  `includes: models/bms.bm.instance.yaml`. Fixed, and the row now mentions the charge port.
- `remotive-car.md` gained a control-command table and the poisoned-ID-110 warning. It *also* gained
  the Part 2 frames and its instance, which was then **reverted** — see the next entry.
- **`uv` and `ruff` are not installed on the box**, contradicting `python-models.md` ("uv is installed")
  and `testing.md`'s `uv sync && uv run pytest`. Both corrected with the working container recipe.
  `testing.md` also gained the CI entry point and "always prove a new test can fail".
- `remotive-topology.md` gained a *Writing a minimal instance* section with the three things that bite.
- `hackathon-lab.md` gained the Part 1/Part 2 handling split.

### The delivery model, stated once so it stops being re-derived

**Day-1 (the participant's own machine) holds the git clone. Day-2 (the box) gets an `rsync -a
--exclude .git`.** Confirmed with the author 2026-09-18 after a wrong turn in the other direction — an
earlier edit added a "clone it on day-2" path to `INSTRUCTIONS.md`, which was reverted. `provision.sh`
does clone a repo, but it is the **examples** repo, not this one; nothing on the AMI fetches
`aws-hackathon`.

Consequences worth holding on to:

- The box has **no git history for `aws-hackathon`** and that is intentional, not an oversight —
  see pending #5, now closed.
- The committed service-account token travels with the folder by design — pending #15, reframed.
- `INSTRUCTIONS.md` step 4 now says the landing path must be `~/aws-hackathon` (`setup-day2.sh` derives
  its symlinks from its own location), explains why `--exclude .git` is there, and warns that work must
  be carried **back** to day-1 before teardown. The day-1 prerequisite now says "cloned on day-1" rather
  than the vaguer "checked out".

### Participant-facing fixes to `INSTRUCTIONS.md` (it is the front door, and it had drifted)

- Step 7 described **"five exercises"** and **never mentioned Part 2**. Someone following the
  instructions literally would not have known the main event existed. Now names both halves, marks Part 1
  optional with Exercise 1 as the floor, says Part 2 is where the session is going, offers "start the car
  and show me what is running" as a first prompt, and links `TROUBLESHOOTING.md`.
- Step 4 still promised the symlink delivered "the three task specs". They were deleted; the sentence now
  describes the steering only.

### Cold-start audit: can a fresh Kiro on a fresh box run the lab?

Traced end to end at the end of the session. The delivery chain is **clone on day-1** → `rsync -a
--exclude .git` to day-2 → `source participant/setup-day2.sh` → symlink
`~/remotivelabs-topology-examples/.kiro -> ~/aws-hackathon/.kiro` → Kiro opened on the examples repo sees
all seven steering files. Verified:

- The symlink resolves and the coaching file is readable through it.
- **No dangling path references** anywhere in the repo. A sweep of every `participant/…`,
  `organizer/…` and `.kiro/…` path mentioned in any `.md` or `.sh` found five apparent misses, all
  benign: `.kiro/settings/mcp.json` and `.kiro/specs/<feature>/…` are README prose about where Kiro
  config *would* live, and the `organizer/archive/` ones are history entries in this file.
- The **start command is byte-identical** in `hackathon-lab.md`, `INSTRUCTIONS.md` and `LAB.md`, and all
  three files it references exist in upstream `HEAD`.
- Steering carries the agent-specific rule that matters most: start the car **detached** with `up -d`,
  because a foreground `up` in a session-managed terminal dies with the session and takes the car down.
- Exercise count is consistently **seven** in all three places that state it.

**One fix came out of the audit.** `INSTRUCTIONS.md` step 7 — the front door — still described "five
exercises that take you from car running to I know where every signal comes from" and **never mentioned
Part 2 at all**. A participant following the instructions verbatim would not have known the main event
existed. Rewritten to name both halves, mark Part 1 optional with Exercise 1 as the floor, say Part 2 is
where the session is going, suggest "start the car and show me what is running" as a first prompt, and
link `TROUBLESHOOTING.md`.

**`participant/service-account.json` is load-bearing, which sharpens pending #15.** `setup-day2.sh`
sources `remotive-auth`, which reads the `token` field out of that JSON and exports
`REMOTIVE_CLOUD_AUTH_TOKEN` into the shell, `~/.ssh/environment` and (best-effort) `/etc/environment`.
Without it there is no token, the broker exits on startup and every dependent container fails. So
git-ignoring the file to keep the credential out of history **breaks the setup path** — the choice is
genuinely between a private repo, distributing the file out of band with a clear error when missing, or
rotating after the event. It is not a free fix.

### Root `README.md` refreshed

It still described a "~1 h hands-on" built around the retired per-task specs ("Tasks 1–3 need no
Android", "the specs were written but not executed through Kiro yet"). Now it opens with the two-part
structure and Part 1 being optional, lists `HANDOVER.md` in the tree, states the **two editing rules**
(Part 2 stays a brief; always-loaded steering describes a clean box), and its *Open points* section
drops the stale spec references, keeps the poisoned-ID-110 warning and adds "Part 2 has never been
walked by a real participant" with a pointer to the numbered list rather than duplicating it.

### The steering-vs-clean-box trap (correction pass, do not undo this)

**Always-loaded steering must describe a clean box, not the box it was written on.** The first pass put
the Part 2 feature's two frames, its BMS control command and its instance into `remotive-car.md`,
`hackathon-lab.md` and `remotive-topology.md` as plain platform facts. Two things wrong with that, the
second worse than the first:

1. **Factually false on a participant box.** They get a fresh upstream clone; none of it exists, and as
   of the sixth session nothing anywhere can make it exist again.
2. **It hands over the Part 2 answer.** Those frames, that command and that instance *are* the exercise.
   An agent with them in always-loaded context will volunteer them the first time anyone asks what is on
   ChassisCan0, and the design work the brief exists to provoke is gone.

All of it was reverted to clean-box truth. As of the sixth session the names live nowhere at all — not in
the steering, not in `organizer/`, not in this file — which is the strongest form of the same rule.

Clean-box facts re-verified against `git show HEAD:` rather than the working tree, which at the time
still had the feature applied:

| Claim | Verified |
|---|---|
| ChassisCan0 has **four** frames: 123, 140, 141, 150 | `grep '^BO_ ' chassis_can.dbc` |
| so **142–149 and 151+ are free** | arithmetic on the above |
| BodyCan0 free IDs are **105 and 111+** (100–104, 106–109, 200, 300 used, 110 poisoned) | `grep '^BO_ ' body_can.dbc` |
| control commands are only `set_batterystatus_stateofcharge` and `emergency_mode` | `git grep` over `models/` |
| **three** buildable instances: `android`, `hello_world`, `fmu` | `git ls-tree` |
| BMS *is* a real model in `hello_world`, via `includes:` | `bms.bm.instance.yaml` in its `includes:` |

The `fmu` instance was found during this check and had been missed entirely — `hello_world`'s shape with
BCM as an actual FMU (`models/bcm/fmu/bcm/model/BCM.fmu`) and BMS/PCM as mocks. Now documented in
`remotive-car.md`.

**Guard for future sessions.** There is no regex for this one, because the names worth catching are
exactly the names this repo refuses to write down. The check is: every frame, signal, control command and
instance named in always-loaded steering must exist in a **fresh clone** of the examples repo. Resolve
any doubt against the repo, not the working tree:

```bash
cd ~/remotivelabs-topology-examples
git show HEAD:remotive_car/platform/databases/chassis_can.dbc | grep '^BO_ '
git ls-tree -r --name-only HEAD remotive_car/instances | grep instance.yaml
git grep -n 'control_handlers' HEAD -- remotive_car/models
```

If a session rebuilds the feature to check something, grep the steering for *its* names before finishing,
then remove the feature. Free-ID *ranges* are honest platform documentation and give nothing away — it is
the names that spoil the exercise.

### This session (2026-09-18, fourth) — day-1 → day-2 collapsed into one command

The day-1 side was the last part of the chain still assembled by hand: five AWS commands, an IP pasted
into `ssh_config`, an `Include` line, an `rsync` and a sourced script, spread over four numbered steps
in `INSTRUCTIONS.md`. It is now **`participant/start-day2.sh`**, run on day-1, and the trigger phrase
*"I'm on the day-1 machine, set up day-2"* maps onto it.

**What the script does**, in seven printed steps: preflight this machine (`aws`/`ssh`/`rsync`,
`sts get-caller-identity`, the `.pem` — and it `chmod 600`s a loose key); reuse or create the
`remotive-hackathon` security group and authorise SSH from the current day-1 IP; **resolve the box**;
patch `ssh_config`'s `HostName` and prepend the `Include` line to `~/.ssh/config` (backed up first);
`rsync -a --exclude .git` the folder to `~/aws-hackathon`; run `setup-day2.sh` over SSH plus a
`remotive-hackathon-update --repo`; then verify.

**The design decisions, since they are the part worth arguing with:**

- **"Start the AMI" was ambiguous and is now answered by precedence**, cheapest first: an instance
  tagged `Name=remotive-hackathon` that is **running** is reused untouched; a **stopped** one is
  started, so its disk and any work on it survive; only with no match does it `run-instances`. Two or
  more matches **fails** and asks for `--instance-id` rather than guessing — the one-box-per-participant
  rule made a silent choice the wrong default.
- **Verification happens in a fresh non-interactive SSH session**, not in the session that sourced the
  setup. That is the only check that proves what actually matters: `PermitUserEnvironment` +
  `~/.ssh/environment` reaching the commands Kiro/Remote-SSH runs. A token that only lives in an
  interactive shell is precisely the failure this catches, and it was invisible before.
- **It never uses the `remotive-hackathon` alias for its own SSH**, always `-i <key> ubuntu@<ip>` with
  `BatchMode=yes`. Connecting via the alias would drag in six `LocalForward`s and collide with the
  participant's tunnel session.
- **Nested virtualization is added only on `c8i`/`m8i`/`r8i`** and any other type is a *warning*, not a
  failure — Part 2 needs no Android, and refusing would block a perfectly good cheap box.
- **`~/.ssh/config` is edited by default** (`--no-ssh-include` opts out), with a timestamped backup.
  Justified because the `Include` line is what makes the host appear in **Kiro's Remote-SSH list**, so
  without it the handover step cannot happen.
- **bash 3.2**, which is what macOS still ships, so no associative arrays and empty arrays expand as
  `${arr[@]+"${arr[@]}"}` to survive `set -u`.
- `--skip-aws` re-runs copy+setup against a box already up (the normal loop after editing this folder),
  `--launch-only` stops once SSH answers, `--no-update` skips the repo refresh.

**The ambiguity the author actually asked to kill: no lab steps from day-1.** The script stops after
step 7 and says so, and that boundary is now stated in four places, agent-facing and
participant-facing:

- **`.kiro/steering/day1-setup.md`** (new, `inclusion: auto`, name *Day-1 setup of the day-2 box*) — the
  trigger phrase, the one command, a hard "do not run `build` / `compose up` / `candump` / Studio, not
  locally and **not over SSH from here**", the four-step Kiro Remote-SSH handover, a table of the
  settled ambiguities so they are not re-litigated in chat, cost/teardown notes, and a failure table.
  It also says to ask before anything destructive: launch/start/copy is what the phrase authorises,
  terminate is not.
- **`hackathon-lab.md` now opens with a which-machine-am-I-on table.** That file is always-loaded and
  begins "This is the hackathon day-2 box", which is simply false in the day-1 workspace — the ambiguity
  was baked into the steering itself. The table keys off the workspace root (`remotive_car/` present or
  not) and sends day-1 to the new file.
- **`INSTRUCTIONS.md`** gained an unnumbered **Quick start** section before step 1, `> Done by
  start-day2.sh step N` notes on steps 1–4, a "**these run on the box, never from day-1**" banner on
  step 5, "from here on, work in the day-2 window" on step 7, and three troubleshooting bullets.
  **Existing step numbers were left alone on purpose** — `LAB.md` and the prose both cite "step 4" and
  "step 7".
- **`README.md` now opens with a three-step participant path**, because the root README is what
  somebody actually opens first and it was entirely maintainer-facing: day-1 prerequisites, *say
  "I'm on the day1 one machine setup day2."*, connect with Remote-SSH (tunnel session first, then the
  window, then open `~/remotivelabs-topology-examples`), and open `participant/LAB.md` in the day-2
  window. A `---` plus "the rest of this file is for whoever maintains the material" separates it from
  the tree and the verified-facts sections. The trigger phrase is quoted **verbatim in both**
  `README.md` and `day1-setup.md`, so the steering matches what the participant is told to type —
  including the "day1 one" wording.
- **The LAB.md-is-not-in-the-folder wrinkle is now stated** in all three places that describe the
  handover (`README.md`, `day1-setup.md`, the script's closing block): the day-2 window opens
  `~/remotivelabs-topology-examples`, so the lab has to be opened with `File → Open File…` or by
  adding `~/aws-hackathon` as a second workspace folder. That is pending #9 written down where a
  participant will hit it, rather than left as a known oddity.
- **`README.md`**: tree entry plus a paragraph in *How this folder reaches the participant's box*.

**Verified locally, which is as far as it goes:** `bash -n` clean on bash 3.2.57, `--help` renders,
unknown-option and missing-key paths fail with the intended message and exit 1, and the `awk` that
rewrites `HostName` was tested against a copy of `ssh_config` (correct line replaced, line count
unchanged, nothing else touched). **Nothing was run against AWS** — see pending #16.

## Pending

1. **Exercise 6.3 rework — decided, not yet done.** Promote the BCM blink rate
   (`models/bcm/python/bcm/state_machines/turn_signals.py`, `blink_interval_in_sec: float = 1.0`, used
   from `bcm/__main__.py` ~line 126) to the main model-level change; demote the `abs.py` `/3.6 → /1.0`
   unit bug to a clearly-marked optional aside with its revert. Rationale: exercise 7 already breaks
   things and does it better; 6.3 should build something. Caveat to write down: blink verification
   depends on the recording signalling a turn, which is intermittent within the 60 s loop — verify via
   the exercise-2 dashboard chart and `--on-change-only`.
2. **The VHAL gRPC swap — blocked on one observation.** See below.
3. ~~**Specs rework**~~ — **CLOSED as superseded, 2026-09-18.** `LAB.md` Part 2 replaced the three
   specs with a single open brief, so there was nothing left to reconcile. The specs were archived and
   then **deleted** at the author's request — see the *Specs retired, then deleted* entry in *Done*.
   `LAB.md`'s *Then build something* section, which carried the reconciliation notes, was replaced by
   the Part 2 brief. `.kiro/specs/` and `organizer/archive/` are both gone.
4. **Re-run exercises 3–7** end to end after any instance change and fix drift.
5. ~~`~/aws-hackathon` is **not under version control**~~ — **CLOSED as by-design, 2026-09-18.** The
   authoritative git history lives on **day-1**, where the repo is cloned; day-2 receives it by
   `rsync -a --exclude .git`, so the copy on the box is deliberately history-free. That is why
   `git rev-parse` fails there, and it is not a defect to fix. Two live consequences, both now stated in
   `INSTRUCTIONS.md`: **edits made on the box have no undo and no history**, so anything worth keeping
   must be carried *back* to day-1 before the box is torn down; and this is why the working rule here was
   always "move, never `rm`" — though when the author explicitly wants something gone, delete it, because
   a backup that dies with the box is not a safety net.
6. **Exercise 2's seekbar section is written but not yet walked by a participant.** The signal
   behaviour is verified from the CLI, but the *UI* claims — that the seekbar sits at the top of the
   dashboard and that dragging it is the gesture described — come from the author, not from anything
   observed. Confirm against Studio before the session, and check whether the Android speedometer
   visibly follows a drag (the CLI numbers say it should).
7. **One display discrepancy left unresolved.** The author reported Studio showing `hello_world` ECUs
   declared `{}` as *mocks*. The generator disagrees (see *Done*). Not chased down because
   `hello_world` was not running — anything Studio showed came from rendering the instance file, not a
   live topology. If it reproduces, it is worth reporting upstream as a labelling bug.
8. **The Studio links are unclicked.** The URL pattern and the `viewMode` enum are verified, and all
   11 paths exist, but no link was opened in a browser this session — I have no UI. Two specific things
   to check on the first click-through: whether `someip.fibex.xml` is classified as a signal database
   (if so it can carry `viewMode=platform`; the link deliberately omits `viewMode` and lets Studio
   default, which is safe either way), and whether `.ldf` behaves like `.dbc` under
   `viewMode=platform`. Also worth deciding whether links should point at `localhost:57123` at all —
   they only resolve with Studio running and the tunnel up, which §1.3 now says explicitly.
   Third thing to check: whether **As YAML** on a `.dbc` really renders Studio's own YAML rather than
   the raw DBC. §4.2 asserts that distinction in order to send participants to `View Mode → Text`
   instead, and it is reasoned from the bundle, not observed. If the two are the same for databases,
   simplify that paragraph.
9. **Editor links depend on the two checkouts being siblings.** Source files now link with a filesystem
   relative path (`../../remotivelabs-topology-examples/...`) so a click opens them in Kiro rather than
   Studio. That assumes `~/aws-hackathon` and `~/remotivelabs-topology-examples` sit next to each other,
   which `setup-day2.sh` guarantees on this box but nothing enforces elsewhere. A tidier fix would be a
   third symlink (examples repo → `participant/`, alongside the existing `.kiro` and `dashboards`), which
   would let these be repo-relative — author's call. Note also that `INSTRUCTIONS.md` tells participants
   to open **`~/remotivelabs-topology-examples`** as the folder, in which `LAB.md` is not visible at all;
   in practice it gets opened as a standalone file or as a second workspace folder. Relative links
   resolve either way, since Kiro resolves them against the file's own location on disk.
10. **§4.3 is the last link inconsistency.** Its two bullets quote exactly the kind of values that only
    exist in the raw view — subnet, VLAN 123, port 16000, the two host IPs, service 102, method 1002,
    FLOAT32 — but its `someip.platform.yaml` link still opens the graph and the FIBEX link is bare.
    §3.4 and §4.2 were switched to `text` for precisely this reason. Left alone only because the author
    scoped each change explicitly; it should almost certainly follow. (The links were at least given
    `topologySubView=graph` so they no longer land on the tree, whichever way the question is settled.)
11. **The user experience of both parts has been walked; what is untested is a stranger doing it.**
    The author confirms Part 1's steps and Part 2's flow work as written, and the feature was built and
    demoed end to end before being removed. What no one has done is **arrive at** the design from the
    brief with no prior knowledge of it — watch the first real participant for whether the five
    requirements are enough to start from, whether the three hints land, how long it takes, and whether
    Kiro coaches or accidentally dictates. Two things make dictating likelier now that the stored
    reference is gone: an agent recalling the old design from an earlier session's context, and the
    coaching file's option tables being read out verbatim. The stance section is the part most likely to
    need tuning.
12. **`inclusion: auto` on the coaching file — front matter now confirmed recognised, trigger wording
    still unproven.** A later session on the same box *did* list it as an activatable steering item
    ("Go creative coaching", with the description as written), so the front matter shape
    (`inclusion: auto` + `name` + `description`) parses and Kiro registers the file. What is still
    untested is whether the `description` fires on the phrasings a real participant uses — that can
    only be judged by watching one. Low risk either way: **four** always-loaded files point at the path
    explicitly (`hackathon-lab.md` ×2, `product.md`, `remotive-car.md`), so an agent is told to read it
    even if auto-activation never triggers. If the trigger proves unreliable, widen the `description`
    rather than switching to `always` — the context cost of ~245 lines on every turn is the reason it is
    `auto` in the first place.
13. ~~**The 3D car was never watched during a flash.**~~ — **CLOSED by the author, 2026-09-18.** The
    interactive Part 2 path is confirmed working **end to end, Jupyter → 3D car**: driving the charger
    and pedal from a notebook makes the hazard flash visibly at :3000. This was the last
    unobserved link in the chain — the lamps were already proven on the bus and in the notebook
    read-back, but nobody had watched the picture. **Human-verified, not agent-inferred.**
14. ~~**A small instance shows SoC as SNA.**~~ — **CLOSED, absorbed into coaching, 2026-09-19.** An
    instance without PCM never lets the BMS battery simulation initialise its pack, so `StateOfCharge`
    and `BatteryPower` sit at SNA and the 3D car's two battery gauges read nothing. Harmless for a
    hazard feature, and a good talking point about derived-vs-sensed signals. Adding `PCM: {mock: {}}`
    does **not** fix it (a mock transmits SNA start values); a playback PCM or a control command would.
    Now a trap entry in `go-creative-coaching.md` instead of an open item.

15. **`participant/service-account.json` is committed on purpose — keep the repo private.** Confirmed by
    the author, 2026-09-18: the credential is *meant* to travel inside this repo, because that is what
    makes the folder self-contained (`setup-day2.sh` → `remotive-auth` reads the `token` field, exports
    `REMOTIVE_CLOUD_AUTH_TOKEN` into the shell and `~/.ssh/environment`; with no token the broker exits on
    startup and every dependent container fails). So this is **not** a leak to fix, and git-ignoring it
    would break the setup path. Two constraints do follow from the decision, and they are the whole of
    what is left open here:
    - **The repo must stay private.** It is a `service_account` token for
      `ami-demo@sa.aws-ami-demo.remotivecloud.com`. `.gitignore` covers `*.pem`, `*.key`, `*.p12`, `.env`
      — none match this filename, which is correct given the intent, but it also means nothing would stop
      a push to a public remote.
    - **It expires 2027-09-11** (created 2026-09-11). After that every box fails at `setup-day2.sh` with
      an auth error that looks like a broker problem. Worth rotating before then and worth knowing as a
      diagnosis.

    `participant/remotive-auth` was checked at the same time and is safe — a documented wrapper with no
    embedded token.

16. **`participant/start-day2.sh` has never been run against AWS.** Syntax, argument handling, the
    failure messages and the `ssh_config` rewrite are verified locally on macOS/bash 3.2; every AWS and
    SSH path is reasoned from the CLI's documented behaviour, not observed. Worth one real pass before a
    session, watching specifically for: whether `describe-security-groups --filters group-name` needs a
    VPC filter in an account with several VPCs; whether a brand-new instance in a default VPC gets a
    public IP without `--associate-public-ip-address` (the script fails with a clear message if it does
    not, but that is a bad first experience); whether `run-instances` without `--subnet-id` picks a
    usable default subnet; and how long the SSH wait really takes on a cold AMI against the 5-minute cap.
    Also unproven: the `inclusion: auto` trigger on `day1-setup.md` firing for the author's exact phrase
    — mitigated the same way as #12, by an explicit pointer from always-loaded `hackathon-lab.md`.
17. **The day-1 machine has no steering describing itself beyond the new file.** Six of the seven
    steering files are about the car and the box, and they are all loaded in the day-1 workspace too.
    The which-machine-am-I-on table at the top of `hackathon-lab.md` is the only guard. If a day-1
    session still drifts into lab commands, the next lever is a `fileMatch`/front-matter split rather
    than more prose — but that costs a duplicated file, so do not do it speculatively.


## The VHAL gRPC Cuttlefish variant — findings and the open question

`instances/android/cuttlefish_vhal_grpc.instance.yaml` + `cuttlefish_vhal_grpc.compose.yaml` arrived
in the 2026-09-17 pull. It is pedagogically better than the current setup, because the last hop stops
being opaque: IHU gets a **broker plus a Python model**, and the bridge is ~60 readable lines in
`models/ihu/python/ihu/broker_to_cuttlefish.py`:

```
GWM ──SOME/IP──► IHU-broker.com ──► ihu model ──VHAL gRPC :9300──► cuttlefish (Android 15)
                                        │        GNSS proxy :1443 ──► Organic Maps
PERF_VEHICLE_SPEED  = 0x11600207     set_property(0, PERF_VEHICLE_SPEED, speed_mps)
GEAR_SELECTION      = 0x11400400     DBC 1=Drive -> VHAL 8=Drive, 0=Reverse -> 2
HVAC_TEMPERATURE_SET = 0x15600503    Android -> area 1/4 -> SOME/IP HVACService.CompartmentControl
```

Build and run (the `cuttlefish` container replaces `ihu` as the Android one):

```bash
remotive topology build \
  -f remotive_car/instances/android/main.instance.yaml \
  -f remotive_car/instances/android/cuttlefish_vhal_grpc.instance.yaml \
  remotive_car/build

CUTTLEFISH_PROXY_TARGET=https://cuttlefish:8443 docker compose \
  -f remotive_car/build/remotive_car_android/docker-compose.yml \
  -f remotive_car/instances/android/cuttlefish_vhal_grpc.compose.yaml \
  --profile playback --profile 3dcar up -d --build
```

**Verified working** when it was up: the instance merges cleanly with `main.instance.yaml` (one `ihu`
service with the three env vars, plus `IHU-broker.com`); 22 containers; `cuttlefish` healthy in ~60 s
(the compose overlay allows a 10 m `start_period`); `IHU-SOMEIP` namespace appears; SOME/IP flows
`172.31.0.18:16000 → 172.31.0.12:16000`; the broker decodes
`IHU-SOMEIP:SpeedService.Event.SpeedEvent.Speed` (9.42, 10.07, 10.29); the model receives it correctly
(proved with a temporary log line: `parameters={'Speed': 14.56}`); `tcpdump 'tcp port 9300'` shows
86-byte gRPC writes every 200 ms; `SetValues` returns `results {}` with no error, with or without a
`timestamp`.

**The unresolved bit:** `adb shell cmd car_service get-property-value PERF_VEHICLE_SPEED` stays at
`0.0` on that Android 15 image. Crucially, Android's *own*
`cmd car_service inject-vhal-event PERF_VEHICLE_SPEED 30` also leaves it at `0.0` — so that CLI is not
a trustworthy probe on this image, and its `0.0` is **not** evidence the bridge is broken. `GEAR_SELECTION`
reads `GEAR_PARK(0x4)` with a boot-time timestamp, i.e. never updated either. The image runs its own
`vendor.remotivelabs-vhal-bridge` service and `ro.boot.vhal_proxy_server_port = 9300`.

**The one thing needed to unblock:** bring the variant up and *look at the head unit UI* on
`https://localhost:8443` — does the speedometer move with the recording? If yes, adopt the variant and
replace the lab's adb verification with the UI plus `tcpdump 'tcp port 9300'` and the `IHU-SOMEIP`
subscribe. If no, the bridge does not reach the VHAL on this image and the variant stays parked.

**Second wart if adopted:** the Android container is named `cuttlefish`, not `ihu`. That means
`CUTTLEFISH_PROXY_TARGET` must be overridden in the documented start command (otherwise the 3D car's
in-dash Android screen 502s), and every `docker exec ... -ihu-1 ... adb` in exercises 1, 5, 6 and 7
becomes `-cuttlefish-1`, with `ihu` now meaning the bridge model. Container count goes 20 → 22.

## If the environment moves region

Nothing in the lab is region-specific, but bandwidth to the AMI dominated this session. Before a new
box is used: pre-pull `remotivelabs/remotivelabs-cuttlefish:16.0.0_r4-1` (~7 GB, the known-good one)
and, if the gRPC variant is still under evaluation, `15.0.0-4` as well. `provision.sh` and
`build-ami.sh` live in `~/aws-hackathon/organizer/`.

**This is now more than a bandwidth nicety.** The second session's box came up with an entirely empty
Docker image cache, so the 7.2 GB Cuttlefish pull happened on the participant's clock. Whatever
`provision.sh` / `build-ami.sh` are meant to bake in, it did not survive onto this box — worth
checking whether the pre-pull step is actually in the AMI build or only in the runbook. Also note the
`3d-car` image is pinned to a tag (`sha-007fe7f` at `d9319e7`) which moves with the examples repo, so
a pre-pull list hardcoding `3d-car:latest` will fetch the wrong image; read the tag out of
`remotive_car/common/3d_car/3d_car.instance.yaml` at build time.
