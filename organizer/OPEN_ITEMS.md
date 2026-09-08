# Open items to attend later

Follow-ups flagged during setup of the hackathon AMI. None are blocking.

Current day-2 AMI (built 2026-09-19 by `build-ami.sh`, verified clean): **us-east-1
`ami-01427a11059a0b23d`** / **eu-central-1 `ami-0ad3d7ef0066987e6`**
(`remotive-topology-hackathon-day2-20260919-clean`) — SSH-tunnel model, service-account auth,
Organic Maps APK, CLI 0.34.1, no Docker images pre-pulled.

Superseded and **not to be used**: `ami-08de37a4b7b92ca19` (us-east-1) and
`ami-0ab06933113f68dc2` (eu-central-1), both dated 2026-09-18 and both **public**. They were
created with `aws ec2 create-image` directly against a working session box rather than by
`build-ami.sh`, so their examples checkout carries an applied Part 2 charge-alert solution
(10 modified files, 8 untracked). Evidence: `/var/log/remotive-provision-done.txt` inside them
reads 2026-09-14 09:54:29 while the images were registered 2026-09-18 14:19:08, and
`chassis_can.dbc` was modified 19 s before registration. Pull their public launch permission
and their snapshots', then deregister.

Cleanup TODO: the earlier **public** AMI `ami-06e937b77ab62ac63` predates the service-account
model and is still public — deregister it (and its snapshot) so the committed token is not
associated with a public image. Also deregister the stuck build `ami-08b3f6eb31f363894`.

## Build a RemotiveStudio dashboard (participant-facing demo)

Prepare a ready-made RemotiveStudio dashboard that showcases the running RemotiveCar, so a
participant sees something meaningful immediately. Include:
- **Relevant signals** — e.g. speed, gear, steering angle, turn/indicator + brake lamp
  states, HVAC set-points (from the topology broker on `localhost:50051` via the tunnel).
- **Frequency / time-series graphs** of those signals over the recorded playback drive.
- **Video** — the front/rear/left/right playback camera streams.
- **Map** — the vehicle location/track (Organic Maps APK is baked into the AMI for the
  in-Android map; the dashboard map is the Studio-side location view).

Decide how it ships: a saved Studio dashboard/layout committed in the repo and auto-loaded,
vs. documented manual setup. Verify it works over the SSH-tunnel (localhost) access model.

## 0. Upcoming RemotiveStudio release — simplify Studio access (waiting on release)

A new RemotiveStudio version is expected that removes the browser secure-context problem
(today the bundle calls `crypto.randomUUID`, which only exists over HTTPS or on
`localhost`, so `http://<PUBLIC_IP>:57123` loads but the app crashes). Once released,
Studio should work directly over the public IP and **SSH becomes optional** — started with
just:

```bash
remotive studio --no-browser
```

When it lands, do this:

1. Upgrade the CLI on the box: `remotive-hackathon-update --cli` (or rebuild the AMI).
2. Verify directly at `http://<PUBLIC_IP>:57123` with **no** tunnel.
3. Two things to check while verifying (both were constraints in the old build):
   - **Broker URL advertised to the browser.** Without a tunnel the client must reach the
     broker at the public IP, so `--advertised-broker-url http://<PUBLIC_IP>:50051` may be
     needed unless Studio now derives it from the browser location.
   - **CSP `connect-src`.** The old `index.html` only allowed `localhost`/`127.0.0.1` (plus
     `cloud.remotivelabs.com`) for outbound connections, which would block a public-IP
     broker even with the crypto issue fixed.
4. Then simplify the docs: drop the mandatory tunnel from `participant/INSTRUCTIONS.md`
   and the MOTD (keep `ssh_config`'s `LocalForward` as a convenience/fallback), and
   present `http://<PUBLIC_IP>:57123` as the primary Studio endpoint.

## 1. Multi-region availability of the AMI (main flag)

The AMI is public **only in us-east-1**. Participants in other regions cannot launch it
directly. To support other regions, for each target region:

1. Copy the AMI:
   ```bash
   aws ec2 copy-image --region <TARGET_REGION> \
     --source-region us-east-1 --source-image-id ami-06e937b77ab62ac63 \
     --name remotive-topology-hackathon
   ```
2. Wait until the copy is `available`, then make the copy AND its snapshot public
   (the account guardrail `block-new-sharing` must be temporarily disabled in that region
   first, then re-enabled — same dance as us-east-1):
   ```bash
   aws ec2 disable-image-block-public-access --region <TARGET_REGION>
   aws ec2 modify-image-attribute --region <TARGET_REGION> \
     --image-id <COPIED_AMI_ID> --launch-permission "Add=[{Group=all}]"
   aws ec2 modify-snapshot-attribute --region <TARGET_REGION> \
     --snapshot-id <COPIED_SNAPSHOT_ID> --attribute createVolumePermission \
     --operation-type add --group-names all
   aws ec2 enable-image-block-public-access --region <TARGET_REGION> \
     --image-block-public-access-state block-new-sharing
   ```
3. Add the new region + AMI ID to `participant/INSTRUCTIONS.md`.

Decide which regions to support and I can run this for each.

## 2. Nested virtualization is CLI-only (usability)

Cuttlefish needs `/dev/kvm`, which requires launching with
`--cpu-options NestedVirtualization=enabled` on a c8i/m8i/r8i type. The EC2 **console launch
wizard does not expose this option**, so console-launched instances will fail to boot Android.
Options to smooth this for participants:
- Provide a **launch template** (can encode the CPU option) they can launch from the console.
- Or keep the CLI-only instruction (currently documented in `participant/INSTRUCTIONS.md`).

## 3. Account guardrail note (informational)

`ImageBlockPublicAccess` was toggled off then back **on** (`block-new-sharing`) in us-east-1
to publish the AMI. It is currently re-enabled. The existing public AMI stays public; the
guardrail only blocks *new* public sharing. No action needed unless publishing more AMIs.

## 4. Leftover resources / cost (housekeeping)

- Manual Android test box **i-01d86bc4705e61d59** (34.234.100.26, c8i.4xlarge) was still
  running as of setup — terminate it when no longer needed to stop charges.
- Reusable infra kept in account 380142015251 / us-east-1: key pair `remotive-android`
  (private key `remotive-android.pem` in repo root), security group `sg-00f91909f739e8cdd`.
- The public AMI's backing snapshot is `snap-07acb20f5e4643d36` (also public).
