#!/usr/bin/env bash
# Publish Jellyfin.Plugin.Soup and stage a Jellyfin plugins/ folder for Docker.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTNET="${DOTNET:-$HOME/.dotnet/dotnet}"
if [[ ! -x "$DOTNET" ]]; then
  DOTNET="$(command -v dotnet)"
fi

OUT="${1:-$ROOT/docker/plugin}"
PUBLISH="$ROOT/.publish"

rm -rf "$PUBLISH" "$OUT"
mkdir -p "$PUBLISH" "$OUT"

"$DOTNET" publish "$ROOT/Jellyfin.Plugin.Soup/Jellyfin.Plugin.Soup.csproj" \
  -c Release \
  -o "$PUBLISH" \
  --nologo

# Only ship the plugin + IdentityModel deps Jellyfin does not provide.
cp "$PUBLISH/Jellyfin.Plugin.Soup.dll" "$OUT/"
cp "$PUBLISH"/Microsoft.IdentityModel.*.dll "$OUT/"

# meta.json (from build.yaml) — required for Dashboard → Plugins listing.
cat >"$OUT/meta.json" <<'EOF'
{
  "category": "Authentication",
  "changelog": "Dashboard main-menu Soup Invites; Plugins → Soup Auth for connection/Tailscale settings.",
  "description": "Outbound-only Jellyfin plugin for Soup identity. Admins invite/revoke from Dashboard → Soup Invites; connection settings under Plugins → Soup Auth. Clients exchange Soup JWTs at POST /SoupAuth/Exchange.",
  "guid": "c8a7e6d5-4b3a-2918-07f6-e5d4c3b2a190",
  "name": "Soup Auth",
  "overview": "Soup entitlement mailbox: invite by Google sub and exchange Soup assertions for Jellyfin sessions.",
  "owner": "soup",
  "targetAbi": "10.11.0.0",
  "timestamp": "2026-09-10T00:00:00Z",
  "version": "0.1.0.0"
}
EOF

echo "Staged plugin → $OUT"
ls -la "$OUT"
