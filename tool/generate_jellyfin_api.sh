#!/bin/sh
set -eu

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

cd "$repo_root"
npx --yes @openapitools/openapi-generator-cli@2.23.4 generate \
  -i tool/openapi/jellyfin-10.11-prototype.yaml \
  -g dart \
  -o packages/jellyfin_api \
  -c tool/openapi/dart-generator.yaml

# Keep generator documentation stable and free of trailing whitespace.
node --input-type=module <<'JS'
import { readFileSync, writeFileSync, readdirSync } from 'node:fs';
const root = 'packages/jellyfin_api';
for (const path of [`${root}/README.md`, ...readdirSync(`${root}/doc`).map(name => `${root}/doc/${name}`)]) {
  writeFileSync(path, readFileSync(path, 'utf8').replace(/[ \t]+$/gm, '').trimEnd() + '\n');
}
JS

dart format packages/jellyfin_api/lib packages/jellyfin_api/test
cd packages/jellyfin_api
dart pub add --dev 'test:^1.31.0'
