#!/bin/bash

set -e

DEB_DIR=/tmp/debs
YAML_CPP_VERSION=0.6.2-4ubuntu1
LUA_VERSION=5.3.3-1.1ubuntu2

mkdir -p "$DEB_DIR"
cd "$DEB_DIR"

curl -fsSLO "https://archive.ubuntu.com/ubuntu/pool/main/y/yaml-cpp/libyaml-cpp0.6_${YAML_CPP_VERSION}_amd64.deb"
curl -fsSLO "https://archive.ubuntu.com/ubuntu/pool/main/y/yaml-cpp/libyaml-cpp-dev_${YAML_CPP_VERSION}_amd64.deb"
curl -fsSLO "https://archive.ubuntu.com/ubuntu/pool/main/l/lua5.3/liblua5.3-0_${LUA_VERSION}_amd64.deb"
curl -fsSLO "https://archive.ubuntu.com/ubuntu/pool/main/l/lua5.3/liblua5.3-dev_${LUA_VERSION}_amd64.deb"

apt-get update
apt-get install -y --allow-downgrades "$DEB_DIR"/*.deb
apt-get install -y \
    novnc \
    websockify \
    x11vnc \
    xvfb \
    openbox \
    dbus-x11

check_version() {
    local package=$1
    local expected=$2
    local actual

    actual=$(dpkg-query -W -f='${Version}' "$package")
    if [ "$actual" != "$expected" ]; then
        echo "$package version mismatch: expected $expected, got $actual" >&2
        exit 1
    fi
}

check_version libyaml-cpp0.6 "$YAML_CPP_VERSION"
check_version libyaml-cpp-dev "$YAML_CPP_VERSION"
check_version liblua5.3-0 "$LUA_VERSION"
check_version liblua5.3-dev "$LUA_VERSION"

apt-get clean
rm -rf /var/lib/apt/lists/* "$DEB_DIR"
