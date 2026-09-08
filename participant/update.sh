#!/usr/bin/env bash
#
# update.sh - refresh the hackathon box: examples repo clone, RemotiveCLI (+Studio),
#             optionally RemotiveBus and the Docker images.
#
# Installed on the AMI as /usr/local/bin/remotive-hackathon-update (see organizer/provision.sh),
# so on the box you can simply run:
#
#   remotive-hackathon-update            # repo + CLI (default)
#   remotive-hackathon-update --all      # repo + CLI + RemotiveBus + docker images
#   remotive-hackathon-update --repo     # only git pull + git lfs pull
#   remotive-hackathon-update --cli      # only RemotiveCLI
#   remotive-hackathon-update --bus      # only RemotiveBus (remotivebusd)
#   remotive-hackathon-update --images   # only pull newer Docker images used by the topology
#
# Environment: REPO_DIR (default ~/remotivelabs-topology-examples), CLI_VERSION (pin a CLI version)
set -euo pipefail

REPO_DIR="${REPO_DIR:-$HOME/remotivelabs-topology-examples}"
CLI_INSTALLER="https://files.remotivelabs.com/remotivelabs-cli/install.sh"
BUS_INSTALLER="https://files.remotivelabs.com/remotivebus/install.sh"
IMAGES=(
  "remotivelabs/remotivebroker-server:1.25"
  "remotivelabs/3d-car:latest"
  "remotivelabs/remotivelabs-cuttlefish:16.0.0_r4-1"
)

do_repo=false; do_cli=false; do_bus=false; do_images=false
if [[ $# -eq 0 ]]; then do_repo=true; do_cli=true; fi
for arg in "$@"; do
  case "$arg" in
    --all)    do_repo=true; do_cli=true; do_bus=true; do_images=true ;;
    --repo)   do_repo=true ;;
    --cli)    do_cli=true ;;
    --bus)    do_bus=true ;;
    --images) do_images=true ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg (see --help)" >&2; exit 2 ;;
  esac
done

log() { echo -e "\n=== $* ==="; }

if $do_repo; then
  log "Examples repo: $REPO_DIR"
  if [[ ! -d "$REPO_DIR/.git" ]]; then
    echo "no git checkout at $REPO_DIR (set REPO_DIR or clone first)" >&2; exit 1
  fi
  cd "$REPO_DIR"
  git fetch --prune origin
  branch="$(git rev-parse --abbrev-ref HEAD)"
  if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
    # Keep the participant's work: stash, pull, re-apply.
    echo "local changes detected - stashing before pull"
    git stash push -m "remotive-hackathon-update $(date -Iseconds)"
    git pull --ff-only origin "$branch" || { echo "pull failed; your changes are in 'git stash list'" >&2; exit 1; }
    git stash pop || echo "WARNING: stash pop had conflicts - resolve them, then 'git stash drop'"
  else
    git pull --ff-only origin "$branch"
  fi
  git lfs pull
  echo "repo at: $(git log --oneline -1)"
  echo "NOTE: after a repo update, rebuild the topology (remotive topology build ...) before docker compose up."
fi

if $do_cli; then
  log "RemotiveCLI (installer upgrades in place; may ask for sudo)"
  before="$(remotive --version 2>/dev/null || echo 'not installed')"
  curl -fsSL "$CLI_INSTALLER" | bash -s -- ${CLI_VERSION:-}
  echo "before: $before"
  echo "after:  $(remotive --version)"
fi

if $do_bus; then
  log "RemotiveBus (remotivebusd)"
  curl -fsSL "$BUS_INSTALLER" | bash -s -- -y
  systemctl is-active remotivebusd 2>/dev/null && echo "remotivebusd active" || true
fi

if $do_images; then
  log "Docker images"
  for img in "${IMAGES[@]}"; do docker pull "$img"; done
  echo "Model images (bcm, gwm, ...) are rebuilt by 'docker compose up --build'."
fi

log "done"
