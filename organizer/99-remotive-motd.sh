#!/usr/bin/env bash
#
# 99-remotive - update-motd fragment shown on SSH login (day-2 RemotiveCar box).
# Installed to /etc/update-motd.d/99-remotive (mode 0755).
#
# This box (day-2) exposes ONLY SSH. Every service binds to loopback and is reached
# from the day-1 machine over SSH port-forwarding (see aws-hackaton/participant/ssh_config),
# so all URLs below are localhost ON DAY-1. localhost is a browser secure context and is
# in Studio's allow-list, so Studio/video/maps work with no extra setup.

REPO_DIR="/home/ubuntu/remotivelabs-topology-examples"

# Public IPv4 of this box (via IMDSv2), so the scp hint below shows the real host.
TOKEN="$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
  -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null || true)"
PUBIP="$(curl -s -H "X-aws-ec2-metadata-token: ${TOKEN}" \
  http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null || true)"
[ -z "$PUBIP" ] && PUBIP="<this-host>"

cat <<EOF

======================================================================
 RemotiveTopology hackathon — day-2 (RemotiveCar) box
======================================================================
 Preinstalled: Docker, RemotiveCLI (+ Studio), RemotiveBus, Wireshark,
 git-lfs, the examples repo, and the Android map APK.

 This box exposes ONLY SSH. Reach everything from your day-1 machine via
 the SSH tunnels in aws-hackaton/participant/ssh_config (ssh remotive-hackathon).

 Repo: ${REPO_DIR}

 GET GOING (in this SSH session):

   cd ${REPO_DIR}

   1) auth: copy service-account.json + remotive-auth here from day-1 (one time):
      #   scp -i ~/.ssh/my-key.pem participant/service-account.json \\
      #       participant/remotive-auth ubuntu@${PUBIP}:~/
      # then:  source ~/remotive-auth
      # Sets the token in this shell, in ~/.ssh/environment (so every SSH session gets
      # it too - incl. non-interactive commands from Kiro/VS Code Remote-SSH), and in
      # /etc/environment if passwordless sudo is available (covers NICE DCV/console).

   2) remotive topology workspace init                  # one-time; answer 'y' to consent

   3) remotive topology build \\
        -f remotive_car/instances/android/main.instance.yaml \\
        -f remotive_car/instances/android/cuttlefish.instance.yaml \\
        remotive_car/build

   4) docker compose \\
        -f remotive_car/build/remotive_car_android/docker-compose.yml \\
        -f remotive_car/instances/android/cuttlefish.compose.yaml \\
        --profile playback --profile 3dcar up --build

   5) remotive studio --no-browser                      # loopback; reached via the tunnel

 ACCESS — on your DAY-1 machine (ports forwarded over SSH):
   RemotiveStudio          : http://localhost:57123
   Android (Cuttlefish)    : https://localhost:8443
   3D car                  : http://localhost:3000
   Topology broker / API   : localhost:50051
   Jupyter (if enabled)    : http://localhost:8888/lab?token=remotivelabs
   Studio desktop app      : on day-1 (needs the CLI + the ssh_config tunnel):
                             remotive studio --desktop  -> talks to localhost:50051

 UPDATE: remotive-hackathon-update   (--all: also RemotiveBus + Docker images)

 Stop everything:
   docker compose -f remotive_car/build/remotive_car_android/docker-compose.yml \\
     -f remotive_car/instances/android/cuttlefish.compose.yaml \\
     --profile playback --profile 3dcar down
======================================================================

EOF
