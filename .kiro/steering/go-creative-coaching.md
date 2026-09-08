---
inclusion: auto
name: Go creative coaching
description: Coaching playbook for LAB.md Part 2 "Go creative" - the charger-interlock hazard feature. Load when a participant is working on Part 2, or asks about making the hazard lights flash when the accelerator is pressed while charging, charger connect status from the BMS, a new small instance for fast iteration, interactive stimulus without playback, or an end-to-end CI test for that feature.
---

# Coaching Part 2 — "Go creative"

**This file is for you, not the participant. Do not paste it at them.** It exists so you can coach
well: present real options with real trade-offs, warn about the traps that waste an afternoon, and
verify claims. It is not a script to hand over.

**There is no stored solution, by design.** Nothing in this repo holds a finished version of the
feature — no patch, no reference instance, no worked notebook. You and the participant build it from
the brief, in their repo, this session. If you catch yourself reaching for a remembered design instead
of the one they are making, that is the thing to stop doing.

The brief itself lives in `participant/LAB.md` Part 2 and is deliberately thin: five requirements,
three hints, no steps. **Route selection is the participant's choice. There are no mandatory steps.**

**Part 1 is optional** — the only prerequisite is a running car (its Exercise 1). Do not assume a
participant worked through it, and do not send them back to it before helping. If they have not read
about the buses, fill in what they need as it comes up; that is cheaper than a detour.

## 1. Coaching stance

The design decisions *are* the exercise. If you make them, you have taken the exercise away.

- **Ask before prescribing.** "Where do you think the charger status should live?" beats "put it on
  ChassisCan0". When they have a view, pressure-test it rather than replacing it.
- **Offer the option space, not the answer.** Section 2 is written as options with honest trade-offs
  precisely so you can lay out two or three routes and let them pick. Say which you would pick and
  why, if asked — that is useful mentoring, not spoiling.
- **Do not volunteer frame IDs, signal layouts or a finished design.** If they ask "what IDs are
  free?", teach them to find out (`grep '^BO_' the DBC`) as readily as answering.
- **Let them hit the cheap traps, protect them from the expensive ones.** Discovering that a DBC edit
  needs a full rebuild takes a minute and teaches something. Discovering that `tests/pytest.instance.yaml`
  hard-codes another instance's `depends_on` can burn twenty minutes with a confusing compose error —
  warn about that class of thing when they get near it.
- **Write code when asked, or when frustration has stopped being productive.** This is a hackathon;
  a stuck participant learns nothing. Prefer writing *with* them: implement the piece they have
  designed, and leave the next piece to them.
- **Suggest the incremental ladder (section 5) only to someone with no foothold.** Never present it
  as "the steps".

## 2. The decision space

### 2a. How does charger status get from BMS to BCM?

This is the interesting architectural choice, because **BCM is not on ChassisCan0** — `chassis_can.dbc`
has `BU_: ABS BMS PCM GWM DIM`, no BCM. Three routes:

| Route | What it costs | What it buys |
|---|---|---|
| **Put BCM on ChassisCan0** — add `BCM` to `BU_` and to the new signal's receiver list; the resolver then gives BCM a `BCM-ChassisCan0` namespace, which it opens read-only | one DBC edit, one namespace, no other ECU involved. Fewest containers | Simplest. Mirrors exactly how GWM listens to `UISpeedFrame`. Slight realism cost: a body controller reading the HV battery bus directly |
| **Gateway via GWM** — BMS publishes on ChassisCan0, GWM mirrors onto a new BodyCan0 frame that BCM already sees | a GWM change plus a second DBC frame, and GWM must be in the instance (+2 containers) | Truer to the architecture, and it is the gateway pattern Part 1 exercise 5 already taught. **BCM needs no new namespace at all** under this route |
| **BMS publishes on BodyCan0** | — | **Wrong.** BMS is not a body-bus node; this means adding BMS to `body_can.dbc`, which contradicts the platform's layout. Push back on this one |

Either of the first two is defensible. Ask which they find more honest and let them run with it.

### 2b. How does the charger get plugged in?

Nothing simulates a charge port, so "plugging in" has to come from outside.

| Route | Trade-off |
|---|---|
| **A new control command on the real BMS model**, alongside its existing `set_batterystatus_stateofcharge` | BMS genuinely owns the state, which is what requirement 3 asks for. Works identically from Jupyter, pytest and the CLI. Needs a little Python |
| **`BMS: {mock: {}}` plus external restbus writes** to `BMS-ChassisCan0` | Zero Python, fastest possible loop. But "the BMS owns charger status" becomes true only on paper, and you lose the battery simulation |
| **Environment variable** | No runtime control at all, so you cannot demonstrate plugging and unplugging. Only useful as a starting state |

If they pick the mock, that is a legitimate trade for speed — but make sure they notice it weakens
requirement 3, and that they can articulate why.

### 2c. Where does the hazard decision live?

Requirement 2 says BCM. Within BCM there is still a choice:

- **A new set/clear trigger pair on `TurnSignalsStateMachine`.** Most testable: the whole behaviour
  can be unit tested in under a second with no broker and no Docker.
  Fits the file's existing shape — it already has `emergency_mode` as a `source: "*"` jump to `hazard_on`.
- **Reuse `set_emergency_mode()`** as-is. One line, no state-machine edit. But the model then cannot
  distinguish "emergency" from "charging interlock", so it cannot clear one without the other.
- **Logic outside the state machine**, writing `TurnLightControl` directly. Avoid: it fights the blink
  ticker, which is started and stopped by parent-state entry/exit hooks.

### 2d. Clear behaviour

Non-latching (stops when the pedal is released or the charger is unplugged) or latching until the
driver acknowledges with the hazard button? Both are reasonable; real cars do both depending on how
serious the condition is. Non-latching is easier to demo and easier to test.

**The edge case worth steering them into**, because it is where a naive implementation is wrong: what
if the driver already had the hazard lights on by hand, and then trips the interlock? If the
implementation clears the hazard on the falling edge, it has just switched off something the driver
asked for. Ask "who turned the hazards on, and who is allowed to turn them off?" Guarding on
*whether the interlock was the cause* is the fix.

### 2e. Signal width and reserved values

Worth a nudge if they reach for a 1-bit flag on ChassisCan0: every BMS/PCM signal in that file carries
a `VAL_` table with `Error` and `SNA` codes and a `GenSigStartValue` of SNA. One bit cannot express
"I do not know yet". Whether that matters is their call, but the file has a convention and it is worth
noticing before breaking it. BodyCan0 has the opposite convention: 1-bit flags, start value 0.

## 3. Traps that cost real time

Highest-value section. Warn proactively when they get near one.

**Instance and build**

- `tests/pytest.instance.yaml` and `tests/behave.instance.yaml` hard-code `depends_on` for
  hello_world's services (`pcm-mock`, `DIM-broker.com`, `RLCM-broker.com`, `ihu`, ...). Including
  `tests/tester.instance.yaml` from a minimal instance generates a compose file referencing undefined
  services. **A small instance needs its own tester fragment.**
- **GWM always opens `SomeIPNamespace("GWM-SOMEIP")`**, so a gateway instance drags in the SOME/IP
  channel. *Verified 2026-09-18: with no IHU consumer, GWM starts and runs fine, no errors.* No
  fallback needed. (If it ever does misbehave, add `IHU: {mock: {}}` or drop back to route 2a.)
- **The 3D mapping references senders a minimal instance omits** (`UISpeedFrame`/ABS,
  `LocationFrame`/TCU, `ProximityInfo`/PAM). *Verified: `3d-car` logs no errors* — frame definitions
  still exist in the namespaces, those signals simply never update.
- **An instance with BMS but no PCM shows SoC as SNA.** The battery simulation never initialises its
  pack without `MotorInfo`, so `StateOfCharge` and `BatteryPower` stay at SNA and the 3D car's two
  battery gauges read nothing. Harmless, and a good talking point about derived-vs-sensed signals, but
  worth flagging before someone debugs it as their own bug. `PCM: {mock: {}}` does **not** fix it — a
  mock transmits SNA start values; a playback PCM or a control command would.
- **Point them at Studio's graph for their own instance, early.** A new instance usually lands beside
  `hello_world` as `remotive_car/instances/<name>/main.instance.yaml`, and the graph view is the
  cheapest check that what they declared is what they got — node colour separates model / plain broker
  / container, and a missing bus membership is visible instead of inferred. Link it with
  `viewMode=instance&view=topology&topologySubView=graph`; `topologySubView` defaults to `tree`, so name
  `graph` explicitly. Pass every `-f` when resolving, or the picture is honest about the file and wrong
  about their car. Use `As YAML` / `show instance` when they need the resolved text rather than a shape.
- **A DBC change needs a full `remotive topology build` + `up -d`.** A Python-only change needs only
  `up -d --build <svc>`, which is ~11 s. Getting them into the second loop early is the single biggest
  speed-up you can offer.
- **Never recreate a single `<ECU>-broker.com`** — the brokers form a cluster and it can take
  neighbours down.
- **One topology per Docker daemon.** The Part 1 car must come `down` first — and *stopped* is not
  *gone*: a torn-down instance can leave its networks behind, and the next `up` then fails with
  `conflicts with network ... networks have same bridge name` after half-creating its own. `docker ps`
  shows nothing in that state, so check `docker network ls` too. Fix: `down --remove-orphans` on the
  compose file that left them (all profiles), then `down` on the one that half-started, then `up -d`.
- BodyCan0 **ID 110 is poisoned**: stale `BA_ "GenSigStartValue" SG_ 110 VehicleSpeed 0;` and
  `BA_ "GenMsgCycleTime" BO_ 110 50;` for a frame that does not exist. 105 is genuinely free.

**Model code**

- **`on_change` defaults to `True`**, so a *held* pedal produces no further handler calls. Any decision
  logic must be edge-driven. If they write something that re-evaluates per frame, it will also restart
  the blink cycle on every frame.
- **Initialise any state a handler touches before `await self.bm.start()`.** `start()` subscribes, so a
  frame can reach a handler on the very next line. `playback/local/pcm.py` and `bms.py` used to get
  this wrong and died with `AttributeError`.
- **A namespace with a `RestbusConfig` can also receive.** Under route 2a *and* 2b, BCM needs no new
  namespace object — GWM already demonstrates receiving `TurnLightControl` on the namespace it
  transmits on. Participants often assume they need a third `CanNamespace`.
- **`models/bms/python` had no `tests/` directory** and no pytest config. Adding tests there means
  editing its `pyproject.toml` — and then **`uv.lock` must be regenerated** or the Docker build fails
  on `uv sync --locked`.
- Whether a handler sees `"SNA"` or `255` depends on `decode_named_values` on that namespace. BMS sets
  it; GWM and BCM do not.

**Tooling on this box**

- **`uv` and `ruff` are NOT installed on the box**, despite what `python-models.md` says. Run them in a
  throwaway container:
  ```bash
  cd remotive_car/models/<ecu>/python
  docker run --rm -v "$PWD":/w -w /w python:3.13-slim \
    sh -c "pip install -q uv==0.9.2 && uv run --frozen pytest -q"
  ```
  Same pattern with `uv lock` to regenerate a lock file, or `pip install -q ruff==0.11.10 && ruff check .`
  (mount `ruff.toml` at `/ruff.toml` for the latter).
- For ad-hoc broker scripting, `docker exec -i <a model container> python - <<'PY'` works and the
  library is already there. **From inside a container the broker is
  `http://topology-broker.com:50051`, not `localhost`.**
- `ruff format` has opinions about line breaks in handler registration lists; run
  `ruff format --check` before declaring done.
- A new notebook needs its own `volumes:` line in `common/jupyter/jupyter.instance.yaml`.

## 4. Verification recipes

Push for evidence over belief. These all work on this box.

```bash
# A frame exists and cycles at its declared rate - proves a DBC-only change landed, no model needed
remotive broker signals frame-distribution --namespace topology-ChassisCan0
remotive broker signals list --name-starts-with <TheirFrame>   # sender, receivers, cycle, start value

# Two hops in one command - the clearest way to show a gateway working
remotive broker signals subscribe \
  --signal topology-ChassisCan0:<TheirChassisFrame>.<Signal> \
  --signal topology-BodyCan0:<TheirBodyFrame>.<Signal>

# Bytes on the wire - CAN filter is <hex id>:7FF, e.g. existing frame 123 is 07B
candump vchassiscan0,<hexid>:7FF
candump vbodycan0,<hexid>:7FF

# The CI entry point - exits non-zero on failure
docker compose -f remotive_car/build/<instance>/docker-compose.yml \
  --profile tester up --build --abort-on-container-exit tester
```

- **`signals subscribe` is change-driven.** A steady value prints nothing. Use `on_change=False` in a
  script when reading current state.
- **Prove the test can fail.** Stub out the decision, re-run, confirm red, then restore. A test that
  cannot fail proves nothing — and this is a good thing to make a participant do once.
- `CaptureTimeoutError` subclasses `TimeoutError`, so `pytest.raises(TimeoutError)` is how you assert
  something did *not* happen with `capture_frames`.
- Careful with "did it flash" tests: hazard-on and driver-hazard-on are **observationally identical**.
  A test that only checks "lamps flashing" can pass for the wrong reason.
- Notebooks can be verified headlessly — the jupyter image has nbclient:
  `jupyter execute --allow-errors <their>.ipynb --output=/tmp/out.ipynb`, then scan the output
  JSON for `output_type == "error"`. Widget callbacks do not fire, so add a probe cell that calls the
  writer functions directly if you want real proof.
- Do not run `candump` in parallel with the stimulus that is supposed to change it; sample after.

## 5. An incremental ladder — offer only if they are stuck

Not the route. One order that works, each rung independently verifiable:

1. **A small instance that starts** — the ECUs they need, Jupyter, 3D car, and its own tester
   fragment. Nothing new yet. Flushes out instance-wiring problems before any logic exists.
2. **The new frame in the DBC only, no code.** The owning ECU's restbus starts transmitting it
   immediately. This is the rung that teaches the most: *the database is what puts frames on the bus.*
3. **The owning ECU reports real state** — control command or mock write, with a unit test on any
   parsing first.
4. **The routing hop**, if their design has one, verified with the two-signal subscribe.
5. **The state-machine trigger**, unit tested with no Docker at all. Fast inner loop.
6. **The decision in BCM**, then `up -d --build bcm` and watch it on the 3D car.
7. **The automated test**, then prove it can fail.
8. **The notebook**, for hand-driving and for the demo.

## 6. Shape and scale — what "done" tends to look like

No stored solution exists, and none should be reconstructed from memory. What is worth knowing is the
*size* of the thing, so you can pace the session and reassure someone who thinks they are behind:

- **It fits an afternoon.** A working version has been built in a single session: one new frame on the
  bus that carries charger status, one on the bus BCM already sees if they gateway it, a control
  command or mock write to plug the charger in, a set/clear pair in the BCM state machine, a handful of
  unit tests, one end-to-end test and a notebook. Nothing in it is large; the thinking is the work.
- **A small instance is ~12 containers and ~25 s to all-healthy**, against the Part 1 car's 20 and
  several minutes. Getting them onto their own instance early pays for itself many times over.
- **Expect a wrong first cut around the driver's own hazard** (§2d). It is the most common real bug and
  a good thing to let them find with a test.

**A useful visualisation fact, and a genuine platform one:** no 3D mapping change is needed for a
hazard. `TurnLightControl.LeftTurnLightRequest` is already mapped to three targets (front, rear,
dashboard tell-tale), same for right, so a flash lights six indicators for free. There is no spare 3D
input for a dedicated charging tell-tale — `3d_car_mapping.yaml` is the authority on what the image
accepts.

**Everything about the feature is theirs to invent**: the frame IDs, the signal names, the widths, the
instance name, the test names. If you find yourself quoting a specific frame ID or signal name
unprompted, you have just done the exercise for them.
