#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

WORKSPACE_IMG="$HOME/yocto-workspace.sparsebundle"
CACHE_IMG="$HOME/yocto-cache.sparsebundle"

WORKSPACE_VOL="/Volumes/yocto-workspace"
CACHE_VOL="/Volumes/yocto-cache"

WORKSPACE_SIZE="150g"
CACHE_SIZE="200g"

create_and_mount() {
  local img="$1" vol="$2" size="$3" label="$4"

  if mount | grep -q "$vol"; then
    echo "$label already mounted at $vol"
    return
  fi

  if [ ! -d "$img" ]; then
    echo "Creating $label sparse bundle ($size) at $img..."
    hdiutil create -size "$size" -fs "Case-sensitive APFS" \
      -volname "$(basename "$vol")" -type SPARSEBUNDLE "$img"
  fi

  echo "Mounting $label..."
  hdiutil attach "$img" -mountpoint "$vol" -nobrowse -quiet
  echo "$label mounted at $vol"
}

create_and_mount "$WORKSPACE_IMG" "$WORKSPACE_VOL" "$WORKSPACE_SIZE" "Workspace"
create_and_mount "$CACHE_IMG"     "$CACHE_VOL"     "$CACHE_SIZE"     "Cache"

mkdir -p "$WORKSPACE_VOL/meta-pi-trustee"
mkdir -p "$CACHE_VOL/downloads"
mkdir -p "$CACHE_VOL/sstate"

echo ""
echo "Setup complete."
