#!/usr/bin/env bash
# Refresh the baked Soup Auth plugin into the writable data dir, then start Jellyfin.
set -euo pipefail

SRC="/opt/soup/plugins/SoupAuth"
DEST="${JELLYFIN_DATA_DIR:-/config}/plugins/Soup Auth"

mkdir -p "$(dirname "$DEST")"
rm -rf "$DEST"
cp -a "$SRC" "$DEST"

exec /jellyfin/jellyfin "$@"
