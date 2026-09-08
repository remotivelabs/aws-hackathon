#!/usr/bin/env bash
#
# provision.sh - Reproducible provisioning for the RemotiveTopology hackathon AMI.
#
# Runs as root on a fresh Ubuntu 24.04 (x86_64) instance. Idempotent / re-runnable.
#
#   Part 1 (base OS dependencies):
#     - apt base tooling, Wireshark (non-interactive), Docker CE + compose plugin,
#       KVM/SocketCAN kernel modules needed by Cuttlefish and RemotiveBus.
#   Part 2 (RemotiveLabs tooling + example content):
#     - RemotiveCLI (bundles RemotiveStudio), RemotiveBus (remotivebusd), git-lfs,
#       clone of remotivelabs-topology-examples, the Android map APK, and the update tool.
#
# The examples repo is left UNMODIFIED except for dropping a map APK into its
# git-ignored apks/ folder, so `remotive-hackathon-update` can still git-pull cleanly.
# Auth is via a service-account token (see aws-hackaton/participant), so a participant
# does NOT log in. Nothing is exposed publicly: services bind to loopback and are reached
# from the day-1 machine over SSH port-forwarding (participant/ssh_config).
#
set -euo pipefail

# ---- config -----------------------------------------------------------------
TARGET_USER="${TARGET_USER:-ubuntu}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
REPO_URL="${REPO_URL:-https://github.com/remotivelabs/remotivelabs-topology-examples.git}"
REPO_DIR="${REPO_DIR:-$TARGET_HOME/remotivelabs-topology-examples}"
export DEBIAN_FRONTEND=noninteractive

log() { echo -e "\n=== $* ==="; }

if [[ $EUID -ne 0 ]]; then
  echo "provision.sh must run as root" >&2
  exit 1
fi

# =============================================================================
# PART 1 - base OS dependencies (baked into the initial image)
# =============================================================================
log "PART 1: apt update + base packages"
apt-get update -y
apt-get install -y \
  ca-certificates curl gnupg git jq unzip make socat \
  cpu-checker qemu-kvm \
  linux-modules-extra-"$(uname -r)" || true

log "PART 1: Wireshark (non-interactive, allow non-root capture)"
# Preseed so the postinst does not open an interactive dialog.
echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections
apt-get install -y wireshark tshark
# Allow the target user to capture without sudo.
if getent group wireshark >/dev/null; then
  usermod -aG wireshark "$TARGET_USER" || true
fi

log "PART 1: Docker CE (official convenience script)"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
fi
usermod -aG docker "$TARGET_USER" || true
systemctl enable --now docker || true

log "PART 1: kernel modules for KVM (Cuttlefish) and SocketCAN (RemotiveBus)"
# These load at runtime on the actual instance; we also persist them for boot.
cat >/etc/modules-load.d/remotive.conf <<'EOF'
kvm_intel
vcan
vxcan
can-gw
EOF
for m in kvm_intel vcan vxcan can-gw; do modprobe "$m" 2>/dev/null || true; done

# =============================================================================
# PART 2 - RemotiveLabs tooling + example content (baked into the final image)
# =============================================================================
log "PART 2: git-lfs"
apt-get install -y git-lfs
git lfs install --system || true

log "PART 2: RemotiveCLI (includes RemotiveStudio)"
curl -fsSL https://files.remotivelabs.com/remotivelabs-cli/install.sh | bash
# The installer already places a working 'remotive' on PATH (apt -> /usr/bin/remotive).
# Only add a system-wide symlink if it is NOT already resolvable, and only to a
# candidate that actually executes (a bad symlink here shadows the real binary).
if ! command -v remotive >/dev/null 2>&1; then
  for cand in /usr/bin/remotive /opt/remotivelabs-cli/bin/remotive /root/.local/bin/remotive; do
    if [[ -x "$cand" ]] && "$cand" --version >/dev/null 2>&1; then
      ln -sf "$cand" /usr/local/bin/remotive
      break
    fi
  done
fi
# Sanity: 'remotive' must run for the target user (PATH-resolved).
sudo -u "$TARGET_USER" bash -lc 'remotive --version' || {
  echo "ERROR: remotive CLI not runnable for $TARGET_USER" >&2; exit 1;
}

log "PART 2: RemotiveBus (remotivebusd, non-interactive)"
curl -fsSL https://files.remotivelabs.com/remotivebus/install.sh | bash -s -- -y

log "PART 2: clone examples repo + git lfs pull"
if [[ ! -d "$REPO_DIR/.git" ]]; then
  sudo -u "$TARGET_USER" git clone "$REPO_URL" "$REPO_DIR"
fi
sudo -u "$TARGET_USER" bash -lc "cd '$REPO_DIR' && git pull --ff-only || true && git lfs pull || true"

log "PART 2: install Android map APK into the examples repo apks/ folder"
# The Cuttlefish image has no Google Play; the docs say to drop a map APK into
# remotive_car/instances/android/cuttlefish/apks/ (git-ignored, so the repo stays clean)
# and it is installed when the container starts. We use Organic Maps from F-Droid (FOSS,
# no Play Services needed), resolving the current version so this does not rot.
APK_DIR="$REPO_DIR/remotive_car/instances/android/cuttlefish/apks"
if [[ -d "$APK_DIR" ]] && ! ls "$APK_DIR"/*.apk >/dev/null 2>&1; then
  VC="$(curl -fsSL https://f-droid.org/api/v1/packages/app.organicmaps | jq -r .suggestedVersionCode)"
  if [[ -n "$VC" && "$VC" != "null" ]]; then
    APK_URL="https://f-droid.org/repo/app.organicmaps_${VC}.apk"
    if curl -fsSL -o "$APK_DIR/organicmaps.apk" "$APK_URL"; then
      chown "$TARGET_USER:$TARGET_USER" "$APK_DIR/organicmaps.apk"
      echo "installed $APK_URL -> $APK_DIR/organicmaps.apk ($(du -h "$APK_DIR/organicmaps.apk" | cut -f1))"
    else
      echo "WARNING: failed to download Organic Maps APK from $APK_URL" >&2
    fi
  else
    echo "WARNING: could not resolve Organic Maps version from F-Droid" >&2
  fi
else
  echo "apks/ dir missing or already has an APK — skipping"
fi

log "PART 2: install remotive-hackathon-update (participant/update.sh)"
# build-ami.sh copies participant/update.sh next to this script as /tmp/update.sh.
UPDATE_SRC="${UPDATE_SRC:-$(dirname "$0")/update.sh}"
if [[ -f "$UPDATE_SRC" ]]; then
  install -m 0755 "$UPDATE_SRC" /usr/local/bin/remotive-hackathon-update
else
  echo "WARNING: $UPDATE_SRC not found - remotive-hackathon-update not installed" >&2
fi

log "PART 2: enable PermitUserEnvironment (so ~/.ssh/environment reaches every SSH session)"
# The RemotiveCloud service-account token is only picked up by the CLI/broker via the
# REMOTIVE_CLOUD_AUTH_TOKEN env var (confirmed: file-based 'auth activate' does not accept
# a raw service-account token file). A plain shell 'export' or ~/.bashrc only covers
# interactive shells, not the non-interactive 'ssh host <cmd>' form that Remote-SSH tools
# (Kiro IDE, VS Code) use to run commands. Enabling PermitUserEnvironment lets sshd inject
# vars from the user's own ~/.ssh/environment into EVERY session it creates - interactive
# and non-interactive alike - with no participant sudo needed to set the token itself.
# (This does not cover NICE DCV/console sessions, which are not created by sshd; the
# participant's remotive-auth also writes /etc/environment, when it can, for that case.)
echo "PermitUserEnvironment yes" > /etc/ssh/sshd_config.d/99-remotive-userenv.conf
systemctl restart ssh || systemctl restart sshd || true

# NOTE: 'remotive topology workspace init' is intentionally NOT run here.
# The RemotiveCLI shows a first-run interactive analytics-consent prompt that cannot
# be answered non-interactively during image build. The participant runs the init as
# part of their own steps (it is included in the login MOTD), right after 'cli login'.

log "PART 2: (optional) pre-pull the heavy Cuttlefish image to speed first launch"
if [[ "${PREPULL_IMAGES:-false}" == "true" ]]; then
  sudo -u "$TARGET_USER" bash -lc 'docker pull remotivelabs/remotivelabs-cuttlefish:16.0.0_r4-1 || true'
fi

log "provisioning complete"
date > /var/log/remotive-provision-done.txt
echo "$REPO_DIR" >> /var/log/remotive-provision-done.txt
