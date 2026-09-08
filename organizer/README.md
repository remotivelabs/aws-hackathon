# RemotiveTopology hackathon AMI

Reproducible scripts that build a preconfigured AMI so a participant only needs to:

```bash
remotive cloud auth login --no-browser    # 1. sign in
remotive topology workspace init          # 2. init workspace (accept the prompt)
remotive topology build ...               # 3. build
docker compose ... up                     # 4. run
```

## What the AMI contains

**Part 1 (base OS deps):** Docker CE + compose, Wireshark + tshark, KVM & SocketCAN
kernel modules, base build tooling.

**Part 2 (RemotiveLabs tooling + content):** RemotiveCLI (bundles RemotiveStudio),
RemotiveBus (`remotivebusd`), git-lfs, and the `remotivelabs-topology-examples` repo
cloned to `/home/ubuntu`.

The RemotiveTopology **workspace is initialized by the participant** (step 2 above),
not baked in: the CLI shows a one-time interactive analytics-consent prompt on first
use that cannot be answered during an unattended image build.

RemotiveBus is a genuine runtime dependency: the Android example is built without the
`can_over_udp`/`vlan_using_bridge` settings, so the generated compose declares its
CAN/VLAN networks with `driver: remotivebus`, and `docker compose up` uses `remotivebusd`
to create them.

A login MOTD (`/etc/update-motd.d/99-remotive`) surfaces the service URLs and the
RemotiveStudio SSH port-forward command.

No RemotiveLabs auth token is baked in — each participant logs in with their own account.

## Files

| File | Purpose |
|---|---|
| `provision.sh` | Idempotent Part 1 + Part 2 provisioning, runs as root on Ubuntu 24.04. |
| `99-remotive-motd.sh` | Login banner: 3-step workflow, URLs, Studio tunnel command. |
| `build-ami.sh` | Orchestrator: launch builder (nested virt), provision, clean, create AMI. |
| `../participant/update.sh` | Installed as `/usr/local/bin/remotive-hackathon-update`: git pull + lfs of the repo, RemotiveCLI upgrade (`--all`: RemotiveBus, images). |

## Build the AMI

```bash
cd organizer
AWS_REGION=us-east-1 \
KEY_NAME=remotive-android \
KEY_FILE=../my-key.pem \
SECURITY_GROUP_ID=sg-xxxxxxxx \
SUBNET_ID=subnet-xxxxxxxx \
./build-ami.sh
```

Optional env: `INSTANCE_TYPE` (default `c8i.4xlarge`), `ROOT_VOLUME_GB` (default 100),
`AMI_NAME`, `PREPULL_IMAGES=true` (bake in the 7.4 GB Cuttlefish image), `KEEP_BUILDER=true`.

## Launch an instance from the AMI

Nested virtualization is a **launch-time** CPU option (Cuttlefish needs `/dev/kvm`); it is
only supported on 8th-gen Intel types (`c8i`/`m8i`/`r8i`):

```bash
aws ec2 run-instances \
  --image-id <AMI_ID> \
  --instance-type c8i.4xlarge \
  --cpu-options NestedVirtualization=enabled \
  --key-name <key> --security-group-ids <sg> --subnet-id <subnet> \
  --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":100,"VolumeType":"gp3"}}]'
```

Open ports for participants: 22 (ssh), 8443 (Android UI), 3000 (3D car), 8888 (Jupyter),
50051 (broker), 57123 (Studio, or reach it via the SSH tunnel), 6520 (adb, optional).
The participant SSH config also tunnels 57123, 50051 and 8888 to localhost.

## Updating an existing box without rebuilding the AMI

Participants run `remotive-hackathon-update` (repo + CLI) or `--all`. If the AMI predates the
update script, install it by hand: `scp participant/update.sh remotive-hackathon:/tmp/ &&
ssh remotive-hackathon sudo install -m 0755 /tmp/update.sh /usr/local/bin/remotive-hackathon-update`.
