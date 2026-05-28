#!/usr/bin/env bash
# Stage release assets for a quickjs-<version> tag.
#
# Args:
#   $1  upstream version tag (e.g. v0.15.0)
#   $2  output directory to populate with release assets
#
# Produces:
#   <out>/qjs-wasi.wasm   the wasi build of quickjs-ng
#   <out>/NOTES.md        release notes (consumed by the workflow as
#                         --notes-file; not uploaded as a release asset)

set -euo pipefail

VERSION="${1:?usage: quickjs.sh <upstream-version> <out-dir>}"
OUT="${2:?usage: quickjs.sh <upstream-version> <out-dir>}"

URL="https://github.com/quickjs-ng/quickjs/releases/download/${VERSION}/qjs-wasi.wasm"

echo "fetching ${URL}" >&2
curl --fail --location --silent --show-error \
  --output "${OUT}/qjs-wasi.wasm" "${URL}"

cat > "${OUT}/NOTES.md" <<EOF
Upstream: [quickjs-ng/quickjs ${VERSION}](https://github.com/quickjs-ng/quickjs/releases/tag/${VERSION})
License: MIT
Asset: \`qjs-wasi.wasm\`

Re-published verbatim from upstream so all trine base runtimes share a
uniform fetch path. See the repo README for the consumption pattern.
EOF
