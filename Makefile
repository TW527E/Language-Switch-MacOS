.PHONY: build test app dmg smoke verify clean run

build:
	swift build

test:
	mkdir -p .build/checks
	swiftc Sources/ShiftInputCore/*.swift Sources/ShiftInput/SettingsStore.swift Scripts/StateMachineChecks.swift -o .build/checks/state-machine-checks
	.build/checks/state-machine-checks

app:
	./Scripts/build-app.sh

dmg:
	./Scripts/create-dmg.sh

smoke: app
	./Scripts/smoke-test-app.sh

verify: test smoke

run: app
	open ./dist/ShiftInput.app

clean:
	swift package clean
	rm -rf dist
