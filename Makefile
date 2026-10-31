.PHONY: app run test install clean

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

clean:
	rm -rf .build build
