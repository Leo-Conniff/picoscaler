# Raspberry Pi 5 Trustee for Confidential Containers

This project builds a lightweight, immutable OS image for Raspberry Pi 5 that runs the [Trustee](https://github.com/confidential-containers/trustee) attestation stack for confidential containers. It runs:

1. **Trustee KBS** — the Key Broker Service; primary interface for incoming requests and the relying party in the RATS model
2. **CoCo AS** — the Confidential Containers Attestation Service; the verifier component in the RATS model that evaluates TEE evidence
3. **RSVP** — the Reference Value Provider Service; holds known-good measurements for hardware, which must be protected from modification

## Why Raspberry Pi 5 for Trustee?

The Pi 5 acts as the trust anchor for the hyposcaler environment. Its role is not to hold secrets directly, but to validate that the core CA (OpenBao) is running in a secured confidential container before releasing the PIN that unlocks hardware-backed key material (a YubiKey in this architecture).

While the Pi 5 lacks physical tamper-resistant hardware and hardware memory isolation, it supports Secure Boot and can store an encryption key for a LUKS partition set during OTP provisioning. An attacker with direct physical access could read values from RAM to access encrypted data, but the split-responsibility model still holds: stealing the Pi 5 alone exposes only the YubiKey PIN, and gaining access only to the server leaves OpenBao unable to run or access any secrets.

In a more robust deployment these components would be backed by HSMs and a silicon-rooted trust anchor. In this model, Secure Boot on the Pi 5 is the equivalent of a manufacturing trust establishment process.

## Storage Layout

Storage for the Pi 5 must be split into at least four partitions:

| Partition | Purpose |
|---|---|
| Boot | Holds the initramfs; read by the bootloader |
| Primary OS | Read-only root filesystem; verified with dm-verity on boot |
| Secondary OS | Staging partition for OTA updates and A/B switching |
| Config/Secrets | Encrypted partition for durable configuration and secrets required by the Trustee stack |

The root filesystem is intentionally read-only and unencrypted as there is no sensitive data in it. This keeps the design simple and fast. Any configuration or secrets must reside in the encrypted partition so they are not extractable at rest.

## OS Design

The OS is built with [Yocto](https://www.yoctoproject.org/) targeting the `raspberrypi5` machine with the [meta-raspberrypi](https://github.com/agherzan/meta-raspberrypi) BSP layer. All layer repos track `master`. The custom `meta-pi-trustee` layer carries the layers to add the Trustee services and configurations needed for the Pi 5.

Yocto is chosen for its minimal footprint, full control over included packages, and the ability to produce a reproducible, signed image for an `aarch64` target without runtime emulation.

The only services outside the kernel and board support packages are the KBS, AS, and RSVP binaries and their runtime dependencies.

## Building

All builds run inside the build Docker container defined in the project root, which bundles the Yocto host dependencies and [kas](https://kas.readthedocs.io/) (v4.4) for layer and configuration management.

### Prerequisites

- Docker
- ~100 GB of free disk space
- Cache volumes for downloads and sstate are optional but strongly recommended. Without them every build re-fetches all sources and recompiles from scratch

### macOS: Case-Sensitive Filesystem Setup

Yocto requires a case-sensitive filesystem. macOS uses case-insensitive APFS by default, which causes build failures. Run the setup script once before your first build on macOS to create case-sensitive APFS sparse bundle images:

```bash
bash scripts/setup-macos.sh
```

This creates two sparse bundles in `$HOME` (consuming only actual used space up to the size limit):

| Image | Mount point | Size limit |
|---|---|---|
| `~/yocto-workspace.sparsebundle` | `/Volumes/yocto-workspace` | 150 GB |
| `~/yocto-cache.sparsebundle` | `/Volumes/yocto-cache` | 200 GB |

The script is idempotent and it skips creation if the bundle already exists and skips mounting if already attached. Re-run it after a reboot before building.

On Linux, set the variables below to directories on a native ext4/xfs filesystem instead.

### Environment Variables

Set these before running any build command. On macOS these correspond to the sparse bundle volumes:

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

The `meta-pi-trustee` layer must be present in the workspace volume before the build starts. The build container reads from the workspace volume, not from the repository checkout directly.

From the `os/pi-trustee` project root:

```bash
rsync -av --delete \
  meta-pi-trustee/ \
  "${WORKSPACE_VOL}/"
```

Run this step whenever anything in `meta-pi-trustee/` has changed (recipes, configuration, kas file). On macOS, ensure the workspace sparse bundle is mounted (step above) before running this.

### 3. Fetch container images

The Yocto build bakes the Trustee container images directly into the root filesystem. Pull them from ghcr.io before building using the prep script:

```bash
export CONTAINER_ARCHIVE=/path/to/container/cache

bash scripts/container-prep.sh
```

This requires skopeo on the host. It archives the containers in the docker archive format for installation on the yocto image.

The images are loaded into containerd at boot by `trustee-container-loader.service`. You can verify after boot with `nerdctl images`.

### 4. Build the Yocto image

On macOS, a separate Docker-managed volume (`yocto-tmp`) holds BitBake's temporary files. this ensures the tmp directory sits on a native filesystem regardless of the workspace volume, which avoids symlink compatibility issues. On Linux, you can specify a local folder mount point instead.

```bash
docker run --rm \
  -v "${WORKSPACE_VOL}:/workspace" \
  -v "${DOWNLOAD_VOL}:/cache/downloads" \
  -v "${SSTATE_VOL}:/cache/sstate" \
  -v "${CONTAINER_ARCHIVE}:/cache/containers" \
  -v yocto-tmp:/cache/tmp \
  pi-trustee-builder
```

kas clones the required layers (`openembedded-core`, `meta-yocto`, `meta-raspberrypi`) into the workspace on first run, configures the build environment, and invokes BitBake to produce a `core-image-minimal` for `raspberrypi5`.

The finished image will be at:

```
${WORKSPACE_VOL}/build/tmp/deploy/images/raspberrypi5/core-image-minimal-raspberrypi5-rootfs***.wic.bz2
```

### 5. Flash the image

```bash
bunzip2 -k "${WORKSPACE_VOL}/build/tmp/deploy/images/raspberrypi5/core-image-minimal-raspberrypi5-rootfs***.wic.bz2"
bmaptool copy core-image-minimal-raspberrypi5.wic /dev/sdX
```

Replace `/dev/sdX` with the target SD card device (e.g. `/dev/sda` on Linux, `/dev/disk4` on macOS).

## Reproducible Builds

After a successful build, generate a lock file to pin all layer commits to the exact revisions used:

```bash
docker run --rm \
  -v "${WORKSPACE_VOL}:/workspace" \
  pi-trustee-builder dump --lock kas-pi-trustee.yml
```

Copy the resulting `kas-pi-trustee.lock.yml` into `meta-pi-trustee/` and commit it. kas loads the lock file automatically on subsequent runs, making builds byte-for-byte reproducible.

## Useful kas Commands

Pass these as arguments to override the default `docker run` command:

```bash
# Drop into a shell with the Yocto environment initialised (for manual bitbake runs)
docker run --rm -it \
  -v "${WORKSPACE_VOL}:/workspace" \
  -v "${DOWNLOAD_VOL}:/cache/downloads" \
  -v "${SSTATE_VOL}:/cache/sstate" \
  -v yocto-tmp:/cache/tmp \
  pi-trustee-builder shell kas-pi-trustee.yml

# Fetch and check out all layers without starting a build
docker run --rm \
  -v "${WORKSPACE_VOL}:/workspace" \
  -v "${DOWNLOAD_VOL}:/cache/downloads" \
  -v "${SSTATE_VOL}:/cache/sstate" \
  -v yocto-tmp:/cache/tmp \
  pi-trustee-builder checkout kas-pi-trustee.yml
```
