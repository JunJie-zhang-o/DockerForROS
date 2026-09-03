CACHE_ROOT ?= .docker-cache
export CACHE_ROOT

.PHONY: build-focal build-jammy build-humble build-humble-on-focal build-humble-on-foxy build-foxy build-all check help

build-focal:
	./build.sh focal

build-jammy:
	./build.sh jammy

build-humble:
	./build.sh humble

build-humble-on-focal:
	./build.sh HumbleOnFocal

build-humble-on-foxy: build-humble-on-focal

build-foxy:
	./build.sh foxy

build-all: build-focal build-jammy build-humble build-humble-on-focal build-foxy

check:
	bash -n build.sh
	docker compose config -q

help:
	@printf '%s\n' \
		'build-focal            Build Noetic on Focal (ros-noetic-focal)' \
		'build-jammy            Build Noetic on Jammy (ros-noetic-jammy)' \
		'build-humble           Build Humble on Jammy (ros-humble-jammy)' \
		'build-humble-on-focal  Build Humble on Focal from the offline bundle (ros-humble-focal)' \
		'build-humble-on-foxy   Alias for build-humble-on-focal' \
		'build-foxy             Build Foxy on Focal (ros-foxy-focal)' \
		'build-all              Build all images' \
		'check                  Validate build.sh and docker-compose.yml' \
		'CACHE_ROOT=<path>      Override the local BuildKit cache directory'
