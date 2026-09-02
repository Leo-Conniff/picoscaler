SUMMARY = "Trustee Helm chart and boot-time deployment service"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit systemd

SRC_URI = " \
    file://chart \
    file://values.yaml \
    file://trustee-helm-deploy.sh \
    file://trustee-helm-deploy.service \
"

S = "${UNPACKDIR}"

SYSTEMD_SERVICE:${PN} = "trustee-helm-deploy.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

do_install() {
    install -d ${D}${datadir}/trustee-helm
    cp -R ${S}/chart ${D}${datadir}/trustee-helm/
    install -m 0644 ${S}/values.yaml ${D}${datadir}/trustee-helm/values.yaml

    install -d ${D}${bindir}
    install -m 0755 ${S}/trustee-helm-deploy.sh ${D}${bindir}/trustee-helm-deploy.sh

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${S}/trustee-helm-deploy.service ${D}${systemd_system_unitdir}/trustee-helm-deploy.service
}

FILES:${PN} += " \
    ${datadir}/trustee-helm \
    ${bindir}/trustee-helm-deploy.sh \
    ${systemd_system_unitdir}/trustee-helm-deploy.service \
"
RDEPENDS:${PN} += "k3s helm"
