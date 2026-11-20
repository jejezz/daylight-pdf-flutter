#!/usr/bin/env bash
# Download the pinned rhwp converter for one platform into third_party/rhwp/<platform>/.
#
#   tool/fetch_rhwp.sh <windows-x64|macos-universal|linux-x64> [asset-dir]
#
# Version, release location and the expected SHA-256 come from third_party/rhwp/rhwp.lock. The archive is
# verified BEFORE it is unpacked; an empty or different hash stops the build. With [asset-dir] the archive is
# taken from that folder instead of being downloaded (used to test this script without a release).
# Needs `gh` (GH_TOKEN in CI) for downloads, and `tar`.
set -euo pipefail

platform="${1:?usage: fetch_rhwp.sh <windows-x64|macos-universal|linux-x64> [asset-dir]}"
asset_dir="${2:-}"
case "$platform" in
  windows-x64) exe=rhwp.exe ;;
  macos-universal | linux-x64) exe=rhwp ;;
  *) echo "unknown platform: $platform" >&2; exit 2 ;;
esac

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# tr: the lock may have CRLF line endings on Windows checkouts.
# shellcheck disable=SC1090
source <(tr -d '\r' < "$root/third_party/rhwp/rhwp.lock")

key="RHWP_SHA256_$(printf '%s' "$platform" | tr 'a-z-' 'A-Z_')"
expected="${!key:-}"
if [ -z "$expected" ]; then
  echo "::error::$key is empty in third_party/rhwp/rhwp.lock — run the \"Build rhwp\" workflow and paste the hashes from its summary" >&2
  exit 1
fi

tag="rhwp-v${RHWP_VERSION}-b${RHWP_BUILD}"
asset="rhwp-${RHWP_VERSION}-b${RHWP_BUILD}-${platform}.tar.gz"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

if [ -n "$asset_dir" ]; then
  cp "$asset_dir/$asset" "$tmp/$asset"
else
  gh release download "$tag" --repo "$RHWP_REPO" --pattern "$asset" --dir "$tmp"
fi

if command -v sha256sum > /dev/null 2>&1; then
  actual="$(sha256sum "$tmp/$asset" | cut -d' ' -f1)"
else
  actual="$(shasum -a 256 "$tmp/$asset" | cut -d' ' -f1)"
fi
if [ "$actual" != "$expected" ]; then
  echo "::error::$asset SHA-256 mismatch: expected $expected, got $actual" >&2
  exit 1
fi

dest="$root/third_party/rhwp/$platform"
rm -rf "$dest"
mkdir -p "$dest"
tar -xzf "$tmp/$asset" -C "$dest"
test -f "$dest/$exe" || { echo "::error::$asset does not contain $exe" >&2; exit 1; }
chmod +x "$dest/$exe"
echo "rhwp $RHWP_VERSION (build $RHWP_BUILD) → third_party/rhwp/$platform/ ($actual)"
