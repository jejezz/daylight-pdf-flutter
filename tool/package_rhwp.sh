#!/usr/bin/env bash
# Pack a built rhwp into the archive tool/fetch_rhwp.sh expects.
#
#   tool/package_rhwp.sh <platform> <binary> <license-dir> <out-dir> <rhwp-version> <build>
#
# Result: <out-dir>/rhwp-<version>-b<build>-<platform>.tar.gz containing, flat: rhwp(.exe), LICENSE,
# THIRD_PARTY_LICENSES.md. Prints the archive's SHA-256 (what goes into third_party/rhwp/rhwp.lock).
set -euo pipefail

platform="${1:?platform}" binary="${2:?binary}" licenses="${3:?license-dir}"
outdir="${4:?out-dir}" version="${5:?rhwp-version}" build="${6:?build}"
case "$platform" in
  windows-x64) exe=rhwp.exe ;;
  macos-universal | linux-x64) exe=rhwp ;;
  *) echo "unknown platform: $platform" >&2; exit 2 ;;
esac

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
cp "$binary" "$stage/$exe"
chmod +x "$stage/$exe"
cp "$licenses/LICENSE" "$licenses/THIRD_PARTY_LICENSES.md" "$stage/"

mkdir -p "$outdir"
asset="rhwp-${version}-b${build}-${platform}.tar.gz"
tar -czf "$outdir/$asset" -C "$stage" "$exe" LICENSE THIRD_PARTY_LICENSES.md

if command -v sha256sum > /dev/null 2>&1; then
  hash="$(sha256sum "$outdir/$asset" | cut -d' ' -f1)"
else
  hash="$(shasum -a 256 "$outdir/$asset" | cut -d' ' -f1)"
fi
echo "$hash  $asset"
