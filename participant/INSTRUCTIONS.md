# RemotiveTopology hackathon — participant instructions

You work from a **day-1 machine** (your laptop, or the provided NICE DCV workstation) and
run the virtual car on a **day-2 machine** (the prebuilt RemotiveCar AMI). The day-2 box's
security group allows **nothing but SSH**, so every service is reached by **SSH
port-forwarding** and shows up on `localhost` on day-1. That is also what makes
RemotiveStudio, its video, and maps work with no extra setup — `localhost` is a browser
secure context and is already in Studio's allow-list.

```
 day-1 (you: browser, Kiro/VS Code, Studio --desktop)
   │  ssh -L 57123/50051/8443/3000/...  (only port 22 is open inbound)
   ▼
 day-2 (RemotiveCar AMI: Docker topology, brokers, Android, Studio)
```

## The day-2 AMI

| | |
|---|---|
| AMI ID | **us-east-1:** `ami-01427a11059a0b23d` / **eu-central-1:** `ami-0ad3d7ef0066987e6` (remotive-topology-hackathon-day2-20260919-clean, x86_64) |
| Preinstalled | Docker + Compose, RemotiveCLI 0.34.1 (+ Studio), RemotiveBus, Wireshark, git-lfs, examples repo, map APK |
| Auth | service account — **no interactive login** (see step 3) |
| Docker images | **not** pre-pulled — the first `docker compose up` pulls ~7 GB (Cuttlefish), so allow extra time on a first start |
| Previous AMIs | ~~ami-08de37a4b7b92ca19 (us-east-1)~~, ~~ami-0ab06933113f68dc2 (eu-central-1)~~ — do not use, their examples checkout is polluted with a Part 2 solution |

## Prerequisites (on day-1)

- AWS CLI configured, and an EC2 **key pair** saved at `~/.ssh/my-key.pem`:
  ```bash
  aws ec2 create-key-pair --region us-east-1 --key-name my-key \
    --query KeyMaterial --output text > ~/.ssh/my-key.pem && chmod 600 ~/.ssh/my-key.pem
  ```
  > If `create-key-pair` says the key already exists, either pick a new `--key-name` (and
  > use it in step 2), or delete the old one first: `aws ec2 delete-key-pair --key-name my-key`.
  > The key pair is bound to the instance **at launch** via `--key-name` (step 2). Use the
  > **same** key name there that you created here — that is what makes it accepted for SSH.
  > A key pair created *after* an instance is running is **not** retroactively added to it
  > (opening port 22 does not help). If you must use a new key on an existing box, either
  > relaunch the box with `--key-name <new-key>`, or (advanced) add the new public key to
  > `~/.ssh/authorized_keys` on the box from a session that already has access.
  > If someone handed you a box launched with a different key, use **that** key's `.pem`
  > and point `IdentityFile` in `participant/ssh_config` at it.
- This `aws-hackathon` repo **cloned on day-1** — your own machine is where the git history lives. It
  carries these instructions, the SSH config, the service-account token, the lab and the Kiro context,
  so it travels as a unit. You copy the whole folder to the box in step 4; day-2 gets the files without
  the history.

> ⚠️ **Nested virtualization is required** for Android/Cuttlefish (`/dev/kvm`). It is a
> launch-time CPU option the console wizard does not expose, so launch via the **CLI** on
> an 8th-gen Intel type (**c8i / m8i / r8i**).

## Quick start — one command on day-1

Steps 1–4 are scripted. From the root of this repo, **on day-1**:

```bash
./participant/start-day2.sh
```

Or open this repo in Kiro on day-1 and say: **"I'm on the day-1 machine, set up day-2."**

It prints seven numbered steps with `[ok]` / `[warn]` / `[FAIL]` lines, and it does what the manual
steps below do:

1. checks this machine — AWS CLI, credentials, `rsync`, your `.pem`;
2. reuses or creates the `remotive-hackathon` security group and allows **SSH from your current IP**;
3. **reuses a running box, starts a stopped one, or launches a new one** from the AMI with nested
   virtualization enabled — it never launches a second box behind your back;
4. writes the box's IP into `participant/ssh_config` and adds the one `Include` line to
   `~/.ssh/config`, which is also what makes `remotive-hackathon` appear in Kiro's Remote-SSH list;
5. `rsync`s this whole folder to `~/aws-hackathon` on the box;
6. runs `participant/setup-day2.sh` there (service-account token + Kiro context) and refreshes the
   examples repo;
7. verifies the token from a **fresh non-interactive SSH session** — the way Kiro runs commands —
   plus `/dev/kvm`.

**It stops there, on purpose. Nothing from the lab is ever run from day-1**: no
`remotive topology build`, no `docker compose up`, no Studio. The car is built and started on day-2,
from the Kiro window connected to the box, so that every command lands where the containers, the
buses and the logs are.

It defaults to **us-east-1**; for Frankfurt use `--region eu-central-1` (it picks that region's AMI).
Re-run it whenever you edit this folder on day-1 and want the box to catch up; add `--skip-aws` to
leave AWS alone. `--help` lists the rest (instance type, key name, instance id, and switches to skip
the security group, the `~/.ssh/config` edit or the repo refresh).

When it finishes, go to **[step 7](#7-start-the-lab)** — connect Kiro and start the lab. **Steps 1–4
below are the manual equivalent** of the script: read them to see what it did, or to take over if it
failed. Steps 5 and 6 are day-2 material either way.

## 1. Security group — SSH only

> Done by `start-day2.sh` step 2, including re-adding the rule when your IP has changed.

The day-2 box only needs inbound **SSH (22)** from day-1. Nothing else is exposed.

```bash
DAY1_IP=$(curl -s https://checkip.amazonaws.com)   # or the day-1 machine's IP/SG

SG=$(aws ec2 create-security-group --region us-east-1 \
  --group-name remotive-hackathon --description "RemotiveTopology hackathon (SSH only)" \
  --query GroupId --output text)

aws ec2 authorize-security-group-ingress --region us-east-1 \
  --group-id "$SG" --protocol tcp --port 22 --cidr "${DAY1_IP}/32"
echo "Security group: $SG"
```

## 2. Launch the day-2 instance (nested virtualization ON)

> Done by `start-day2.sh` step 3 — which first looks for an instance tagged
> `Name=remotive-hackathon` and reuses it (starting it again if it was stopped) rather than launching
> a second one.

```bash
# For us-east-1:
aws ec2 run-instances --region us-east-1 \
  --image-id ami-01427a11059a0b23d \
  --instance-type c8i.4xlarge \
  --cpu-options NestedVirtualization=enabled \
  --key-name my-key \
  --security-group-ids "$SG" \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":100,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=remotive-hackathon}]' \
  --query 'Instances[0].InstanceId' --output text

# For eu-central-1:
aws ec2 run-instances --region eu-central-1 \
  --image-id ami-0ad3d7ef0066987e6 \
  --instance-type c8i.4xlarge \
  --cpu-options NestedVirtualization=enabled \
  --key-name my-key \
  --security-group-ids "$SG" \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":100,"VolumeType":"gp3","DeleteOnTermination":true}}]' \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=remotive-hackathon}]' \
  --query 'Instances[0].InstanceId' --output text
```

Get its IP once running:

```bash
aws ec2 describe-instances --region us-east-1 \
  --filters "Name=tag:Name,Values=remotive-hackathon" "Name=instance-state-name,Values=running" \
  --query 'Reservations[].Instances[].PublicIpAddress' --output text
```

## 3. Connect from day-1 (SSH config with all tunnels)

> `start-day2.sh` step 4 does sub-steps 1 and 2 for you (the `HostName` and the `Include` line).
> Sub-step 3, the Kiro extension, is a one-time manual thing on your own machine.

Use the ready-made **`participant/ssh_config`** in this repo — it defines host
`remotive-hackathon` and forwards every service to `localhost` on day-1.

1. In `participant/ssh_config`, set `HostName` to the day-2 IP from step 2.
2. Add one line at the top of your `~/.ssh/config`:
   ```
   Include /ABSOLUTE/PATH/TO/aws-hackaton/participant/ssh_config
   ```
3. **For Kiro IDE users:** Install the **"Open Remote - SSH"** extension from the Extensions marketplace (`Cmd+Shift+X` or `Ctrl+Shift+X`). This is the Kiro-compatible Remote-SSH extension (not the Microsoft one).
4. Connect (any of these — all get the tunnels):
   - **Terminal:** `ssh remotive-hackathon`
   - **Kiro IDE:** Press `Cmd+Shift+P` (macOS) or `Ctrl+Shift+P` (Windows/Linux) → "Open Remote-SSH: Connect to Host" → select `remotive-hackathon`
   - **VS Code:** Remote-SSH → `remotive-hackathon`

## 4. Copy this folder to day-2 and run the setup script

> Done by `start-day2.sh` steps 5–7: the `rsync`, the sourced setup script, and a verification that
> the token is present in a *fresh* SSH session. Run it again after editing this folder on day-1.

One copy, one command. Everything the box needs — the service-account token, the lab, and the
Kiro context — lives in this folder, so it travels as a unit.

```bash
# from day-1 (one time), from the directory that contains aws-hackathon/:
rsync -a --exclude .git -e "ssh -i ~/.ssh/my-key.pem" aws-hackathon ubuntu@<DAY2_IP>:~/
```

It must land at `~/aws-hackathon` — `setup-day2.sh` builds its symlinks from its own location, and the
rest of the docs assume that path. `--exclude .git` is deliberate: the git history stays on day-1, where
you cloned it, so day-2 carries the files only. Anything you want to keep from a session therefore has
to come **back** to day-1 before the box goes away.

Then, in your day-2 SSH session, source the setup script once:

```bash
source ~/aws-hackathon/participant/setup-day2.sh
```

It prints a self-check; all lines should say `[ok]`. What it does:

1. **Authentication** — activates the committed service account
   (`participant/service-account.json`); you do **not** run `remotive cloud auth login`.
2. **Kiro context** — symlinks `~/remotivelabs-topology-examples/.kiro` to
   `~/aws-hackathon/.kiro`. That symlink is what gives Kiro the hackathon steering, so it knows this
   car, these buses and this instance, while leaving the examples checkout itself untouched.
3. **Somewhere for your artifacts** — symlinks `dashboards` in the examples repo to
   `~/aws-hackathon/participant/dashboards`. RemotiveStudio can only save a dashboard inside its
   workspace, and the workspace needs to be the examples repo; saving into `dashboards/` keeps
   your work with this folder instead.
4. Adds those entries to the examples repo's local `.git/info/exclude`, so `git status` stays
   quiet.

Re-running it is harmless — do that after any reconnect where something looks off.

Verify auth by hand if you like:

```bash
remotive cloud auth whoami      # prints the service account, no login prompt
```

Step 1 sets `REMOTIVE_CLOUD_AUTH_TOKEN` + `REMOTIVE_CLOUD_ORGANIZATION` in three places, so
it keeps working after you disconnect and reconnect, and for commands run **non-interactively
over SSH** (which is how Remote-SSH tools such as Kiro IDE or VS Code execute commands):

- **This shell**, immediately.
- **`~/.ssh/environment`** — the AMI enables `PermitUserEnvironment`, so sshd injects this
  into *every* SSH session it creates, interactive or not. No sudo needed (it's your own file).
- **`/etc/environment`**, best-effort, if passwordless sudo is available — covers a NICE
  DCV desktop terminal or any other non-SSH session on this box.

> The token is needed both for `remotive topology build` **and** for `docker compose up`
> (the RemotiveBroker verifies the subscription at container start). Because it is now in
> every SSH session's environment (including future connections and Remote-SSH commands),
> the documented steps below just work — you do not need to keep this shell open.

## 5. Build and run (on day-2)

> **These commands run on the box, in a day-2 terminal — never from day-1.** `start-day2.sh`
> deliberately stops before them.
>
> Prefer to let Kiro do this? Skip to step 7 and start the lab from the Kiro window **connected to
> day-2** — its first exercise is exactly this. The commands below are here for when you want to run
> it yourself.

With the token loaded (step 4 — automatic in every shell once the setup script has run):

```bash
cd ~/remotivelabs-topology-examples

remotive topology workspace init      # one-time (answer 'y' to the analytics prompt)

remotive topology build \
  -f remotive_car/instances/android/main.instance.yaml \
  -f remotive_car/instances/android/cuttlefish.instance.yaml \
  remotive_car/build

docker compose \
  -f remotive_car/build/remotive_car_android/docker-compose.yml \
  -f remotive_car/instances/android/cuttlefish.compose.yaml \
  --profile playback --profile 3dcar up --build
```

> `docker compose` passes `REMOTIVE_CLOUD_AUTH_TOKEN` to the RemotiveBroker, which verifies
> the subscription on startup — without it the broker exits and other containers fail with
> "dependency ... failed to start". Because `~/.bashrc` auto-loads the token in every
> shell, this is already satisfied. (If you ever see that error, run `echo
> $REMOTIVE_CLOUD_AUTH_TOKEN` — empty means the setup script hasn't run in this session; redo
> step 4.)

Start RemotiveStudio, pointing it at the examples repo as its workspace so the file browser has
the platform and instance files (it finds the running broker by itself). **Keep this in a separate
terminal** — the `docker compose up` command above holds its terminal and runs in the foreground:

```bash
remotive studio ~/remotivelabs-topology-examples --no-browser   # first run asks for analytics consent — answer 'y'
```

> **Important:** `docker compose up` without `-d` runs in the **foreground and holds that
> terminal**. `Ctrl+C` there stops the entire car (all containers exit with code 143). Keep the
> topology running in its own terminal and run everything else (`candump`, the CLI, Studio) in
> other terminals. If containers suddenly all died at once, check `docker ps -a` for
> `Exited (143)` — someone hit `Ctrl+C` in the compose terminal.

## 6. Access the services — all on localhost (day-1)

Because the SSH config forwards these ports, open them on **day-1**:

| Service | URL on day-1 |
|---|---|
| RemotiveStudio | `http://localhost:57123` |
| Android head unit (Cuttlefish) | `https://localhost:8443` (accept the self-signed cert) |
| 3D car | `http://localhost:3000` |
| Topology broker / API | `localhost:50051` |
| adb | `adb connect localhost:6520` |
| Jupyter (if an example exposes it) | `http://localhost:8888/lab?token=remotivelabs` |

## 7. Start the lab

**Connect to day-2 with Kiro IDE:**
1. Press `Cmd+Shift+P` (macOS) or `Ctrl+Shift+P` (Windows/Linux)
2. Type "Open Remote-SSH: Connect to Host"
3. Select `remotive-hackathon`
4. A new Kiro window opens connected to the day-2 box
5. In that window, open the folder: `~/remotivelabs-topology-examples`

Keep the `ssh remotive-hackathon` terminal session open alongside it — that is what forwards Studio,
the broker, the 3D car, Android and adb to `localhost` on day-1.

**From here on, work in the day-2 window.** The Kiro on day-1 only exists to run
`start-day2.sh`; it has no car to look at, no containers and no logs.

Then open **[`participant/LAB.md`](LAB.md)**. It has two halves:

- **Part 1 — Understand the platform.** Seven exercises: start the car, watch it, take it apart, change
  it, break it. **Optional, and a menu rather than a checklist** — take the ones that look interesting.
  The one worth doing is **Exercise 1, which starts the car**, because Part 2 needs it running.
- **Part 2 — Go creative.** An open brief: a feature to build, with every design decision yours and no
  steps to follow. This is where the session is going, so leave it the time it deserves.

Both halves are driven by asking Kiro rather than by copying commands. Kiro already has the context for
this box (that is what the `.kiro` symlink from step 4 is for), so you can open the lab and start
prompting — "start the car and show me what is running" is a fine first message.

If something misbehaves, **[`participant/TROUBLESHOOTING.md`](TROUBLESHOOTING.md)** has the symptom
tables.

## RemotiveStudio desktop app (`--desktop`, on day-1) — optional

Instead of the browser, you can run the Studio **desktop app on day-1**. Same Studio, plus one
thing the browser cannot do: **capture a channel straight into Wireshark**, decoded by frame name
and sender. This is optional; nothing in the lab depends on it.

- **Requires the RemotiveCLI on day-1** and a supported desktop platform (macOS,
  Windows, or x86_64 Linux). Install the CLI on day-1 with:
  ```bash
  curl -fsSL https://files.remotivelabs.com/remotivelabs-cli/install.sh | bash
  ```
- Make sure the tunnel is up (`ssh remotive-hackathon`), then on day-1:
  ```bash
  source participant/remotive-auth      # same service-account token
  remotive studio --desktop             # downloads the desktop app on first run, then launches it
  ```
  `--desktop-version <x.y.z>` pins a specific build. The app talks to the topology on
  `localhost:50051` over the tunnel.
- Wireshark must be installed on day-1. Nothing to switch on in Studio: the integration is enabled
  by default.
- With the workspace open, a channel's `...` menu offers **Capture channel in Wireshark**,
  **Open in Signal View** and **Live channel preview**. Wireshark runs locally on day-1 with a
  generated RemotiveLabs profile, so CAN frames appear as `TurnLightControl` / `GearInfo` with
  `BCM`, `TCU` as senders rather than raw IDs.

If you use the browser instead, everything in the lab still works — the tunnel forwards Studio on
`localhost:57123`.

## Update the day-2 tooling / examples repo

The AMI ships `remotive-hackathon-update`:

```bash
remotive-hackathon-update            # examples repo (git pull + lfs) + RemotiveCLI
remotive-hackathon-update --all      # also RemotiveBus + Docker images
```

Uncommitted work in the examples repo is stashed and re-applied around the pull. After an
update, rerun the build + `docker compose up --build`.

## Stop / clean up (avoid charges)

```bash
docker compose -f remotive_car/build/remotive_car_android/docker-compose.yml \
  -f remotive_car/instances/android/cuttlefish.compose.yaml \
  --profile playback --profile 3dcar down

aws ec2 terminate-instances --region us-east-1 --instance-ids <INSTANCE_ID>
```

## Troubleshooting

- **`start-day2.sh` can't SSH after 5 minutes:** in order — the security group must allow TCP 22
  from your *current* IP (re-run the script, it re-adds the rule), the box must have been launched
  with the key pair you are using (`--key-name` at launch, never retroactive), or the host key
  changed after a relaunch (`ssh-keygen -R <ip>`).
- **`start-day2.sh` says "more than one instance tagged":** one box per participant. Pass
  `--instance-id <id>` to pick one, or terminate the extra.
- **`remotive-hackathon` is missing from Kiro's Remote-SSH list:** `~/.ssh/config` needs the
  `Include` line (step 3); the script adds it unless you passed `--no-ssh-include`. Reload the Kiro
  window afterwards.
- **Android never boots / `ihu` unhealthy:** launched without
  `--cpu-options NestedVirtualization=enabled` or not on c8i/m8i/r8i. Check `ls /dev/kvm` on
  day-2.
- **Can't reach a service on day-1 localhost:** the SSH session (with the forwards) must be
  open; reconnect `ssh remotive-hackathon`. Nothing is exposed publicly on day-2.
- **`build` says "No workspace detected":** run `remotive topology workspace init` first.
- **`whoami` prompts for login:** the two `REMOTIVE_CLOUD_*` env vars aren't set — redo step 4
  (source the setup script).
- **Containers all exited with code 143:** Someone hit `Ctrl+C` in the terminal running
  `docker compose up`. Restart with the same command.
- **"Open Remote - SSH" extension not working:** Make sure you've reloaded the Kiro window after
  installing the extension (`Cmd+Shift+P` → "Reload Window").

See **[`TROUBLESHOOTING.md`](TROUBLESHOOTING.md)** for the full symptom table, or ask Kiro: it has
the context for this box and can inspect containers and logs itself.
