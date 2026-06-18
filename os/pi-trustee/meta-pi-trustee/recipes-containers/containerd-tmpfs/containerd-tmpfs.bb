SUMMARY = "Dedicated tmpfs mount for containerd"
DESCRIPTION = "Mounts a strict tmpfs over /var/lib/containerd to bypass nested OverlayFS with volatile-binds"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SRC_URI = "file://var-lib-containerd.mount"

SYSTEMD_SERVICE:${PN} = "var-lib-containerd.mount"
SYSTEMD_AUTO_ENABLE = "enable"

do_install() {
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/var-lib-containerd.mount ${D}${systemd_system_unitdir}/

    # Make sure folder exists on ro fs so it can guarantee mounting
    install -d ${D}/var/lib/containerd
}

FILES:${PN} += "\
    ${systemd_system_unitdir}/var-lib-containerd.mount \
    /var/lib/containerd \
"
RRECOMMENDS:${PN} += "containerd"