#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
CHART_DIR="$PROJECT_DIR/meta-pi-trustee/recipes-containers/trustee-helm/files/chart"
OVERRIDES_FILE="$PROJECT_DIR/meta-pi-trustee/recipes-containers/trustee-helm/files/values.yaml"

DEST_DIR="${CONTAINER_ARCHIVE:?Error: CONTAINER_ARCHIVE environment variable not set. Exiting.}"
mkdir -p "$DEST_DIR"

if ! command -v skopeo >/dev/null 2>&1; then
    echo "Error: skopeo is required to archive container images but was not found in PATH."
    exit 1
fi

if ! command -v helm >/dev/null 2>&1; then
    echo "Error: helm CLI is required to package the chart and render manifests."
    exit 1
fi

echo "1. Packaging Trustee Helm chart..."
helm package "$CHART_DIR" --destination "$DEST_DIR"

echo "2. Extracting container images via helm template..."
# Render chart manifests using chart/values.yaml defaults (and optional overrides if present)
HELM_ARGS=("$CHART_DIR")
if [ -s "$OVERRIDES_FILE" ]; then
    HELM_ARGS+=(-f "$OVERRIDES_FILE")
fi

DISCOVERED_IMAGES=$(helm template trustee "${HELM_ARGS[@]}" | grep 'image:' | sed -E 's/.*image:[[:space:]]*//' | tr -d '"'"'" | sort -u)

# Combine with baseline k3s airgap system images required for offline operation
ALL_IMAGES=()
while IFS= read -r img; do
    [ -n "$img" ] && ALL_IMAGES+=("$img")
done <<< "$DISCOVERED_IMAGES"

ALL_IMAGES+=("rancher/mirrored-pause:3.6" "rancher/mirrored-coredns-coredns:1.10.1")

# Deduplicate image list
UNIQUE_IMAGES=($(printf "%s\n" "${ALL_IMAGES[@]}" | sort -u))

echo "Found ${#UNIQUE_IMAGES[@]} images to archive:"
for img in "${UNIQUE_IMAGES[@]}"; do
    echo "  - $img"
done

echo ""
echo "3. Archiving container images for airgap runtime..."
for img in "${UNIQUE_IMAGES[@]}"; do
    # Dynamically sanitize full image name to a safe archive filename (e.g. repo_image_tag.tar)
    archive_name="$(echo "$img" | sed 's#[^a-zA-Z0-9._-]#_#g').tar"
    target_file="$DEST_DIR/$archive_name"

    echo "Pulling $img -> $archive_name..."
    for i in {1..3}; do
        if skopeo copy --override-arch arm64 --override-os linux "docker://$img" "docker-archive:$target_file"; then
            break
        elif [ "$i" -eq 3 ]; then
            echo "Failed to pull $img after 3 attempts."
            exit 1
        fi
        echo "Retrying $img in 5 seconds..."
        sleep 5
    done
done

echo ""
echo "Container archive complete. All artifacts saved to: $DEST_DIR"
