CACHE_ROOT ?= .docker-cache
PARALLEL_JOBS ?= 4
export CACHE_ROOT

ROS1_IMAGE_TARGETS := build-NoeticOnFocal build-NoeticOnJammy
ROS2_IMAGE_TARGETS := build-HumbleOnJammy build-HumbleOnFocal build-FoxyOnFocal build-JazzyOnNoble

.PHONY: build-NoeticOnFocal build-NoeticOnJammy build-HumbleOnJammy build-HumbleOnFocal build-FoxyOnFocal build-JazzyOnNoble build-focal build-jammy build-humble build-humble-on-focal build-humble-on-foxy build-foxy build-jazzy build-ros1-all build-ros2-all build-all check help

build-NoeticOnFocal:
	./build.sh NoeticOnFocal

build-NoeticOnJammy:
	./build.sh NoeticOnJammy

build-HumbleOnJammy:
	./build.sh HumbleOnJammy

build-HumbleOnFocal:
	./build.sh HumbleOnFocal

build-FoxyOnFocal:
	./build.sh FoxyOnFocal

build-JazzyOnNoble:
	./build.sh JazzyOnNoble


build-ros1-all:
	$(MAKE) -j$(PARALLEL_JOBS) $(ROS1_IMAGE_TARGETS)

build-ros2-all:
	$(MAKE) -j$(PARALLEL_JOBS) $(ROS2_IMAGE_TARGETS)


build-all: build-NoeticOnFocal build-HumbleOnJammy build-HumbleOnFocal build-FoxyOnFocal build-JazzyOnNoble

check:
	bash -n build.sh
	docker compose config -q

help:
	@printf '%s\n' \
		'build-NoeticOnFocal    Build Dockerfile.NoeticOnFocal (ros-noetic-focal)' \
		'build-NoeticOnJammy    Build Dockerfile.NoeticOnJammy (ros-noetic-jammy)' \
		'build-HumbleOnJammy    Build Dockerfile.HumbleOnJammy (ros-humble-jammy)' \
		'build-HumbleOnFocal    Build Dockerfile.HumbleOnFocal from the offline bundle (ros-humble-focal)' \
		'build-FoxyOnFocal      Build Dockerfile.FoxyOnFocal (ros-foxy-focal)' \
		'build-JazzyOnNoble     Build Dockerfile.JazzyOnNoble (ros-jazzy-noble)' \
		'build-ros1-all         Build all ROS1 images in parallel' \
		'build-ros2-all         Build all ROS2 images in parallel' \
		'build-all              Build all images' \
		'check                  Validate build.sh and docker-compose.yml' \
		'PARALLEL_JOBS=<n>      Override parallel jobs for build-ros1-all/build-ros2-all' \
		'CACHE_ROOT=<path>      Override the local BuildKit cache directory'
