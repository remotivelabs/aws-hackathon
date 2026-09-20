# ARM64 AMI Build Report

## Current build — 2026-09-20

**Status:** ✅ public in both regions. Built with `organizer/build-ami.sh`, which now takes `ARCH`.

| | |
|---|---|
| AMI | **us-east-1:** `ami-01837a4e45a10e866` / **eu-central-1:** `ami-05ac1fbdea026b519` |
| Name | `remotive-topology-hackathon-arm64-20260920-194721` |
| Base | Ubuntu 24.04 arm64 `ami-0246d714afcc1d494` (resolved from SSM) |
| Built on | `c7g.4xlarge` in us-east-1, then `copy-image` to eu-central-1 |
| Snapshots | `snap-0f8da5f7c6b049dee` (us-east-1) / `snap-04eea9c017f8a162b` (eu-central-1), both public |
| Size | **13.84 GiB** of real data on a 100 GiB declared root volume — Docker cache is **cold** (`PREPULL_IMAGES` unset, so no Cuttlefish) |

Built from the **same `provision.sh`** as the x86 image, so the two no longer drift. Two changes made
for this build:

- `build-ami.sh` takes `ARCH=amd64|arm64`. It picks the arch's Ubuntu SSM parameter, defaults the
  builder to `c7g.4xlarge` for arm64, and **omits `--cpu-options NestedVirtualization=enabled`**, which
  is Intel-only and fails the `run-instances` call on Graviton. The build needs no KVM itself.
- `provision.sh` is arch-aware: `kvm_intel` is only written to `modules-load.d` on x86_64 (on arm64 KVM
  is in-kernel, so listing a module only produces a boot warning). Its required packages were also
  split out from behind a `|| true`, which previously could hide a base-tooling failure until PART 2.

**Launching:** `c7g.metal`. Virtualized Graviton exposes no nested virtualization, so `/dev/kvm` needs
bare metal; there KVM is native and no CPU option is needed. Participant-facing instructions are in
`participant/INSTRUCTIONS.md` § *Optional track: Arm on Arm*.

**Publishing note:** the account has EC2 **Image Block Public Access** at `block-new-sharing` in both
regions. Publishing = `disable-image-block-public-access`, then `modify-image-attribute` +
`modify-snapshot-attribute`, then `enable-image-block-public-access` back to `block-new-sharing`.
Verified re-enabled in both regions after this build.

**Not yet done:** no on-box verification of the new image. Nothing has been launched from it — Docker,
the CLI, RemotiveBus, the buses and Cuttlefish are all unverified on this build. The content argument is
that it came from the same provisioning as the working x86 image.

**Superseded:** `ami-0b4c4739e522f410c` (the 2026-09-18 build below) is **deprecated** as of
2026-09-20T18:17Z — still launchable by ID, hidden from searches. Everything from here down describes
that first build and is kept for its ARM64 findings, not for its AMI IDs.

---

# First build (2026-09-18, superseded)

**Date:** 2026-09-18  
**Region:** eu-central-1 (Frankfurt)  
**Status:** ⚠️ **DEPRECATED 2026-09-20** — superseded by the build above

## AMI Details

- **AMI ID:** `ami-0b4c4739e522f410c`
- **Name:** `remotive-topology-hackathon-day2-arm64-20260918-183421`
- **Architecture:** ARM64 (aarch64)
- **Base Image:** Ubuntu 24.04 LTS ARM64 (ami-0e79e661e73ddfac9)
- **Instance Type Used for Build:** c7g.4xlarge (Graviton3, 16 vCPU, 32 GB RAM)
- **Visibility:** 🌍 **PUBLIC** (available to all AWS accounts worldwide)
- **Snapshot:** snap-029b327729af81a40 (also public)

## What Was Installed

The provisioning completed successfully with all core components:

### ✅ Verified Working on ARM64:
1. **Docker CE** - Installed and working
2. **RemotiveCLI** (0.34.1) - ARM64 native build available and working
3. **RemotiveBus** (0.11.3) - ARM64 native build available and working
4. **Wireshark/tshark** - Installed successfully
5. **git-lfs** - Working
6. **remotivelabs-topology-examples** - Cloned and ready
7. **Organic Maps APK** - Downloaded for Android (62 MB)
8. **All base packages** - curl, jq, make, socat, etc.

### ⚠️ Known Limitations:

1. **Cuttlefish/Android Emulator** - **MAY NOT WORK on ARM64**
   - Cuttlefish is designed primarily for x86_64 with nested virtualization
   - The ARM64 instance does not support nested virtualization in the same way
   - Android head unit functionality is **UNTESTED** on ARM64
   - This means the `android` instance from LAB.md Part 1 may fail

2. **KVM/Nested Virtualization**
   - ARM64 instances have different virtualization capabilities
   - `kvm_intel` module is x86-specific (provision script attempted to load it)
   - This will affect any workload requiring nested virtualization

## Build Process

```bash
# Base AMI selected
Ubuntu 24.04 LTS ARM64: ami-0e79e661e73ddfac9

# Instance launched
Instance Type: c7g.4xlarge
Storage: 100 GB gp3
Security Group: sg-0852be7ec83c794f5 (remotive-hackathon-eu-sg)

# Provisioning completed successfully
All packages installed without errors
RemotiveCLI confirmed working: remotive --version
RemotiveBus service installed and enabled
```

## AMI Public Access

✅ **The AMI and its snapshot are now public** and can be used by any AWS account.

To launch this AMI from **any AWS account**:

```bash
# Anyone can now use this AMI in eu-central-1
aws ec2 describe-images \
  --image-ids ami-0b4c4739e522f410c \
  --region eu-central-1 \
  --query 'Images[0].[State,Public,Name]' \
  --output table
```

**AMI Block Public Access Status:** Re-enabled in `block-new-sharing` mode (best practice - protects against accidental future shares while preserving existing public AMIs)

## Launch Instructions

Once the AMI is available:

```bash
# Launch an ARM64 bare metal instance
aws ec2 run-instances \
  --image-id ami-0b4c4739e522f410c \
  --instance-type c7g.metal \
  --key-name my-key \
  --security-group-ids <sg-id> \
  --subnet-id <subnet-id> \
  --region eu-central-1 \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=remotive-arm64-test}]'
```

### Recommended Instance Types:
- **c7g.metal** - 64 vCPU, 128 GB RAM (bare metal, best performance)
- **c7g.16xlarge** - 64 vCPU, 128 GB RAM (virtualized)
- **c7g.4xlarge** - 16 vCPU, 32 GB RAM (development/testing)
- **c6g family** - Previous generation Graviton2

## Testing Recommendations

Before using this AMI in production:

1. **Test RemotiveCLI/Studio:**
   ```bash
   remotive studio --no-browser
   ```

2. **Test RemotiveBus:**
   ```bash
   sudo systemctl status remotivebusd
   ```

3. **Test Docker:**
   ```bash
   docker run --rm hello-world
   ```

4. **Test the examples repo:**
   ```bash
   cd ~/remotivelabs-topology-examples
   remotive topology workspace init
   ```

5. **⚠️ CRITICAL: Test Android/Cuttlefish:**
   ```bash
   # Try building the android instance
   remotive topology build \
     -f remotive_car/instances/android/main.instance.yaml \
     -f remotive_car/instances/android/cuttlefish.instance.yaml \
     remotive_car/build
   
   # Try to start it
   docker compose \
     -f remotive_car/build/remotive_car_android/docker-compose.yml \
     -f remotive_car/instances/android/cuttlefish.compose.yaml \
     --profile playback --profile 3dcar up
   ```

6. **Test hello_world instance (no Android):**
   ```bash
   remotive topology build \
     -f remotive_car/instances/hello_world/main.instance.yaml \
     -f remotive_car/settings/can_over_udp.settings.instance.yaml \
     -f remotive_car/settings/vlan_using_bridge.settings.instance.yaml \
     remotive_car/build
   
   docker compose \
     -f remotive_car/build/remotive_car_hello_world/docker-compose.yml \
     --profile 3dcar up --build
   ```

## What Works Best on ARM64

The ARM64 AMI is **ideal for:**
- RemotiveCLI/Studio development work
- RemotiveBus testing
- Python behavioral model development
- The `hello_world` instance (no Android required)
- Any workload that doesn't require Android/Cuttlefish
- Cost-effective bare metal performance

## What to Avoid

The ARM64 AMI is **NOT recommended for:**
- The full `android` instance from LAB.md Part 1
- Workloads requiring x86 Android emulation
- Any scenario where Cuttlefish is essential

## Comparison with x86_64 AMI

| Feature | x86_64 (ami-0ab06933113f68dc2) | ARM64 (ami-0b4c4739e522f410c) |
|---------|-------------------------------|------------------------------|
| RemotiveCLI | ✅ Works | ✅ Works |
| RemotiveBus | ✅ Works | ✅ Works |
| Docker | ✅ Works | ✅ Works |
| Cuttlefish/Android | ✅ Works | ⚠️ Untested/May Not Work |
| Nested Virtualization | ✅ Full Support | ⚠️ Limited |
| Performance | Good | Excellent (Graviton3) |
| Cost | Baseline | ~20% cheaper |
| LAB.md Part 1 | ✅ Full Support | ⚠️ Partial (no Android) |
| LAB.md Part 2 | ✅ Works | ✅ Should Work |

## Next Steps

1. ✅ AMI creation initiated - wait 10-20 minutes
2. ⏳ Test launch an instance from the AMI
3. ⏳ Verify all core functionality works
4. ⏳ **Critically: Test Cuttlefish/Android** (expected to fail)
5. ⏳ Document actual limitations discovered during testing
6. ⏳ Decide on use case: development-only or full hackathon support

## Build Instance Details (Terminated)

- **Instance ID:** i-003518f6ced37d061
- **Public IP:** 63.183.198.220 (now released)
- **Status:** Terminated after AMI creation
- **Provisioning log:** /tmp/provision.log (on the instance, now gone)

## Notes

- The base Ubuntu 24.04 ARM64 AMI date shows as 2026-09-04, which appears to be future-dated but is the latest available
- All RemotiveLabs packages have native ARM64 builds available
- The provision script attempted to load `kvm_intel` which is x86-specific - this is expected to fail silently on ARM64
- PermitUserEnvironment is enabled for SSH to support RemotiveLabs auth token injection

---

**Created:** 2026-09-18 18:34:21 UTC  
**AMI Status Check:** `aws ec2 describe-images --image-ids ami-0b4c4739e522f410c --region eu-central-1`
