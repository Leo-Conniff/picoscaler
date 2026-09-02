# Raspberry Pi 5 Trustee for Confidential Containers

This project builds a lightweight, immutable OS image for Raspberry Pi 5 that runs the [Trustee](https://github.com/confidential-containers/trustee) attestation stack for confidential containers using **k3s** and **Helm**. It runs:

1. **Trustee KBS** — the Key Broker Service; primary interface for incoming requests and the relying party in the RATS model
2. **CoCo AS** — the Confidential Containers Attestation Service; the verifier component in the RATS model that evaluates TEE evidence
3. **RSVP** — the Reference Value Provider Service; holds known-good measurements for hardware, which must be protected from modification

## Why Raspberry Pi 5 for Trustee?

The Pi 5 acts as the trust anchor for the hyposcaler environment. Its role is not to hold secrets directly, but to validate that the core CA (OpenBao) is running in a secured confidential container before releasing the PIN that unlocks hardware-backed key material (a YubiKey in this architecture).

While the Pi 5 lacks physical tamper-resistant hardware and hardware memory isolation, it supports Secure Boot and can store an encryption key for a LUKS partition set during OTP provisioning. An attacker with direct physical access could read values from RAM to access encrypted data, but the split-responsibility model still holds: stealing the Pi 5 alone exposes only the YubiKey PIN, and gaining access only to the server leaves OpenBao unable to run or access any secrets.

In a more robust deployment these components would be backed by HSMs and a silicon-rooted trust anchor. In this model, Secure Boot on the Pi 5 is the equivalent of a manufacturing trust establishment process.

## Storage Layout

Storage for the Pi 5 is split into four partitions:

| Partition | Mount Point / Purpose | Description |
|---|---|---|
| **Boot** | `/boot` | Holds the initramfs and kernel; read by the bootloader |
| **Primary OS** | `/` | Active read-only root filesystem; verified with dm-verity on boot |
| **Secondary OS** | Staging | Standby partition for atomic A/B OTA OS updates |
| **Config/Secrets** | `/var/lib/trustee/data` | Encrypted LUKS partition for durable keys, TLS certificates, policies, and reference values |

The root filesystem is strictly read-only and immutable. Ephemeral state for k3s (`/var/lib/rancher`, `/var/lib/kubelet`) runs on `tmpfs`. Durable secrets and certificates are bound directly from `/var/lib/trustee/data` to the Trustee pods via `hostPath` volumes.

## Air-Gapped & Immutable Architecture

The target Raspberry Pi 5 operates in a **strictly air-gapped environment** with no internet access at runtime:

- **Immutable A/B Updates**: Container images, Helm charts, and k3s binaries are locked build artifacts baked directly into the rootfs. Updates occur atomically via A/B partition swaps.
- **Strict Local Image Policy (`imagePullPolicy: Never`)**: All Trustee pods enforce `Never`. Kubelet will fail immediately rather than ever attempting network access.
- **Pre-Baked Container Archives**: All container images (`kbs`, `as`, `rvps`, `pause`, `coredns`) are pre-fetched at build time, baked into `/usr/share/k3s-images/`, and automatically loaded by k3s at boot.
- **Offline Helm Deployment**: The Helm chart and production `values.yaml` are bundled in `/usr/share/trustee-helm/` and deployed by `trustee-helm-deploy.service` on boot.

## OS Design

The OS is built with [Yocto](https://www.yoctoproject.org/) targeting the `raspberrypi5` machine with the [meta-raspberrypi](https://github.com/agherzan/meta-raspberrypi) BSP layer and `meta-virtualization`. All layer repos track `master`. The custom `meta-pi-trustee` layer packages the Trustee Helm chart, k3s offline configuration, and boot-time deployment units.

## Building

All builds run inside the build Docker container defined in the project root, which bundles the Yocto host dependencies and [kas](https://kas.readthedocs.io/) (v4.4) for layer and configuration management.

### Prerequisites

- Docker (allocate at least 12–16 GB RAM and 4+ GB Swap in Docker Desktop Settings -> Resources)
- `skopeo` (for container image caching during prep)
- `helm` (optional; if missing, prep script falls back to dockerized helm)
- ~100 GB of free disk space
- Cache volumes for downloads and sstate

### macOS: Case-Sensitive Filesystem Setup

Yocto requires a case-sensitive filesystem. macOS uses case-insensitive APFS by default, which causes build failures. Run the setup script once before your first build on macOS to create case-sensitive APFS sparse bundle images:

```bash
bash scripts/setup-macos.sh
```

This creates two sparse bundles in `$HOME`:

| Image | Mount point | Size limit |
|---|---|---|
| `~/yocto-workspace.sparsebundle` | `/Volumes/yocto-workspace` | 150 GB |
| `~/yocto-cache.sparsebundle` | `/Volumes/yocto-cache` | 200 GB |

### Environment Variables

Set these before running any build command:

```bash
export WORKSPACE_VOL=/Volumes/yocto-workspace/meta-pi-trustee
export DOWNLOAD_VOL=/Volumes/yocto-cache/downloads
export SSTATE_VOL=/Volumes/yocto-cache/sstate
```

### 1. Build the Docker image

Run once from the `os/pi-trustee` project root, or after any changes to `build.dockerfile`:

```bash
docker build \
  -f build.dockerfile \
  -t pi-trustee-builder \
  .
```

### 2. Sync the meta layer to the workspace volume

From the `os/pi-trustee` project root:

```bash
rsync -av --delete \
  meta-pi-trustee/ \
  "${WORKSPACE_VOL}/"
```

### 3. Fetch container images (Helm-driven)

The build script uses `helm template` against the Trustee Helm chart and `values.yaml` to dynamically discover and archive all required container images and k3s system airgap images:

```bash
export CONTAINER_ARCHIVE=/path/to/container/cache

bash scripts/container-prep.sh
```

### 4. Build the Yocto image

```bash
docker run --rm \
  -v "${WORKSPACE_VOL}:/workspace" \
  -v "${DOWNLOAD_VOL}:/cache/downloads" \
  -v "${SSTATE_VOL}:/cache/sstate" \
  -v "${CONTAINER_ARCHIVE}:/cache/containers" \
  -v yocto-tmp:/cache/tmp \
  pi-trustee-builder
```

The finished image will be at:

```
${WORKSPACE_VOL}/build/tmp/deploy/images/raspberrypi5/pi-trustee-raspberrypi5-*.rootfs.wic.bz2
```

### 5. Flash the image

Flash the generated image to your target SD card or drive using **[Balena Etcher](https://etcher.balena.io/)**:

1. Open Balena Etcher.
2. Select **Flash from file** and choose the built `.wic.bz2` (or decompressed `.wic`) image from:
   ```
   ${WORKSPACE_VOL}/build/tmp/deploy/images/raspberrypi5/pi-trustee-raspberrypi5-*.rootfs.wic.bz2
   ```
3. Select your target SD card / storage drive and click **Flash!**.

*(Alternative CLI option with bmaptool)*:
```bash
bunzip2 -k "${WORKSPACE_VOL}/build/tmp/deploy/images/raspberrypi5/pi-trustee-raspberrypi5-*.rootfs.wic.bz2"
bmaptool copy pi-trustee-raspberrypi5-*.rootfs.wic /dev/sdX
```

## Enabling Root Login for Testing & Validation

By default, the production image is hardened and headless with no TTY login and no default root user. To enable command-line validation on a connected monitor and keyboard:

### 1. Enable `debug-tweaks` in `kas-pi-trustee.yml`

Add `debug-tweaks` to `local_conf_header` in `kas-pi-trustee.yml` (or your build's `local.conf`):

```yaml
local_conf_header:
  debug: |
    # Enable passwordless root login (allow-root-login, empty-root-password)
    EXTRA_IMAGE_FEATURES += "debug-tweaks"
```

### 2. Log in via Monitor & Keyboard (TTY)

1. Connect an HDMI display and USB keyboard to the Raspberry Pi 5.
2. Boot the device. Once startup completes, you will see the `pi-trustee login:` prompt on screen (`tty1`).
3. Type `root` and press **Enter** (no password required) to access the shell.

## Runtime Verification on Raspberry Pi 5

Once logged in at the console, you can inspect the air-gapped k3s cluster and Helm deployment:

```bash
# Verify k3s service and node status
systemctl status k3s
kubectl get nodes -o wide

# Verify all images were imported locally into containerd
crictl images

# Verify image pull policy is strictly "Never"
kubectl get pods -n coco-trustee -o jsonpath='{..imagePullPolicy}'

# Verify Helm release and pod health
helm list -n coco-trustee
kubectl get pods -n coco-trustee -o wide

# Test KBS HTTP endpoint
curl -i http://localhost:8080/kbs/v0/version
```

## Reproducible Builds

After a successful build, generate a lock file to pin all layer commits:

```bash
docker run --rm \
  -v "${WORKSPACE_VOL}:/workspace" \
  pi-trustee-builder dump --lock kas-pi-trustee.yml
```
