# trine-bases

Wasm base runtimes for **trine** Worker Images.

Each base runtime (QuickJS, CPython-WASI, future Ruby/Lua/...) is published
as a GitHub Release in this repo. trine pulls the wasm asset on first cold
start, verifies its sha256 against a value pinned in trine's source, and
caches it locally for subsequent runs.

## Release convention

Tags follow `<runtime>-<upstream-version>`, e.g.:

- `quickjs-v0.15.0`
- `python-3.11.4`

Each release ships:

| Asset | Purpose |
| --- | --- |
| `<runtime>.wasm` | The base runtime binary |
| `SHA256SUM` | One line per asset: `<digest>  <filename>` |
| Auxiliary blobs as needed | e.g. `python311.zip` for the CPython stdlib |

Release notes record upstream source (repo + tag), license, and any
repackaging steps applied.

## Consuming a release

Every asset in a release is at a stable GitHub URL:

```
https://github.com/toazoth/trine-bases/releases/download/<tag>/<asset>
```

For QuickJS v0.15.0 specifically:

```
https://github.com/toazoth/trine-bases/releases/download/quickjs-v0.15.0/qjs-wasi.wasm
https://github.com/toazoth/trine-bases/releases/download/quickjs-v0.15.0/SHA256SUM
```

Recommended fetch + verify (works on macOS and Linux):

```sh
TAG=quickjs-v0.15.0
BASE=https://github.com/toazoth/trine-bases/releases/download/${TAG}

mkdir -p cache && cd cache
curl --fail --location --remote-name "${BASE}/qjs-wasi.wasm"
curl --fail --location --remote-name "${BASE}/SHA256SUM"

# macOS: shasum -a 256 -c SHA256SUM
# Linux: sha256sum -c SHA256SUM
shasum -a 256 -c SHA256SUM 2>/dev/null || sha256sum -c SHA256SUM
```

`SHA256SUM` contains one line per asset in the release, formatted
`<digest>  <filename>` — compatible with both `shasum -a 256 -c` and
`sha256sum -c`.

## Publishing a release

Per-runtime recipes live in `recipes/<runtime>.sh`. A recipe takes a
version arg and an output directory, and populates the output with that
runtime's release assets plus a `NOTES.md`.

Cutting a release is one git push:

```
git tag <runtime>-<upstream-version>
git push origin <runtime>-<upstream-version>
```

For example, to release QuickJS v0.15.0:

```
git tag quickjs-v0.15.0
git push origin quickjs-v0.15.0
```

The `release` GitHub Actions workflow runs the matching recipe, generates
`SHA256SUM` over the staged assets, and creates the GitHub Release with
the assets attached and `NOTES.md` as the body. Adding a new runtime =
drop a new executable `recipes/<name>.sh`; the workflow auto-dispatches
by tag prefix.

The workflow also exposes `workflow_dispatch` for re-running a release
against an existing tag if a recipe is fixed up.

## Trust model

trine's source embeds a `(runtime, version, sha256)` tuple for every base
it knows about. The loader refuses to use any downloaded blob whose digest
doesn't match. Publishing a new runtime version is therefore a two-step
change: (1) push a tag here, (2) pin the new digest in trine.

## Why a separate repo

Keeps the trine binary lean (only wasmtime + loader plumbing); every
language runtime lives behind a uniform, content-addressed fetch + cache.
Offline / air-gapped builds can opt in to static embedding via cargo
features on the trine side.
