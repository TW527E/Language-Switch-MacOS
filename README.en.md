[繁體中文](README.md) | [简体中文](README.zh-CN.md) | [English](README.en.md)

# ShiftInput

ShiftInput is a lightweight, event-driven, native macOS enhancement for switching input sources. It runs in the background, appears in the menu bar by default, and stays out of the Dock by default.

## Features

### Shift input-source toggle

- Tap `Shift` by itself to switch from the current input source to the most recently used English input source.
- When English is active, tap `Shift` again to restore the previously used input source.
- A macOS-style input-source HUD appears after switching.
- Typing uppercase letters, modifier shortcuts, Shift-clicking, and Shift-scrolling do not trigger a switch.

### Shift + Space Pinyin width toggle

- Press `Shift + Space` in an Apple Pinyin input source to toggle the system full-width/half-width punctuation mode.
- No HUD is displayed.
- Apple Pinyin – Traditional and Pinyin – Simplified are supported.
- **Apple Zhuyin is deliberately excluded.** In Zhuyin and all other input sources, `Shift + Space` passes through unchanged.

The two shortcuts can be enabled or disabled independently in Settings.

## Other settings

- Show the menu bar icon; enabled by default.
- Show the Dock icon; disabled by default.
- If both icons are hidden, open ShiftInput again from Finder to return to Settings.

## Requirements and permissions

- macOS 13 or later.
- System Settings → Privacy & Security → Accessibility.
- System Settings → Privacy & Security → Input Monitoring.

The first launch displays Settings and the current permission state. Rebuilding an ad-hoc-signed app may cause macOS to request permission again.

## Local builds

The Apple Swift toolchain is required. You can also open `Package.swift` directly in Xcode.

```bash
# Pure-Swift state-machine and input-source classification checks
make test

# Create dist/ShiftInput.app
make app

# Create dist/ShiftInput-0.2.0.dmg
make dmg
```

Build a Universal Binary for both Apple Silicon and Intel:

```bash
BUILD_ARCHS="arm64 x86_64" VERSION=0.2.0 make dmg
```

Other supported build parameters:

```bash
VERSION=0.2.0 BUILD_NUMBER=2 CONFIGURATION=release make app
```

Run all local verification:

```bash
make verify
```

## Installing the DMG

1. Open `dist/ShiftInput-<version>.dmg`.
2. Drag `ShiftInput.app` to the `Applications` shortcut in the disk image.
3. Start ShiftInput from Applications.
4. Grant both keyboard permissions shown in Settings.

## GitHub Actions

`.github/workflows/build-dmg.yml` runs for:

- Pushes to `main`.
- Pull requests.
- Manual workflow dispatches.

The workflow runs checks, builds an `arm64 + x86_64` Universal Binary, packages and verifies a DMG, and uploads it as a GitHub Actions artifact.

To publish a new version, change the semantic version in the root `VERSION` file (for example, `0.3.0`), commit it, and push it to `main`. After a successful build, the workflow automatically creates the matching `v0.3.0` tag and GitHub Release, attaches the DMG, and lists every commit since the previous version in the release notes. Existing version tags are never overwritten.

## Technical design

- Swift, AppKit, Core Graphics, and Text Input Source Services.
- `CGEventTap` processes only the required keyboard and pointer events.
- System input-source notifications replace continuous polling.
- `TISSelectInputSource` performs input-source changes and the previous source is persisted.
- `Shift + Space` is forwarded as Apple's native `Option + Shift + H` command only when Apple Pinyin is detected.
- A timed-out event tap recovers automatically; monitoring stops if permissions are revoked.

## Project layout

```text
.github/workflows/build-dmg.yml  GitHub Actions DMG build
VERSION                          Application and Release version
Sources/ShiftInputCore/          Testable pure-Swift logic
Sources/ShiftInput/              AppKit application and system integration
Resources/AppIcon.png            1024px application icon master
Scripts/build-app.sh             .app build script
Scripts/generate-app-icon.sh     ICNS iconset generation script
Scripts/create-dmg.sh            DMG packaging script
Scripts/smoke-test-app.sh        App lifecycle and menu-bar check
Scripts/StateMachineChecks.swift State-machine and Pinyin classification checks
Makefile
Package.swift
```
