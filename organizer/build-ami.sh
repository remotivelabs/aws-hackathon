#!/usr/bin/env bash
#
# build-ami.sh - Reproducibly build the RemotiveTopology hackathon AMI.
#
# Launches a fresh Ubuntu 24.04 c8i builder with nested virtualization enabled,
# runs provision.sh + installs the login MOTD, cleans machine-specific state,
# then creates an AMI and waits until it is available.
#
# Requirements: awscli v2 configured for the target account, an existing key pair
# and security group that allows SSH from the caller.
#
# Usage:
#   AWS_REGION=us-east-1 KEY_NAME=remotive-android KEY_FILE=./remotive-android.pem \
#   SECURITY_GROUP_ID=sg-xxxx SUBNET_ID=subnet-xxxx \
#   ./build-ami.sh
#
set -euo pipefail

# ---- config (override via env) ----------------------------------------------
AWS_REGION="${AWS_REGION:-us-east-1}"
INSTANCE_TYPE="${INSTANCE_TYPE:-c8i.4xlarge}"          # 8th-gen Intel => nested virt
KEY_NAME="${KEY_NAME:?set KEY_NAME}"
KEY_FILE="${KEY_FILE:?set KEY_FILE (path to the private key)}"
SECURITY_GROUP_ID="${SECURITY_GROUP_ID:?set SECURITY_GROUP_ID}"
SUBNET_ID="${SUBNET_ID:?set SUBNET_ID}"
ROOT_VOLUME_GB="${ROOT_VOLUME_GB:-100}"
AMI_NAME="${AMI_NAME:-remotive-topology-hackathon-$(date +%Y%m%d-%H%M%S)}"
SSM_AMI_PARAM="/aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"

aws() { command aws --region "$AWS_REGION" "$@"; }
log() { echo -e "\n### $* ###"; }

# ---- resolve base AMI -------------------------------------------------------
log "Resolving latest Ubuntu 24.04 amd64 AMI"
BASE_AMI="$(aws ssm get-parameter --name "$SSM_AMI_PARAM" --query 'Parameter.Value' --output text)"
echo "Base AMI: $BASE_AMI"

# ---- launch builder with nested virtualization enabled ----------------------
log "Launching builder ($INSTANCE_TYPE, NestedVirtualization=enabled)"
BUILDER_ID="$(aws ec2 run-instances \
  --image-id "$BASE_AMI" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SECURITY_GROUP_ID" \
  --subnet-id "$SUBNET_ID" \
  --cpu-options 'NestedVirtualization=enabled' \
  --block-device-mappings "[{\"DeviceName\":\"/dev/sda1\",\"Ebs\":{\"VolumeSize\":${ROOT_VOLUME_GB},\"VolumeType\":\"gp3\",\"DeleteOnTermination\":true}}]" \
  --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=remotive-ami-builder}]' \
  --query 'Instances[0].InstanceId' --output text)"
echo "Builder instance: $BUILDER_ID"

cleanup() {
  if [[ "${KEEP_BUILDER:-false}" != "true" && -n "${BUILDER_ID:-}" ]]; then
    log "Terminating builder $BUILDER_ID"
    aws ec2 terminate-instances --instance-ids "$BUILDER_ID" >/dev/null || true
  fi
}
trap cleanup EXIT

log "Waiting for builder to be running"
aws ec2 wait instance-running --instance-ids "$BUILDER_ID"
PUBIP="$(aws ec2 describe-instances --instance-ids "$BUILDER_ID" \
  --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)"
echo "Builder public IP: $PUBIP"

log "Waiting for SSH"
for i in $(seq 1 40); do
  if ssh -i "$KEY_FILE" $SSH_OPTS ubuntu@"$PUBIP" 'echo ok' >/dev/null 2>&1; then break; fi
  sleep 10
done

# ---- provision --------------------------------------------------------------
log "Copying provisioning scripts to builder"
scp -i "$KEY_FILE" $SSH_OPTS \
  "$SCRIPT_DIR/provision.sh" "$SCRIPT_DIR/99-remotive-motd.sh" \
  "$SCRIPT_DIR/../participant/update.sh" \
  ubuntu@"$PUBIP":/tmp/

log "Running provision.sh (this installs everything)"
ssh -i "$KEY_FILE" $SSH_OPTS ubuntu@"$PUBIP" \
  'chmod +x /tmp/provision.sh && sudo /tmp/provision.sh'

log "Installing login MOTD"
ssh -i "$KEY_FILE" $SSH_OPTS ubuntu@"$PUBIP" \
  'sudo cp /tmp/99-remotive-motd.sh /etc/update-motd.d/99-remotive && sudo chmod 0755 /etc/update-motd.d/99-remotive'

# ---- clean machine-specific state before imaging ----------------------------
log "Cleaning machine-specific state (cloud-init, ssh host keys, logs, shell history)"
ssh -i "$KEY_FILE" $SSH_OPTS ubuntu@"$PUBIP" 'sudo bash -s' <<'CLEAN'
set -e
cloud-init clean --logs || true
rm -f /etc/ssh/ssh_host_* || true
rm -f /home/ubuntu/.bash_history /root/.bash_history || true
# Do NOT bake in any RemotiveLabs auth token - each participant logs in themselves.
rm -rf /home/ubuntu/.config/.remotive /home/ubuntu/.remotive 2>/dev/null || true
truncate -s 0 /var/log/syslog 2>/dev/null || true
CLEAN

# ---- create the AMI ---------------------------------------------------------
log "Stopping builder before create-image"
aws ec2 stop-instances --instance-ids "$BUILDER_ID" >/dev/null
aws ec2 wait instance-stopped --instance-ids "$BUILDER_ID"

log "Creating AMI: $AMI_NAME"
AMI_ID="$(aws ec2 create-image \
  --instance-id "$BUILDER_ID" \
  --name "$AMI_NAME" \
  --description 'RemotiveTopology hackathon - Docker, RemotiveCLI+Studio, RemotiveBus, Wireshark, examples repo + workspace init. Launch with cpu-options NestedVirtualization=enabled.' \
  --query 'ImageId' --output text)"
echo "AMI: $AMI_ID"

log "Waiting for AMI to become available"
aws ec2 wait image-available --image-ids "$AMI_ID"

aws ec2 create-tags --resources "$AMI_ID" \
  --tags Key=Name,Value="$AMI_NAME" Key=project,Value=remotive-hackathon >/dev/null || true

log "DONE"
echo "AMI_ID=$AMI_ID"
echo "Launch participants with:  --cpu-options NestedVirtualization=enabled"
