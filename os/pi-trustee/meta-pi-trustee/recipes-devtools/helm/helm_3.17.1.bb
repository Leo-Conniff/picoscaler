SUMMARY = "The Kubernetes Package Manager"
HOMEPAGE = "https://helm.sh"
LICENSE = "Apache-2.0"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/Apache-2.0;md5=89aea4e17d99a7cacdbeed46a0096b10"

SRC_URI = "https://get.helm.sh/helm-v${PV}-linux-arm64.tar.gz;name=arm64"
SRC_URI[arm64.sha256sum] = "c86c9b23602d4abbfae39d9634e25ab1d0ea6c4c16c5b154113efe316a402547"

S = "${UNPACKDIR}/linux-arm64"

INSANE_SKIP:${PN} += "already-stripped"
INHIBIT_PACKAGE_STRIP = "1"
INHIBIT_SYSROOT_STRIP = "1"
INHIBIT_PACKAGE_DEBUG_SPLIT = "1"

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${S}/helm ${D}${bindir}/helm
}

FILES:${PN} = "${bindir}/helm"
COMPATIBLE_HOST = "aarch64.*-linux"
