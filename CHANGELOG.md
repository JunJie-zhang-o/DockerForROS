# Changelog

## 2026-06-21

- Added local X11/Wayland socket forwarding configuration for all ROS compose services.
- Persisted graphics environment variables into `/etc/environment` at container startup so SSH sessions can use local GUI forwarding without `ssh -X`.
- Documented the local Linux GUI startup flow, Powerlevel10k-safe `xhost` setup, and SSH usage.
