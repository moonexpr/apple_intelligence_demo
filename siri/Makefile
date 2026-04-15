PREFIX ?= $(HOME)/.local

.PHONY: build install clean

build:
	swift build -c release

install: build
	mkdir -p $(PREFIX)/bin
	cp .build/release/siri $(PREFIX)/bin/siri
	chmod u+x $(PREFIX)/bin/siri

clean:
	swift package clean
