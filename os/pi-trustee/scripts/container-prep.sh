#!/usr/bin/env bash
set -euo pipefail

DEST_DIR="${CONTAINER_ARCHIVE:?Error: CONTAINER_ARCHIVE not set. Exiting.}"
mkdir -p "$DEST_DIR"

if [ ! -d "$DEST_DIR" ]; then
    echo "Failed to create directory. Provided directory: $DEST_DIR"
    exit 1
fi

# macOS/Bash 3.2 compatible standard array using "name|url" format
CONTAINERS=(
    "kbs|ghcr.io/confidential-containers/staged-images/kbs-grpc-as:latest"
    "rvps|ghcr.io/confidential-containers/staged-images/rvps:latest"
    "attest|ghcr.io/confidential-containers/staged-images/coco-as-grpc:latest"
)

echo "Starting container archive process..."
for item in "${CONTAINERS[@]}"; do
    tar_name="${item%%|*}"
    container_url="${item##*|}"
    # Use .archive extension so yocto won't auto-extract as tar
    target_file="$DEST_DIR/${tar_name}.archive"
    
    if [ -f "$target_file" ]; then
        echo "Deleting existing file $target_file..."
        rm "$target_file"
    fi

    echo "Pulling $container_url..."
    # Retry up to 3 times with 5 second wait in case of transient issues
    for i in {1..3}; do
        if skopeo copy --override-arch arm64 --override-os linux "docker://$container_url" "docker-archive:$target_file"; then
            break
        elif [ "$i" -eq 3 ]; then
            echo "Failed to pull $container_url after 3 attempts."
            exit 1
        fi
        echo "Retrying $container_url in 5 seconds..."
        sleep 5
    done
done

echo "Container archive complete."
