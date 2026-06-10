FROM ubuntu:22.04

ARG DEBIAN_FRONTEND=noninteractive

# Yocto host dependencies for whinlatter
# https://docs.yoctoproject.org/5.3/ref-manual/system-requirements.html

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential chrpath cpio debianutils diffstat file gawk gcc \
    git iputils-ping libacl1 locales python3 python3-git python3-jinja2 \
    python3-pexpect python3-pip python3-subunit socat texinfo \
    unzip wget xz-utils zstd \
    curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# Install kas with a known version
ARG KAS_VERSION=4.4
RUN pip3 install --no-cache-dir kas==${KAS_VERSION}

# Create non-root user for bit bake
ARG BUILD_UID=1000
ARG BUILD_GID=1000
RUN groupadd -g ${BUILD_GID} bitbake \
    && useradd -m -u ${BUILD_UID} -g bitbake -s /bin/bash bitbake \
    && mkdir -p /workspace /cache/downloads /cache/sstate \
    && chown -R bitbake:bitbake /workspace /cache

USER bitbake

# Cache volumes for both idempotency and saving downloads between builds
VOLUME ["/cache/downloads", "/cache/sstate"]

WORKDIR /workspace

# Bitbake env variables for building the image
ENV MACHINE=raspberrypi5 \
    DL_DIR=/cache/downloads \
    SSTATE_DIR=/cache/sstate \
    BB_ENV_PASSTHROUGH_ADDITIONS="MACHINE DL_DIR SSTATE_DIR KAS_BUILD_DIR DISTRO"

ENTRYPOINT ["kas"]
# TODO: update with build command
CMD ["--help"]
