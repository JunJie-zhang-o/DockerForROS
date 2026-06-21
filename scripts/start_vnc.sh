#!/usr/bin/env bash
set -euo pipefail

if [[ -n "${VNC_DISPLAY:-}" ]]; then
    display="$VNC_DISPLAY"
else
    display=""
    for candidate in $(seq 10 29); do
        if [[ ! -e "/tmp/.X11-unix/X${candidate}" ]]; then
            display="$candidate"
            break
        fi
    done
    if [[ -z "$display" ]]; then
        echo "No free VNC display found in :10-:29. Set VNC_DISPLAY manually." >&2
        exit 1
    fi
fi
geometry="${VNC_GEOMETRY:-1920x1080}"
depth="${VNC_DEPTH:-24}"
password="${VNC_PASSWORD:-1234}"
vgl_display="${VGL_DISPLAY:-egl}"
novnc_port="${NOVNC_PORT:-6080}"
novnc_host="${NOVNC_HOST:-0.0.0.0}"
start_novnc="${START_NOVNC:-1}"
vncserver="/opt/TurboVNC/bin/vncserver"
vncpasswd="/opt/TurboVNC/bin/vncpasswd"
websockify="$(command -v websockify || true)"
novnc_dir="/usr/share/novnc"

if [[ ! -x "$vncserver" ]]; then
    echo "TurboVNC is not installed at $vncserver" >&2
    exit 1
fi

mkdir -p "$HOME/.vnc"
chmod 700 "$HOME/.vnc"

if [[ ! -f "$HOME/.vnc/passwd" ]]; then
    printf '%s\n' "$password" | "$vncpasswd" -f > "$HOME/.vnc/passwd"
    chmod 600 "$HOME/.vnc/passwd"
fi

cat > "$HOME/.vnc/xstartup.turbovnc" <<EOF
#!/usr/bin/env bash
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
export DISPLAY=":${display}"
export VGL_DISPLAY="${vgl_display}"
export QT_X11_NO_MITSHM=1
xsetroot -solid "#202020"
openbox-session &
xterm -geometry 120x36+40+40 &
wait
EOF
chmod +x "$HOME/.vnc/xstartup.turbovnc"

"$vncserver" ":${display}" \
    -geometry "$geometry" \
    -depth "$depth" \
    -localhost \
    -xstartup "$HOME/.vnc/xstartup.turbovnc"

port=$((5900 + display))

if [[ "$start_novnc" == "1" ]]; then
    if [[ -z "$websockify" || ! -d "$novnc_dir" ]]; then
        echo "noVNC/websockify is not installed; skipping browser proxy." >&2
    elif ! pgrep -f "websockify .*${novnc_host}:${novnc_port} .*127.0.0.1:${port}" >/dev/null 2>&1; then
        nohup "$websockify" --web "$novnc_dir" "${novnc_host}:${novnc_port}" "127.0.0.1:${port}" \
            > "$HOME/.vnc/novnc-${novnc_port}.log" 2>&1 &
    fi
fi

cat <<EOF
TurboVNC is running on display :${display}.

From your local machine, create an SSH tunnel:
  ssh -L ${port}:127.0.0.1:${port} ros@REMOTE_HOST -p 10022

Then connect your VNC Viewer to:
  localhost:${port}

For noVNC in a browser, create an SSH tunnel:
  ssh -L ${novnc_port}:127.0.0.1:${novnc_port} ros@REMOTE_HOST -p 10022

Or open it directly if the remote firewall allows port ${novnc_port}:
  http://REMOTE_HOST:${novnc_port}/vnc.html

For SSH tunnel access, open:
  http://localhost:${novnc_port}/vnc.html

Run OpenGL programs inside the VNC desktop with:
  export DISPLAY=:${display}
  vglrun -d ${vgl_display} rviz
  vglrun -d ${vgl_display} gazebo
EOF
