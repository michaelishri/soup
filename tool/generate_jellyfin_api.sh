#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

cd "$repo_root"
npx --yes @openapitools/openapi-generator-cli@2.23.4 generate \
  -i tool/openapi/jellyfin-10.11-prototype.yaml \
  -g dart \
  -o packages/jellyfin_api \
  --additional-properties=pubName=jellyfin_api,pubVersion=0.1.0,serializationLibrary=json_serializable

dart format packages/jellyfin_api/lib packages/jellyfin_api/test
cd packages/jellyfin_api
dart pub add --dev 'test:^1.31.0'
