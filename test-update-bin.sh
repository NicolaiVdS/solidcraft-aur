#!/usr/bin/env bash
# Self-check for update-bin.sh: fake an old solidcraft-bin, update it, and require the sed-patched
# .SRCINFO to match what makepkg generates. Needs network and makepkg.
set -euo pipefail
here=$(dirname "$(realpath "$0")")
t=$(mktemp -d)
trap 'rm -rf "$t"' EXIT
cd "$t"
sed -E -e 's/^pkgver=.*/pkgver=0.0.1/' -e 's/^pkgrel=.*/pkgrel=3/' \
  -e "s/^(sha256sums_x86_64=\(')[0-9a-f]{64}/\1$(printf '%064d' 1)/" \
  -e "s/^(sha256sums_aarch64=\(')[0-9a-f]{64}/\1$(printf '%064d' 2)/" \
  "$here/solidcraft-bin/PKGBUILD" > PKGBUILD
makepkg --printsrcinfo > .SRCINFO
git init -q && git config user.name test && git config user.email test@localhost
git add . && git commit -qm init

"$here/update-bin.sh" .
makepkg --printsrcinfo | diff -u - .SRCINFO
ver=$(sed -n 's/^pkgver=//p' PKGBUILD)
grep -q '^pkgrel=1$' PKGBUILD
! grep -qE '0{63}[12]' PKGBUILD
[[ $(git log -1 --format=%s) == "Update to $ver" ]]
"$here/update-bin.sh" . | grep -q "up to date: $ver"
echo "ok: 0.0.1-3 -> $ver-1"
