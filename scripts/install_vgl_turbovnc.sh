#!/usr/bin/env bash
set -euo pipefail

VIRTUALGL_VERSION="${VIRTUALGL_VERSION:-3.1}"
TURBOVNC_VERSION="${TURBOVNC_VERSION:-3.1}"
ARCH="${VGL_TVNC_ARCH:-amd64}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

virtualgl_deb="$tmp_dir/virtualgl.deb"
turbovnc_deb="$tmp_dir/turbovnc.deb"

curl -fL --retry 3 \
    "https://sourceforge.net/projects/virtualgl/files/${VIRTUALGL_VERSION}/virtualgl_${VIRTUALGL_VERSION}_${ARCH}.deb/download" \
    -o "$virtualgl_deb"

curl -fL --retry 3 \
    "https://sourceforge.net/projects/turbovnc/files/${TURBOVNC_VERSION}/turbovnc_${TURBOVNC_VERSION}_${ARCH}.deb/download" \
    -o "$turbovnc_deb"

apt-get update
apt-get install -y \
    dbus-x11 \
    libegl1 \
    libgl1 \
    libglu1-mesa \
    mesa-utils \
    novnc \
    openbox \
    websockify \
    xterm
apt-get install -y "$virtualgl_deb" "$turbovnc_deb"
apt-get clean
rm -rf /var/lib/apt/lists/*
