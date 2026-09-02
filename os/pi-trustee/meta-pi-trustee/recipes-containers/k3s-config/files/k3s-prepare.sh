#!/bin/sh
set -eu

# Ensure k3s agent images directory exists on the tmpfs mount
mkdir -p /var/lib/rancher/k3s/agent/images

# Link baked airgap image archives into k3s agent images directory for auto-import
if [ -d /usr/share/k3s-images ]; then
    for img in /usr/share/k3s-images/*.tar; do
        [ -f "$img" ] || continue
        ln -sf "$img" /var/lib/rancher/k3s/agent/images/$(basename "$img")
    done
fi

# Ensure trustee data subdirectories exist on the data partition (or fallback directory)
mkdir -p /var/lib/trustee/data/kbs
mkdir -p /var/lib/trustee/data/certs
mkdir -p /var/lib/trustee/data/as
mkdir -p /var/lib/trustee/data/rvps
