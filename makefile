CACHE_ROOT ?= .docker-cache
export CACHE_ROOT

.PHONY: build-NoeticOnFocal build-NoeticOnJammy build-HumbleOnJammy build-HumbleOnFocal build-FoxyOnFocal build-JazzyOnNoble build-focal build-jammy build-humble build-humble-on-focal build-humble-on-foxy build-foxy build-jazzy build-all check help

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

build-focal: build-NoeticOnFocal

build-jammy: build-NoeticOnJammy

build-humble: build-HumbleOnJammy

build-humble-on-focal: build-HumbleOnFocal

build-humble-on-foxy: build-HumbleOnFocal

build-foxy: build-FoxyOnFocal

build-jazzy: build-JazzyOnNoble

build-all: build-NoeticOnFocal build-NoeticOnJammy build-HumbleOnJammy build-HumbleOnFocal build-FoxyOnFocal build-JazzyOnNoble

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
		'build-focal            Alias for build-NoeticOnFocal' \
		'build-jammy            Alias for build-NoeticOnJammy' \
		'build-humble           Alias for build-HumbleOnJammy' \
		'build-humble-on-focal  Alias for build-HumbleOnFocal' \
		'build-humble-on-foxy   Alias for build-HumbleOnFocal' \
		'build-foxy             Alias for build-FoxyOnFocal' \
		'build-jazzy            Alias for build-JazzyOnNoble' \
		'build-all              Build all images' \
		'check                  Validate build.sh and docker-compose.yml' \
		'CACHE_ROOT=<path>      Override the local BuildKit cache directory'
