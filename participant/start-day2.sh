#!/usr/bin/env bash
#
# start-day2.sh — the ONE command you run on the day-1 machine.
#
#   ./participant/start-day2.sh
#
# It brings the day-2 RemotiveCar box up and hands you a box you can connect Kiro to:
#
#   1. Preflight        — aws / ssh / rsync present, credentials valid, key pair usable.
#   2. Security group   — reuse or create `remotive-hackathon`, allow SSH from this machine's IP.
#   3. The box          — reuse a running instance, start a stopped one, or launch a new one
#                         from the public AMI with nested virtualization enabled.
#   4. ssh_config       — write the box's IP into participant/ssh_config, and add the one
#                         `Include` line to ~/.ssh/config so `remotive-hackathon` resolves
#                         (that is also what makes the host appear in Kiro's Remote-SSH list).
#   5. Copy             — rsync this whole aws-hackathon folder to ~/aws-hackathon on the box.
#   6. Auth + context   — run `participant/setup-day2.sh` there: service-account token into
#                         ~/.ssh/environment, .kiro + dashboards symlinks.
#   7. Verify           — prove the token is present in a *fresh* non-interactive SSH session
#                         (that is how Kiro runs commands), and that /dev/kvm exists.
#
# It deliberately STOPS THERE. It does not build the topology and does not start the car:
# nothing from the lab is ever run from day-1. You do that on day-2, from Kiro, after
# connecting with Remote-SSH — the script prints the exact steps at the end.
#
# Options (all optional):
#   --region <r>          default: $AWS_REGION, else $AWS_DEFAULT_REGION, else us-west-1
#   --ami <id>            override the region's AMI
#   --instance-type <t>   default c8i.4xlarge (needs c8i/m8i/r8i for Android/KVM)
#   --key-name <n>        EC2 key pair name, default my-key
#   --key-file <path>     matching private key, default ~/.ssh/my-key.pem
#   --name <tag>          Name tag used to find/create the box, default remotive-hackathon
#   --instance-id <id>    use exactly this instance, skip discovery
#   --no-sg               do not create or modify any security group
#   --no-ssh-include      do not touch ~/.ssh/config (you add the Include line yourself)
#   --no-update           do not `git pull` the examples repo on the box
#   --launch-only         stop after the box is reachable (no copy, no setup)
#   --skip-aws            no AWS calls at all; use the HostName already in ssh_config
#                         (for re-running the copy + setup against a box that is already up)
#   -h | --help
#
set -euo pipefail

# ---------------------------------------------------------------------------- defaults
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-us-west-1}}"
AMI_ID=""
INSTANCE_TYPE="c8i.4xlarge"
KEY_NAME="my-key"
KEY_FILE="$HOME/.ssh/my-key.pem"
NAME_TAG="remotive-hackathon"
INSTANCE_ID=""
SSH_ALIAS="remotive-hackathon"
SG_NAME="remotive-hackathon"
ROOT_VOLUME_GB=100
DO_SG=true
DO_SSH_INCLUDE=true
DO_UPDATE=true
LAUNCH_ONLY=false
SKIP_AWS=false

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HACKATHON_DIR="$(cd "${HERE}/.." && pwd)"
SSH_CONFIG_FILE="${HERE}/ssh_config"
EXAMPLES_DIR_REMOTE='$HOME/remotivelabs-topology-examples'

# ---------------------------------------------------------------------------- helpers
step()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
info()  { printf '    %s\n' "$*"; }
ok()    { printf '    \033[32m[ok]\033[0m   %s\n' "$*"; }
warn()  { printf '    \033[33m[warn]\033[0m %s\n' "$*"; }
die()   { printf '\n\033[31m[FAIL]\033[0m %s\n\n' "$*" >&2; exit 1; }

need() { command -v "$1" >/dev/null 2>&1 || die "'$1' is not installed on this machine. $2"; }

usage() { sed -n '2,/^set -euo/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//;$d'; }

ami_for_region() {
  # Public day-2 AMI per region — keep in sync with participant/INSTRUCTIONS.md.
  case "$1" in
    us-west-1)    echo "ami-0175ecdc439312e2f" ;;
    us-east-1)    echo "ami-01427a11059a0b23d" ;;
    eu-central-1) echo "ami-0ad3d7ef0066987e6" ;;
    *)            echo "" ;;
  esac
}

aws_ec2() { aws ec2 --region "$REGION" "$@"; }

# ---------------------------------------------------------------------------- args
while [ $# -gt 0 ]; do
  case "$1" in
    --region)         REGION="${2:?}"; shift 2 ;;
    --ami)            AMI_ID="${2:?}"; shift 2 ;;
    --instance-type)  INSTANCE_TYPE="${2:?}"; shift 2 ;;
    --key-name)       KEY_NAME="${2:?}"; shift 2 ;;
    --key-file)       KEY_FILE="${2:?}"; shift 2 ;;
    --name)           NAME_TAG="${2:?}"; shift 2 ;;
    --instance-id)    INSTANCE_ID="${2:?}"; shift 2 ;;
    --no-sg)          DO_SG=false; shift ;;
    --no-ssh-include) DO_SSH_INCLUDE=false; shift ;;
    --no-update)      DO_UPDATE=false; shift ;;
    --launch-only)    LAUNCH_ONLY=true; shift ;;
    --skip-aws)       SKIP_AWS=true; shift ;;
    -h|--help)        usage; exit 0 ;;
    *) die "unknown option: $1  (see --help)" ;;
  esac
done

printf '\n\033[1mRemotiveTopology hackathon — day-1 → day-2 setup\033[0m\n'
info "hackathon folder : ${HACKATHON_DIR}"
$SKIP_AWS || info "region           : ${REGION}"
info "ssh host alias   : ${SSH_ALIAS}"

# ============================================================== 1. preflight (day-1)
step "1/7  Preflight on this (day-1) machine"

need ssh   "Install OpenSSH."
need rsync "Install rsync (macOS: preinstalled; Ubuntu: apt install rsync)."

case "$KEY_FILE" in
  *[[:space:]]*) die "the private key path must not contain spaces (rsync -e cannot quote it): ${KEY_FILE}" ;;
esac

if ! $SKIP_AWS; then
  need aws "Install the AWS CLI: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
  aws sts get-caller-identity --region "$REGION" >/dev/null 2>&1 \
    || die "AWS credentials are not working for region ${REGION}. Run 'aws configure' (or set AWS_PROFILE) and try again."
  ok "AWS credentials valid ($(aws sts get-caller-identity --region "$REGION" --query Arn --output text 2>/dev/null))"
fi

[ -f "$KEY_FILE" ] || die "private key not found at ${KEY_FILE}.
    Create the key pair on day-1 and use the SAME name at launch:
      aws ec2 create-key-pair --region ${REGION} --key-name ${KEY_NAME} \\
        --query KeyMaterial --output text > ${KEY_FILE} && chmod 600 ${KEY_FILE}
    Or point at an existing key with --key-file / --key-name."

perms="$(ls -l "$KEY_FILE" | cut -c1-10)"
case "$perms" in
  -rw-------|-r--------) : ;;
  *) chmod 600 "$KEY_FILE" && info "tightened permissions on ${KEY_FILE} to 600" ;;
esac
ok "private key: ${KEY_FILE}"

[ -f "${HERE}/service-account.json" ] \
  || warn "participant/service-account.json is missing — step 6 will not be able to install the token."
[ -d "${HACKATHON_DIR}/.kiro/steering" ] \
  || warn "${HACKATHON_DIR}/.kiro/steering is missing — Kiro on day-2 will have no hackathon context."

SSH_OPTS=(-i "$KEY_FILE" -o IdentitiesOnly=yes -o BatchMode=yes -o ConnectTimeout=10
          -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR)

# ============================================== 2. security group (SSH from this IP)
DAY1_IP=""
if ! $SKIP_AWS && $DO_SG; then
  step "2/7  Security group — SSH from this machine only"
  DAY1_IP="$(curl -fsS --max-time 10 https://checkip.amazonaws.com 2>/dev/null | tr -d '[:space:]' || true)"
  if [ -z "$DAY1_IP" ]; then
    warn "could not determine this machine's public IP; skipping the ingress rule."
  else
    info "this machine's public IP: ${DAY1_IP}"
  fi
else
  step "2/7  Security group — skipped"
  $SKIP_AWS && info "--skip-aws given" || info "--no-sg given"
fi

ensure_ssh_ingress() {   # $1 = security group id
  [ -n "${DAY1_IP}" ] || return 0
  local out
  if out="$(aws_ec2 authorize-security-group-ingress --group-id "$1" \
              --protocol tcp --port 22 --cidr "${DAY1_IP}/32" 2>&1)"; then
    ok "$1: allowed SSH from ${DAY1_IP}/32"
  elif printf '%s' "$out" | grep -q 'InvalidPermission.Duplicate'; then
    ok "$1: SSH from ${DAY1_IP}/32 already allowed"
  else
    # Anything else is real — a missing IAM permission must not look like success.
    warn "$1: could not add the SSH rule. If you cannot connect later, this is why:"
    printf '           %s\n' "$(printf '%s' "$out" | tail -1)"
  fi
}

SG_ID=""
if ! $SKIP_AWS && $DO_SG; then
  SG_ID="$(aws_ec2 describe-security-groups --filters "Name=group-name,Values=${SG_NAME}" \
            --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null || echo "None")"
  if [ -z "$SG_ID" ] || [ "$SG_ID" = "None" ]; then
    SG_ID="$(aws_ec2 create-security-group --group-name "$SG_NAME" \
              --description "RemotiveTopology hackathon (SSH only)" \
              --query GroupId --output text)"
    ok "created security group ${SG_NAME} (${SG_ID}) — inbound SSH only, nothing else exposed"
  else
    ok "reusing security group ${SG_NAME} (${SG_ID})"
  fi
  ensure_ssh_ingress "$SG_ID"
fi

# ==================================================================== 3. the day-2 box
step "3/7  The day-2 box"

LAUNCHED_NEW=false
PUBLIC_IP=""

if $SKIP_AWS; then
  PUBLIC_IP="$(awk -v a="$SSH_ALIAS" '
      $1=="Host" { inb = ($2==a) }
      inb && tolower($1)=="hostname" { print $2; exit }
    ' "$SSH_CONFIG_FILE")"
  [ -n "$PUBLIC_IP" ] || die "--skip-aws needs a HostName for '${SSH_ALIAS}' in ${SSH_CONFIG_FILE}."
  ok "using ${PUBLIC_IP} from ssh_config (no AWS calls)"
else
  if [ -z "$INSTANCE_ID" ]; then
    found="$(aws_ec2 describe-instances \
      --filters "Name=tag:Name,Values=${NAME_TAG}" \
                "Name=instance-state-name,Values=pending,running,stopping,stopped" \
      --query 'Reservations[].Instances[].[InstanceId,State.Name]' --output text 2>/dev/null || true)"
    count="$(printf '%s\n' "$found" | grep -c . || true)"
    if [ "${count:-0}" -gt 1 ]; then
      printf '\n%s\n' "$found" >&2
      die "more than one instance tagged Name=${NAME_TAG} in ${REGION}.
    Pick one with --instance-id <id>, or terminate the extras. One box per participant."
    fi
    if [ "${count:-0}" -eq 1 ]; then
      INSTANCE_ID="$(printf '%s\n' "$found" | awk '{print $1}')"
      state="$(printf '%s\n' "$found" | awk '{print $2}')"
      info "found ${INSTANCE_ID} (${state})"
      case "$state" in
        stopping)
          info "waiting for it to finish stopping…"
          aws_ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"
          state=stopped ;;
      esac
      if [ "$state" = "stopped" ]; then
        info "starting it…"
        aws_ec2 start-instances --instance-ids "$INSTANCE_ID" >/dev/null
        ok "start requested (a stopped box keeps its disk, so your previous work is still there)"
      else
        ok "already ${state} — reusing it, nothing launched"
      fi
    fi
  else
    info "using ${INSTANCE_ID} as given"
    state="$(aws_ec2 describe-instances --instance-ids "$INSTANCE_ID" \
              --query 'Reservations[].Instances[].State.Name' --output text)"
    case "$state" in
      terminated|shutting-down)
        die "${INSTANCE_ID} is ${state} — it cannot be started again. Launch a new box by re-running
    without --instance-id (nothing tagged ${NAME_TAG} means a fresh launch)." ;;
    esac
    if [ "$state" = "stopped" ] || [ "$state" = "stopping" ]; then
      [ "$state" = "stopping" ] && aws_ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"
      aws_ec2 start-instances --instance-ids "$INSTANCE_ID" >/dev/null
      ok "start requested"
    else
      ok "already ${state}"
    fi
  fi

  if [ -z "$INSTANCE_ID" ]; then
    # ---- nothing there: launch a new one from the AMI ----
    [ -n "$AMI_ID" ] || AMI_ID="$(ami_for_region "$REGION")"
    [ -n "$AMI_ID" ] || die "no published day-2 AMI for region ${REGION}.
    Use --region us-west-1, --region us-east-1 or --region eu-central-1, or pass --ami <id>
    if you copied the image."

    aws_ec2 describe-key-pairs --key-names "$KEY_NAME" >/dev/null 2>&1 \
      || die "EC2 key pair '${KEY_NAME}' does not exist in ${REGION}.
    A key pair is bound to the instance AT LAUNCH, so it has to exist first:
      aws ec2 create-key-pair --region ${REGION} --key-name ${KEY_NAME} \\
        --query KeyMaterial --output text > ${KEY_FILE} && chmod 600 ${KEY_FILE}"

    case "$INSTANCE_TYPE" in
      c8i.*|m8i.*|r8i.*) : ;;
      *) warn "instance type ${INSTANCE_TYPE} does not support nested virtualization.
              Android/Cuttlefish needs /dev/kvm — Part 2 does not. Use c8i/m8i/r8i if you want Android." ;;
    esac

    sg_args=()
    if [ -n "$SG_ID" ]; then sg_args=(--security-group-ids "$SG_ID"); fi

    cpu_args=()
    case "$INSTANCE_TYPE" in
      c8i.*|m8i.*|r8i.*) cpu_args=(--cpu-options NestedVirtualization=enabled) ;;
    esac

    info "launching ${INSTANCE_TYPE} from ${AMI_ID} in ${REGION}…"
    # ${arr[@]+"${arr[@]}"} so an empty array is safe under `set -u` on bash 3.2 (macOS default).
    INSTANCE_ID="$(aws_ec2 run-instances \
      --image-id "$AMI_ID" \
      --instance-type "$INSTANCE_TYPE" \
      ${cpu_args[@]+"${cpu_args[@]}"} \
      --key-name "$KEY_NAME" \
      ${sg_args[@]+"${sg_args[@]}"} \
      --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":${ROOT_VOLUME_GB},\"VolumeType\":\"gp3\",\"DeleteOnTermination\":true}}]" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${NAME_TAG}}]" \
      --query 'Instances[0].InstanceId' --output text)"
    LAUNCHED_NEW=true
    ok "launched ${INSTANCE_ID}"
  fi

  info "waiting for 'running'…"
  aws_ec2 wait instance-running --instance-ids "$INSTANCE_ID"

  # An existing box may sit behind a different SG, and home IPs change — make sure we can get in.
  if $DO_SG && [ -n "$DAY1_IP" ]; then
    for sg in $(aws_ec2 describe-instances --instance-ids "$INSTANCE_ID" \
                  --query 'Reservations[].Instances[].SecurityGroups[].GroupId' --output text); do
      [ "$sg" = "$SG_ID" ] && continue
      ensure_ssh_ingress "$sg"
    done
  fi

  PUBLIC_IP="$(aws_ec2 describe-instances --instance-ids "$INSTANCE_ID" \
                --query 'Reservations[].Instances[].PublicIpAddress' --output text)"
  [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "None" ] \
    || die "${INSTANCE_ID} is running but has no public IP. Launch it in a subnet with auto-assign public IP on."
  ok "${INSTANCE_ID} is running at ${PUBLIC_IP}"
fi

# ======================================================== 4. ssh_config (day-1 side)
step "4/7  SSH config on this machine"

tmp="$(mktemp)"
awk -v a="$SSH_ALIAS" -v ip="$PUBLIC_IP" '
  $1=="Host" { inb = ($2==a) }
  inb && tolower($1)=="hostname" { print "    HostName " ip; next }
  { print }
' "$SSH_CONFIG_FILE" >"$tmp" && mv "$tmp" "$SSH_CONFIG_FILE"
ok "${SSH_CONFIG_FILE}: HostName → ${PUBLIC_IP}"

if $DO_SSH_INCLUDE; then
  user_cfg="$HOME/.ssh/config"
  mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
  if [ -f "$user_cfg" ] && grep -qF "$SSH_CONFIG_FILE" "$user_cfg"; then
    ok "${user_cfg} already includes the hackathon config"
  else
    backup="${user_cfg}.bak-$(date +%Y%m%d-%H%M%S)"
    if [ -f "$user_cfg" ]; then cp "$user_cfg" "$backup"; fi
    tmp="$(mktemp)"
    {
      echo "# RemotiveTopology hackathon (added by participant/start-day2.sh)"
      echo "Include ${SSH_CONFIG_FILE}"
      echo
      [ -f "$user_cfg" ] && cat "$user_cfg"
    } >"$tmp"
    mv "$tmp" "$user_cfg"
    chmod 600 "$user_cfg"
    ok "added 'Include ${SSH_CONFIG_FILE}' at the top of ${user_cfg}"
    [ -f "$backup" ] && info "previous file backed up as ${backup}"
  fi
else
  warn "--no-ssh-include: add this line yourself at the TOP of ~/.ssh/config, or '${SSH_ALIAS}' will not resolve
          (Kiro's Remote-SSH host list reads that file):
              Include ${SSH_CONFIG_FILE}"
fi

# ------ wait for sshd
if $LAUNCHED_NEW; then
  ssh-keygen -R "$PUBLIC_IP" >/dev/null 2>&1 || true   # fresh box, possibly recycled IP
fi

info "waiting for SSH on ${PUBLIC_IP} (a fresh box needs a minute)…"
reachable=false
for _ in $(seq 1 60); do
  if ssh "${SSH_OPTS[@]}" "ubuntu@${PUBLIC_IP}" true >/dev/null 2>&1; then reachable=true; break; fi
  sleep 5
done
$reachable || die "cannot SSH to ubuntu@${PUBLIC_IP} after 5 minutes.
    Check, in this order:
      • the security group allows TCP 22 from $(printf '%s' "${DAY1_IP:-your IP}")/32
      • the box was launched with --key-name ${KEY_NAME}, matching ${KEY_FILE}
        (a key pair created after launch is NOT added retroactively)
      • host key changed after a relaunch:  ssh-keygen -R ${PUBLIC_IP}"
ok "SSH works: ssh ${SSH_ALIAS}  (and 'ubuntu@${PUBLIC_IP}')"

if $LAUNCH_ONLY; then
  step "Done (--launch-only)"
  info "The box is up and reachable. Nothing was copied and no setup was run."
  info "Re-run without --launch-only, or with --skip-aws, to finish steps 5–7."
  exit 0
fi

# ============================================================ 5. copy the folder over
step "5/7  Copy ${HACKATHON_DIR} → ubuntu@${PUBLIC_IP}:~/aws-hackathon"

info "the git history stays here on day-1 (--exclude .git); the box gets the files only"
rsync -a --exclude .git --exclude .DS_Store \
  -e "ssh -i ${KEY_FILE} -o IdentitiesOnly=yes -o BatchMode=yes -o StrictHostKeyChecking=accept-new -o LogLevel=ERROR" \
  "${HACKATHON_DIR}" "ubuntu@${PUBLIC_IP}:~/"
ok "copied (it must land at ~/aws-hackathon — setup-day2.sh builds its symlinks from its own location)"

# ================================================== 6. auth + Kiro context on day-2
step "6/7  Install auth and Kiro context on the box"

ssh "${SSH_OPTS[@]}" -T "ubuntu@${PUBLIC_IP}" bash -l -s <<'REMOTE' || die "setup-day2.sh failed on the box — see its output above."
source "$HOME/aws-hackathon/participant/setup-day2.sh"
REMOTE

if $DO_UPDATE; then
  step "6b/7  Refresh the examples repo on the box (git pull)"
  info "the checkout baked into the AMI can lag; this is box prep, not a lab step"
  ssh "${SSH_OPTS[@]}" -T "ubuntu@${PUBLIC_IP}" bash -l -s <<'REMOTE' || warn "repo refresh failed — not fatal, you can run 'remotive-hackathon-update --repo' on the box later."
if command -v remotive-hackathon-update >/dev/null 2>&1; then
  remotive-hackathon-update --repo
else
  git -C "$HOME/remotivelabs-topology-examples" pull --ff-only
fi
git -C "$HOME/remotivelabs-topology-examples" log --oneline -1
REMOTE
fi

# ======================================================================== 7. verify
step "7/7  Verify the box from a fresh, non-interactive SSH session"
info "this is exactly how Kiro/Remote-SSH runs commands, so it is the check that matters"

ssh "${SSH_OPTS[@]}" "ubuntu@${PUBLIC_IP}" '
  if [ -n "${REMOTIVE_CLOUD_AUTH_TOKEN:-}" ]; then
    echo "    [ok]   cloud token   : present in a non-interactive session (org=${REMOTIVE_CLOUD_ORGANIZATION:-?})"
  else
    echo "    [FAIL] cloud token   : NOT in this session — the broker will exit on docker compose up"
  fi
  if [ -L "$HOME/remotivelabs-topology-examples/.kiro" ]; then
    echo "    [ok]   Kiro context  : $(readlink "$HOME/remotivelabs-topology-examples/.kiro")"
  else
    echo "    [FAIL] Kiro context  : .kiro symlink missing in the examples repo"
  fi
  if [ -e /dev/kvm ]; then
    echo "    [ok]   /dev/kvm      : present (Android/Cuttlefish can boot)"
  else
    echo "    [warn] /dev/kvm      : missing — Android will not boot. Part 2 does not need it."
  fi
  if remotive cloud auth whoami >/dev/null 2>&1; then
    echo "    [ok]   remotive auth : whoami succeeded without a login prompt"
  else
    echo "    [warn] remotive auth : whoami failed — check participant/service-account.json (token expires 2027-09-11)"
  fi
  printf "    [info] docker images : %s cached\n" "$(docker images -q 2>/dev/null | wc -l | tr -d " ")"
'

# ========================================================================= handover
cat <<EOF

$(printf '\033[1m')Day-1 is done. Nothing from the lab has been run — that is deliberate.$(printf '\033[0m')

No topology was built and no container was started. The car is built and run on day-2,
from Kiro, so that every command lands where the box, the buses and the logs are.

$(printf '\033[1m')Next, on this machine:$(printf '\033[0m')

  1. Keep a tunnel session open (it forwards Studio, the broker, the 3D car, Android, adb):
         ssh ${SSH_ALIAS}
     Leave it running — nothing is exposed on day-2 except port 22.

  2. Connect Kiro to the box:
         Cmd+Shift+P (macOS) / Ctrl+Shift+P → "Open Remote-SSH: Connect to Host" → ${SSH_ALIAS}
     First time only: install the "Open Remote - SSH" extension (Cmd+Shift+X), then reload the window.

  3. In the new Kiro window, open the folder:
         ~/remotivelabs-topology-examples
     That folder has the .kiro symlink, so Kiro there knows this car and this box.

  4. Open the lab in that window — it sits outside the folder you just opened, so use
     File → Open File… (or add ~/aws-hackathon as a second workspace folder):
         ~/aws-hackathon/participant/LAB.md

         Part 1  optional exercises (Exercise 1, starting the car, is the only one that matters)
         Part 2  the open brief — where the session is going

  5. Ask that Kiro — not this one — to start the car. A good first message:
         start the car and show me what is running

Box: ${INSTANCE_ID:-<existing>} at ${PUBLIC_IP} (region ${REGION})
Re-run this script any time to re-copy the folder after editing it on day-1 (add --skip-aws
to leave AWS alone). Stop the box when you are done, from day-1:
    aws ec2 stop-instances --region ${REGION} --instance-ids ${INSTANCE_ID:-<id>}      # keeps the disk
    aws ec2 terminate-instances --region ${REGION} --instance-ids ${INSTANCE_ID:-<id>} # gone for good

EOF
