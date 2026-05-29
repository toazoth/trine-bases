#!/usr/bin/env bash
# Stage release assets for a python-<version> tag.
#
# CPython-WASI is multi-asset: the wasm binary does NOT embed the stdlib, so we
# republish both the binary and the stdlib zip. Upstream is VMware Labs'
# webassembly-language-runtimes build, repackaged verbatim under uniform names.
#
# Args:
#   $1  version (e.g. 3.11.4) — must match a known upstream build below
#   $2  output directory to populate with release assets
#
# Produces:
#   <out>/python.wasm      the wasi build of CPython
#   <out>/python311.zip    the CPython standard library (maps to
#                          /usr/local/lib/python311.zip in the guest)
#   <out>/NOTES.md         release notes (consumed by the workflow as
#                          --notes-file; not uploaded as a release asset)

set -euo pipefail

VERSION="${1:?usage: python.sh <version> <out-dir>}"
OUT="${2:?usage: python.sh <version> <out-dir>}"

# Map a trine version to the exact upstream VMware WLR release + expected
# digests. Pinning digests here guarantees the bytes we republish are exactly
# the ones trine's source pins; an upstream change fails loudly instead of
# silently shipping different bytes.
case "${VERSION}" in
  3.11.4)
    WLR_TAG="python/3.11.4+20230714-11be424"
    WLR_TARBALL="python-3.11.4-wasi-sdk-20.0.tar.gz"
    WASM_MEMBER="bin/python-3.11.4.wasm"
    ZIP_MEMBER="usr/local/lib/python311.zip"
    WASM_SHA256="d464c4fc136a738a2afb5d21a76dbe5085b50bdf8d2bda45b47c64cc99f57ea3"
    ZIP_SHA256="d47df521a222a10587646c5fd6c859933a3e8d6c2d6a090dec45c08534b5e8a2"
    ;;
  *)
    echo "python.sh: unsupported version '${VERSION}'" >&2
    echo "  add a case mapping it to an upstream VMware WLR build + digests" >&2
    exit 1
    ;;
esac

# URL-encode the upstream tag path (/ -> %2F, + -> %2B).
WLR_TAG_ENC="${WLR_TAG//\//%2F}"
WLR_TAG_ENC="${WLR_TAG_ENC//+/%2B}"
URL="https://github.com/vmware-labs/webassembly-language-runtimes/releases/download/${WLR_TAG_ENC}/${WLR_TARBALL}"

# sha256 of a file, portable across macOS (shasum) and Linux (sha256sum).
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

verify() {
  local file="$1" expected="$2" actual
  actual="$(sha256_of "${file}")"
  if [ "${actual}" != "${expected}" ]; then
    echo "python.sh: digest mismatch for ${file}" >&2
    echo "  expected ${expected}" >&2
    echo "  actual   ${actual}" >&2
    exit 1
  fi
}

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

echo "fetching ${URL}" >&2
curl --fail --location --silent --show-error \
  --output "${WORK}/bundle.tar.gz" "${URL}"

tar -xzf "${WORK}/bundle.tar.gz" -C "${WORK}" "${WASM_MEMBER}" "${ZIP_MEMBER}"

cp "${WORK}/${WASM_MEMBER}" "${OUT}/python.wasm"
cp "${WORK}/${ZIP_MEMBER}" "${OUT}/python311.zip"

verify "${OUT}/python.wasm" "${WASM_SHA256}"
verify "${OUT}/python311.zip" "${ZIP_SHA256}"

cat > "${OUT}/NOTES.md" <<EOF
Upstream: [vmware-labs/webassembly-language-runtimes ${WLR_TAG}](https://github.com/vmware-labs/webassembly-language-runtimes/releases/tag/${WLR_TAG})
License: PSF (CPython); see upstream release for full license set
Assets:
- \`python.wasm\` — CPython ${VERSION} WASI build (stdlib NOT embedded)
- \`python311.zip\` — CPython standard library; map at \`/usr/local/lib/python311.zip\`

Repackaged verbatim from upstream (renamed only) so all trine base runtimes
share a uniform fetch path. The default guest \`sys.path\` already includes
\`/usr/local/lib/python311.zip\`. See the repo README for the consumption
pattern.
EOF
