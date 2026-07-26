#!/usr/bin/env bash
set -euo pipefail

VNC_DISPLAY="${VNC_DISPLAY:-:1}"
VNC_GEOMETRY="${VNC_GEOMETRY:-1920x1080}"
VNC_DEPTH="${VNC_DEPTH:-24}"
NOVNC_PORT="${NOVNC_PORT:-6080}"

display_num="${VNC_DISPLAY#:}"
vnc_port=$((5900 + display_num))

mkdir -p "$HOME/.vnc"
cat > "$HOME/.vnc/xstartup" <<'XSTARTUP'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
xcompmgr -n >/tmp/xcompmgr.log 2>&1 &
exec openbox-session
XSTARTUP
chmod +x "$HOME/.vnc/xstartup"

vncserver -kill "$VNC_DISPLAY" >/dev/null 2>&1 || true
vncserver "$VNC_DISPLAY" \
    -geometry "$VNC_GEOMETRY" \
    -depth "$VNC_DEPTH" \
    -localhost no \
    -SecurityTypes None \
    --I-KNOW-THIS-IS-INSECURE

exec websockify --web=/usr/share/novnc "$NOVNC_PORT" "localhost:${vnc_port}"
