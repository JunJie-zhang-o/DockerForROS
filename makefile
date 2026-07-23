CACHE_ROOT ?= .docker-cache
export CACHE_ROOT

.PHONY: build-focal build-jammy build-humble build-humble-on-foxy build-foxy build-all check help

build-focal:
	./build.sh focal

build-jammy:
	./build.sh jammy

build-humble:
	./build.sh humble

build-humble-on-foxy:
	./build.sh HumbleOnFoxy

build-foxy:
	./build.sh foxy

build-all: build-focal build-jammy build-humble build-humble-on-foxy build-foxy

check:
	bash -n build.sh
	docker compose config -q

help:
	@printf '%s\n' \
		'build-focal            Build Noetic on Focal (cros20)' \
		'build-jammy            Build Noetic on Jammy (cros22)' \
		'build-humble           Build Humble on Jammy (cros22-humble)' \
		'build-humble-on-foxy   Build Humble from source on Focal (cros20-humble)' \
		'build-foxy             Build Foxy on Focal (cros20-foxy)' \
		'build-all              Build all images' \
		'check                  Validate build.sh and docker-compose.yml' \
		'CACHE_ROOT=<path>      Override the local BuildKit cache directory'
