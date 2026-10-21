#!/usr/bin/env bash
# Bump a solidcraft-bin checkout to upstream's latest stable release and commit it.
# PKGBUILD and .SRCINFO get the same sed (makepkg refuses to run as root, so CI can't regenerate
# .SRCINFO); test-update-bin.sh checks the result against `makepkg --printsrcinfo`.
# Usage: update-bin.sh <dir with PKGBUILD and .SRCINFO>. Needs bash, curl, git and GNU sed.
set -euo pipefail
cd "$1"
repo=https://github.com/tangency-labs/solidcraft

# /releases/latest redirects to the newest non-prerelease tag: no API token, no rate limit.
new=$(curl -fsSLo /dev/null -w '%{url_effective}' "$repo/releases/latest")
new=${new##*/v}
old=$(sed -n 's/^\tpkgver = //p' .SRCINFO)
[[ $new =~ ^[0-9]+(\.[0-9]+)*$ ]] || { echo "unexpected release tag: $new" >&2; exit 1; }
[[ $new != "$old" ]] || { echo "up to date: $old"; exit 0; }
[[ $(printf '%s\n' "$old" "$new" | sort -V | tail -1) == "$new" ]] ||
  { echo "latest release $new is older than $old" >&2; exit 1; }

# Upstream's checksum file saves downloading both ~65 MB tarballs.
sums=$(curl -fsSL "$repo/releases/download/v$new/SHA256SUMS.txt")
args=(-e "s/${old//./\\.}/$new/g" -e 's/^(\s*pkgrel\s*=\s*).*/\11/')
for arch in x86_64 aarch64; do
  sum=$(awk -v f="solidcraft-$new-linux-$arch.tar.gz" '$2 == f { print $1 }' <<<"$sums")
  [[ $sum =~ ^[0-9a-f]{64}$ ]] || { echo "no $arch tarball in v$new SHA256SUMS.txt" >&2; exit 1; }
  args+=(-e "s/^(\s*sha256sums_$arch\s*=\s*\(?'?)[0-9a-f]{64}/\1$sum/")
done
sed -i -E "${args[@]}" PKGBUILD .SRCINFO
git commit -qm "Update to $new" PKGBUILD .SRCINFO
echo "updated $old -> $new"
