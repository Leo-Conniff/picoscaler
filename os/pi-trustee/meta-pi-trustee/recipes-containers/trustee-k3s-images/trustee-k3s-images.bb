SUMMARY = "Trustee airgap container images for k3s"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

S = "${UNPACKDIR}"

do_install() {
    install -d ${D}${datadir}/k3s-images
    if [ -d "${CONTAINER_TARS}" ]; then
        for archive in ${CONTAINER_TARS}/*.tar ${CONTAINER_TARS}/*.archive; do
            [ -e "$archive" ] || continue
            base=$(basename "$archive")
            base="${base%.archive}.tar"
            install -m 0644 "$archive" "${D}${datadir}/k3s-images/${base}"
        done
    fi
}

do_install[vardeps] += "CONTAINER_TARS"
FILES:${PN} += "${datadir}/k3s-images"
