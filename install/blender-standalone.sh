#!/usr/bin/env bash
# Optional per-user official Blender build; no system package transaction.
set -euo pipefail

version=${1:-5.2.2}
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
[[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo 'Expected a Blender version such as 5.2.2' >&2; exit 2; }
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || { echo 'This installer supports Linux x86_64.' >&2; exit 2; }
series=${version%.*}
name="blender-$version-linux-x64"
base="https://download.blender.org/release/Blender$series"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/blender"
root="$HOME/.local/opt/blender"
mkdir -p "$cache" "$root" "$HOME/.local/bin" "$HOME/.local/share/applications"

if [[ ! -x "$root/$name/blender" ]]; then
  curl -fLsS --retry 2 "$base/blender-$version.sha256" -o "$cache/blender-$version.sha256"
  if [[ ! -f "$cache/$name.tar.xz" ]]; then
    curl -fL --retry 2 --continue-at - "$base/$name.tar.xz" -o "$cache/$name.tar.xz.part"
    mv "$cache/$name.tar.xz.part" "$cache/$name.tar.xz"
  fi
  expected=$(awk -v file="$name.tar.xz" '$2 == file || $2 == "*" file {print $1}' "$cache/blender-$version.sha256")
  [[ $expected =~ ^[a-fA-F0-9]{64}$ ]] || { echo 'Missing official SHA-256 checksum' >&2; exit 1; }
  printf '%s  %s\n' "$expected" "$cache/$name.tar.xz" | sha256sum --check -
  staging=$(mktemp -d "$root/.install.XXXXXXXX")
  trap 'rm -rf -- "$staging"' EXIT
  tar -xJf "$cache/$name.tar.xz" -C "$staging"
  "$staging/$name/blender" --version
  mv "$staging/$name" "$root/$name"
fi

if [[ -e "$HOME/.local/bin/blender" && ! -L "$HOME/.local/bin/blender" ]]; then
  echo 'Refusing to replace an existing non-symlink Blender command.' >&2
  exit 1
fi
ln -sfn "$root/$name" "$root/current"
chmod +x "$repo_dir/config/blender/launch.sh"
ln -sfn "$repo_dir/config/blender/launch.sh" "$HOME/.local/bin/blender"
cat > "$HOME/.local/share/applications/blender-standalone.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Blender
GenericName=3D Creation Suite
Comment=Official standalone Blender for Linux
Exec="$HOME/.local/bin/blender" %f
Icon=$root/current/blender.svg
Terminal=false
Categories=Graphics;3DGraphics;
MimeType=application/x-blender;
StartupWMClass=Blender
EOF
if command -v desktop-file-validate >/dev/null; then
  desktop-file-validate "$HOME/.local/share/applications/blender-standalone.desktop"
fi
if command -v update-desktop-database >/dev/null; then
  update-desktop-database "$HOME/.local/share/applications"
fi
echo "Installed Blender $version. Run blender or use the application launcher."
