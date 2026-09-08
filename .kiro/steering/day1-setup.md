---
inclusion: auto
name: Day-1 setup of the day-2 box
description: How to set up the hackathon day-2 box from the day-1 machine. Load when the user says they are on the day-1 machine, asks to set up or start day 2, launch or start the AMI or EC2 instance, copy the aws-hackathon folder to the box, install the auth or service-account token, fix the SSH config or tunnels, or connect Kiro Remote-SSH to the box.
---

# Setting up day-2 from day-1

**You are the day-1 agent.** The workspace is `aws-hackathon` — the participant's own clone on their
own machine. There is no car here: no Docker topology, no brokers, no SocketCAN devices, no
`remotive_car/`. Everything in `hackathon-lab.md` describes the **other** machine.

**The trigger.** The root `README.md` tells the participant to say, verbatim:

> **I'm on the day1 one machine setup day2.**

Take that, and any variation of it ("set up day 2", "start the box", "launch the AMI"), as the
instruction to run exactly one thing:

```bash
./participant/start-day2.sh
```

Run it from the workspace root, in the foreground, and let it finish. It is chatty on purpose: seven
numbered steps, `[ok]` / `[warn]` / `[FAIL]` lines, and a closing handover block. Pass its output
through to the user rather than summarising it away — the `[warn]` lines are the ones they need.

It is idempotent. Re-running it is the normal way to re-copy the folder after an edit on day-1
(`--skip-aws` skips the AWS calls if the box is already up).

## The hard rule: day-1 runs nothing from the lab

`start-day2.sh` stops once the box is reachable, set up and verified. That boundary is deliberate,
so do not cross it:

- **Do not** run `remotive topology build`, `docker compose up`, `candump`, `remotive broker ...`,
  `remotive studio` or any exercise from `LAB.md` — not locally, and **not over SSH from here**
  either. A car started over a one-shot SSH command has no terminal to live in and no logs the
  participant can see.
- **Do not** start Part 1 or Part 2 in this session. The day-1 machine has no topology to inspect and
  this session has none of the runtime context.
- **Do not** offer to "just have a look at the car" from here.

When the script finishes, hand over: the participant connects **Kiro on day-2** with Remote-SSH and
prompts *that* Kiro. Its workspace is `~/remotivelabs-topology-examples`, whose `.kiro` symlink
gives it the day-2 steering. State the handover in these four steps (the script prints them too):

1. `ssh remotive-hackathon` in a terminal, and leave it open — that session carries every port
   forward (Studio 57123, broker 50051, Android 8443, 3D car 3000, adb 6520, Jupyter 8888).
2. `Cmd+Shift+P` → **Open Remote-SSH: Connect to Host** → `remotive-hackathon`. First time on a
   machine: install the **"Open Remote - SSH"** extension (not the Microsoft one) and reload.
3. In the new window, open the folder `~/remotivelabs-topology-examples`.
4. Open the lab, `~/aws-hackathon/participant/LAB.md` — it is *outside* the opened folder, so
   `File → Open File…`, or add `~/aws-hackathon` as a second workspace folder. Then ask that Kiro to
   start the car; *"start the car and show me what is running"* is a good first message.

These three steps are also printed at the top of the root `README.md`, which is where the participant
is told to say the trigger phrase. Keep the two in step.

If the user asks a lab or platform question **while still on day-1**, answer it from the files here
(the steering and `participant/LAB.md` are the same content the day-2 agent reads) and say plainly
that running it needs the day-2 session.

## Ambiguities the script has already settled

Do not re-litigate these in chat, and do not invent your own AWS commands — say what the script did.

| Question | Settled as |
|---|---|
| "start the AMI" — launch a new box, or start an existing one? | Whatever is cheapest and least destructive: an instance tagged `Name=remotive-hackathon` that is **running** is reused as-is; a **stopped** one is started (its disk, and any work on it, survives); only if there is none does it launch a new one from the AMI. Two or more matches is an error, not a guess — it asks for `--instance-id`. |
| Which AMI? | Picked from the region: `us-east-1` → `ami-01427a11059a0b23d`, `eu-central-1` → `ami-0ad3d7ef0066987e6`. Any other region is an error with the two valid ones named, not a silent fallback. |
| Nested virtualization | Added automatically on `c8i`/`m8i`/`r8i` (needed for `/dev/kvm`, i.e. Android). Any other type gets a warning, not a failure — Part 2 does not need Android. |
| Where does the folder land? | `~/aws-hackathon` on the box, via `rsync -a --exclude .git`. The path matters: `setup-day2.sh` derives its symlinks from its own location. |
| Where does auth come from? | `participant/setup-day2.sh`, run on the box, which sources `remotive-auth` → `participant/service-account.json` → `REMOTIVE_CLOUD_AUTH_TOKEN` in `~/.ssh/environment`. Never `remotive cloud auth login`. |
| How is it proven? | Step 7 opens a **fresh non-interactive** SSH session and checks the token there, because that is how Remote-SSH and Kiro run commands. A token that only exists in an interactive shell is the failure mode this catches. |
| Does the lab get started? | No. See the hard rule above. |

## Things worth saying out loud, unprompted

- **The box costs money while it runs.** `c8i.4xlarge` is not cheap. Tell the participant how to stop
  it (`aws ec2 stop-instances ...`, keeps the disk) versus terminate it (gone). The script prints
  both with the instance id filled in.
- **The box is disposable and has no git history** for `aws-hackathon` (that is why `.git` is
  excluded). Anything built on day-2 has to come **back** to day-1 before teardown —
  `git diff > ~/aws-hackathon/my-feature.patch` in the examples repo, plus a check of `git status`
  for new files.
- **The tunnel session is load-bearing.** Nothing is exposed on day-2 except port 22, so every
  `localhost` URL on day-1 dies when that `ssh remotive-hackathon` session closes.

## When something fails

| Symptom | Cause / next move |
|---|---|
| `AWS credentials are not working` | `aws configure`, or set `AWS_PROFILE`. The script does not manage credentials. |
| `private key not found` / `key pair does not exist` | A key pair is bound to the instance **at launch** and is never added retroactively. Create it first, then launch with the same `--key-name`. If someone else launched the box, use *their* key with `--key-file`. |
| `cannot SSH ... after 5 minutes` | In order: security-group ingress for the current day-1 IP (the script adds it, unless `--no-sg`), wrong key pair, or a changed host key after a relaunch (`ssh-keygen -R <ip>`). |
| `more than one instance tagged` | One box per participant. Pick with `--instance-id` or terminate the extra — and ask before terminating anything. |
| `[FAIL] cloud token` in step 7 | `participant/service-account.json` missing, or its token expired (this one expires 2027-09-11). Everything downstream fails at `docker compose up` with the broker exiting. |
| `[warn] /dev/kvm missing` | Launched without nested virtualization, or not on c8i/m8i/r8i. Android will not boot; Part 2 is unaffected. Relaunching is the only fix — it is a launch-time CPU option. |
| Host does not appear in Kiro's Remote-SSH list | `~/.ssh/config` needs `Include <abs path>/participant/ssh_config` at the top. The script adds it unless `--no-ssh-include`; reload the Kiro window afterwards. |

Ask before anything destructive: terminating an instance, deleting a key pair, or revoking security
group rules. Launching, starting and copying are what the trigger phrase authorises; tearing down is
not.
