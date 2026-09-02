SUMMARY = "Lightweight Kubernetes (k3s) binary distribution"
HOMEPAGE = "https://k3s.io"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/Apache-2.0;md5=89aea4e17d99a7cacdbeed46a0096b10"

inherit systemd

K3S_VERSION = "v1.31.6+k3s1"

SRC_URI = " \
    https://github.com/k3s-io/k3s/releases/download/${K3S_VERSION}/k3s-arm64;downloadfilename=k3s-arm64-${K3S_VERSION};name=arm64 \
    file://k3s.service \
"
SRC_URI[arm64.sha256sum] = "1909a4904e5b426e2aac50ef1a72821a9a03e744ea896f26b7e415a490fdfac6"

S = "${UNPACKDIR}"

INSANE_SKIP:${PN} += "already-stripped"
INHIBIT_PACKAGE_STRIP = "1"
INHIBIT_SYSROOT_STRIP = "1"
INHIBIT_PACKAGE_DEBUG_SPLIT = "1"

SYSTEMD_SERVICE:${PN} = "k3s.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${S}/k3s-arm64-${K3S_VERSION} ${D}${bindir}/k3s

    # Create standard symlinks for kubectl, crictl, ctr
    ln -sf k3s ${D}${bindir}/kubectl
    ln -sf k3s ${D}${bindir}/crictl
    ln -sf k3s ${D}${bindir}/ctr

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${S}/k3s.service ${D}${systemd_system_unitdir}/k3s.service
}

FILES:${PN} += " \
    ${bindir}/k3s \
    ${bindir}/kubectl \
    ${bindir}/crictl \
    ${bindir}/ctr \
    ${systemd_system_unitdir}/k3s.service \
"

RDEPENDS:${PN} += "iptables iproute2"
COMPATIBLE_HOST = "aarch64.*-linux"
