.PHONY: build-focal build-jammy build-humble build-humble-on-foxy build-foxy build-all

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
