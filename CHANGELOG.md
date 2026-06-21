# Changelog

## 2026-06-21

- Added local X11/Wayland socket forwarding configuration for all ROS compose services.
- Persisted graphics environment variables into `/etc/environment` at container startup so SSH sessions can use local GUI forwarding without `ssh -X`.
- Documented the local Linux GUI startup flow, Powerlevel10k-safe `xhost` setup, and SSH usage.
- Optimized the ROS Noetic on Jammy image build by moving optional development packages after the expensive offline ROS installation layer, allowing that layer to remain cached when tool dependencies change.
- Added `bubblewrap` to all ROS development images.
- Replaced full `.codex` directory mounts with explicit mounts for authentication, configuration, skills, and memories, keeping configuration and skills read-only.
