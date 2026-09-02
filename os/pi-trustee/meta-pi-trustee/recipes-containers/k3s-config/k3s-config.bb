SUMMARY = "Configuration, tmpfs mounts, and airgap staging for k3s on read-only rootfs"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SRC_URI = " \
    file://config.yaml \
    file://var-lib-rancher.mount \
    file://var-lib-kubelet.mount \
    file://k3s-prepare.service \
    file://k3s-prepare.sh \
"

S = "${UNPACKDIR}"

SYSTEMD_SERVICE:${PN} = " \
    var-lib-rancher.mount \
    var-lib-kubelet.mount \
    k3s-prepare.service \
"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    install -d ${D}${sysconfdir}/rancher/k3s
    install -m 0644 ${S}/config.yaml ${D}${sysconfdir}/rancher/k3s/config.yaml

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${S}/var-lib-rancher.mount ${D}${systemd_system_unitdir}/
    install -m 0644 ${S}/var-lib-kubelet.mount ${D}${systemd_system_unitdir}/
    install -m 0644 ${S}/k3s-prepare.service ${D}${systemd_system_unitdir}/

    install -d ${D}${bindir}
    install -m 0755 ${S}/k3s-prepare.sh ${D}${bindir}/k3s-prepare.sh

    # Create directory mount points on read-only rootfs
    install -d ${D}${localstatedir}/lib/rancher
    install -d ${D}${localstatedir}/lib/kubelet
    install -d ${D}${localstatedir}/lib/trustee/data
}

FILES:${PN} += " \
    ${sysconfdir}/rancher/k3s/config.yaml \
    ${systemd_system_unitdir} \
    ${bindir}/k3s-prepare.sh \
    ${localstatedir}/lib/rancher \
    ${localstatedir}/lib/kubelet \
    ${localstatedir}/lib/trustee/data \
"
RRECOMMENDS:${PN} += "k3s"
