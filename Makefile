APP_PATH = $(HOME)/Applications/TubeKeep.app

.PHONY: build run release clean

default: run

build:
	./build_and_run.sh debug

run:
	./build_and_run.sh debug

release:
	./build_and_run.sh release

clean:
	swift package clean
