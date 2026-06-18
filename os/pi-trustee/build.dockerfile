FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

# Yocto host dependencies for whinlatter
# https://docs.yoctoproject.org/5.3/ref-manual/system-requirements.html
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential chrpath cpio debianutils diffstat file gawk gcc \
    git iputils-ping libacl1 libcrypt-dev locales \
    python3 python3-git python3-jinja2 python3-pexpect python3-pip \
    python3-subunit socat texinfo unzip wget xz-utils zstd \
    curl ca-certificates

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# Install kas with a known version
ARG KAS_VERSION=4.4
RUN pip3 install --no-cache-dir kas==${KAS_VERSION}

# Bitbake must be run as non-root user
RUN groupadd -r bitbakegroup \
    && useradd -r -g bitbakegroup -m bitbake
RUN mkdir -p /workspace /cache/containers /cache/downloads /cache/sstate /cache/tmp\
    && chown -R bitbake:bitbakegroup /workspace /cache

USER bitbake

# Cache volumes for both idempotency and saving downloads between builds
VOLUME ["/cache/downloads", "/cache/sstate", "/cache/containers"]

WORKDIR /workspace

# Bitbake env variables for building the image
ENV MACHINE=raspberrypi5 \
    DL_DIR=/cache/downloads \
    SSTATE_DIR=/cache/sstate \
    CONTAINER_ARCHIVE=/cache/containers \
    TMPDIR=/cache/tmp \
    BB_ENV_PASSTHROUGH_ADDITIONS="MACHINE DL_DIR SSTATE_DIR KAS_BUILD_DIR DISTRO"

ENV BB_HASHSERVE_DB_DIR=${SSTATE_DIR}

ENTRYPOINT ["kas"]
CMD ["build", "kas-pi-trustee.yml"]
