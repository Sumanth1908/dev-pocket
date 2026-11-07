.PHONY: app run test install icon clean

ICON_STYLE ?= classic

app:
	./scripts/bundle.sh

run: app
	-pkill -x DevPocket
	open build/DevPocket.app

test:
	swift test

install: app
	-pkill -x DevPocket
	rm -rf /Applications/DevPocket.app
	cp -R build/DevPocket.app /Applications/
	open /Applications/DevPocket.app

# Regenerate Support/AppIcon.icns, e.g. `make icon ICON_STYLE=midnight`.
# Styles: swift scripts/make-icon.swift --list
icon:
	swift scripts/make-icon.swift --style $(ICON_STYLE) Support/AppIcon.icns

clean:
	rm -rf .build build
