require recipes-core/images/core-image-minimal.bb

SUMMARY = "Custom image for raspberry pi 5 that runs a complete KBS Trustee cluster."
LICENSE = "MIT"


IMAGE_INSTALL:append = " k3s helm k3s-config trustee-k3s-images trustee-helm volatile-binds iproute2 iptables"
EXTRA_IMAGE_FEATURES += "read-only-rootfs"
