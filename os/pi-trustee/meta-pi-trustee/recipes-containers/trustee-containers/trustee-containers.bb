SUMMARY = "Trustee container images and boot-time loader service"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SYSTEMD_SERVICE:${PN} = "trustee-container-loader.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

# CONTAINER_TARS set based on CONTAINER_ARCHIVE env var in kas conf

FILESEXTRAPATHS:prepend := "${THISDIR}/files:${CONTAINER_TARS}:"

# Some versions of Yocto will auto extract tar files. So save as archive ext and copy
SRC_URI = " \
    file://kbs.archive \
    file://rvps.archive \
    file://attest.archive \
    file://trustee-container-loader.service \
"

# Tars are fetched just prior to build. Consider disabling and commiting checksum after validation
BB_STRICT_CHECKSUM = "0"

do_install() {
    install -d ${D}/usr/share/trustee-containers
    install -m 0644 ${UNPACKDIR}/kbs.archive ${D}/usr/share/trustee-containers/kbs.tar
    install -m 0644 ${UNPACKDIR}/rvps.archive ${D}/usr/share/trustee-containers/rvps.tar
    install -m 0644 ${UNPACKDIR}/attest.archive ${D}/usr/share/trustee-containers/attest.tar

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${UNPACKDIR}/trustee-container-loader.service \
        ${D}${systemd_system_unitdir}/trustee-container-loader.service
}

FILES:${PN} += " /usr/share/trustee-containers ${systemd_system_unitdir}"
RDEPENDS:${PN} = "containerd nerdctl"
