require recipes-core/images/core-image-minimal.bb

SUMMARY = "Custom image for raspberry pi 5 that runs a complete KBS Trustee cluster."
LICENSE = "MIT"


IMAGE_INSTALL:append = " cni containerd containerd-tmpfs nerdctl iproute2 iptables runc trustee-containers volatile-binds"
EXTRA_IMAGE_FEATURES += "read-only-rootfs"
