# Changelog

## 2026-06-21

- Added VirtualGL + TurboVNC support for remote high-performance 3D GUI workflows.
- Added noVNC and websockify support for browser-based access to the TurboVNC desktop, listening on all interfaces by default.
- Added `start-vnc` to launch a localhost-only TurboVNC desktop for SSH-tunneled access.
- Defaulted VirtualGL to the EGL backend to avoid requiring a container-visible physical `:0` display.
- Clarified that `vglrun -d egl` is the required piece for GPU-accelerated RViz/Gazebo; TurboVNC, TightVNC, and noVNC mainly affect transport and client experience.
- Changed `start-vnc` to pick a free display starting at `:10` to avoid conflicts with mounted host X11 sockets.
- Forced the VNC session startup environment to use its own `DISPLAY` so GUI windows do not open on the host monitor.
- Added local X11/Wayland socket forwarding configuration for all ROS compose services.
- Persisted graphics environment variables into `/etc/environment` at container startup so SSH sessions can use local GUI forwarding without `ssh -X`.
- Documented the local Linux GUI startup flow, Powerlevel10k-safe `xhost` setup, and SSH usage.
