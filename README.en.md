[简体中文](README.md) | [繁體中文](README.zh-TW.md) | [English](README.en.md)

<p align="center"><img src="Resources/AppIcon.png" width="128" alt="ShiftIME"></p>

# ShiftIME

**Tap `Shift` to switch between Chinese and English on your Mac, just like on Windows.** [Download the latest release](https://github.com/TW527E/ShiftIME/releases/latest)

ShiftIME is a lightweight, event-driven, native macOS enhancement for switching input sources. It runs in the background, appears in the menu bar by default, and stays out of the Dock by default.

## Features

### Shift input-source toggle

- Tap `Shift` by itself to switch from the current input source to the most recently used English input source.
- When English is active, tap `Shift` again to restore the previously used input source.
- When returning to Apple Pinyin, ShiftIME waits for the input source to become selected and retries if macOS has not finished switching. Plain text keystrokes during that bounded wait are deferred so the Pinyin indicator cannot be paired with lost or Latin-only first input.
- After switching, macOS shows its native input-source indicator next to the caret; ShiftIME only hands focus around when a focused text input has not adopted the new source, since that dismisses the indicator.
- Typing uppercase letters, modifier shortcuts, Shift-clicking, and Shift-scrolling do not trigger a switch.

### Shift + Space Pinyin width toggle

- Press `Shift + Space` in an Apple Pinyin input source to toggle the system full-width/half-width punctuation mode.
- No HUD is displayed.
- Apple Pinyin – Traditional and Pinyin – Simplified are supported.
- **Apple Zhuyin is deliberately excluded.** In Zhuyin and all other input sources, `Shift + Space` passes through unchanged.

The two shortcuts can be enabled or disabled independently in Settings.

### Remote-app and game bypass

- `Shift` and `Shift + Space` pass through by default in common remote-desktop, streaming, and game applications so ShiftIME does not intercept them.
- Automatic detection covers common remote apps, the macOS game category, and Steam, GOG, and Epic game paths.
- Add other apps to the Settings list and control the `Shift` and `Shift + Space` bypasses independently.
- Newly added apps bypass both shortcuts by default; the menu-bar menu can also add the current app quickly.

## Other settings

- Show the menu bar icon; enabled by default.
- Show the Dock icon; disabled by default.
- Show the center-screen HUD when macOS does not show its caret indicator; disabled by default.
- If both icons are hidden, open ShiftIME again from Finder to return to Settings.

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

# Create dist/ShiftIME.app
make app

# Create dist/ShiftIME-1.0.0.dmg
make dmg
```

Build a Universal Binary for both Apple Silicon and Intel:

```bash
BUILD_ARCHS="arm64 x86_64" VERSION=1.0.0 make dmg
```

Other supported build parameters:

```bash
VERSION=1.0.0 BUILD_NUMBER=2 CONFIGURATION=release make app
```

Run all local verification:

```bash
make verify
```

## Installing the DMG

1. Download and open `ShiftIME-<version>.dmg` from [Releases](https://github.com/TW527E/ShiftIME/releases/latest) (or a locally built `dist/ShiftIME-<version>.dmg`).
2. Drag `ShiftIME.app` to the `Applications` shortcut in the disk image.
3. Start ShiftIME from Applications.
4. Grant both keyboard permissions shown in Settings.

Upgrading from ShiftInput: quit and delete `ShiftInput.app` first, otherwise both apps respond to Shift. ShiftIME needs the keyboard permissions granted again, and its settings start from the defaults.

## GitHub Actions

`.github/workflows/build-dmg.yml` runs for:

- Pushes to `main`.
- Pull requests.
- Manual workflow dispatches.

The workflow runs checks, builds an `arm64 + x86_64` Universal Binary, packages and verifies a DMG, and uploads it as a GitHub Actions artifact.

To publish a new version, change the semantic version in the root `VERSION` file (for example, `0.3.0`), commit it, and push it to `main`. After a successful build, the workflow automatically creates the matching `v0.3.0` tag and GitHub Release, attaches the DMG, and lists every commit since the previous version in the release notes. Existing version tags are never overwritten.

## Technical design

- Swift, AppKit, Core Graphics, and Text Input Source Services.
- `CGEventTap` intercepts keyboard events only; Shift-click and Shift-scroll are detected from the window server's event counters, so no mouse or scroll event passes through ShiftIME.
- System input-source notifications replace continuous polling.
- Each input-source notification uses one system snapshot to update persistence, Pinyin capability, and UI consistently.
- `TISSelectInputSource` performs input-source changes and the previous source is persisted; each switch is confirmed with the current source ID and selected state, retried a bounded number of times when necessary, and plain text keystrokes and Shift are deferred until confirmation completes, so a capital letter typed right after a switch is not seen by Pinyin as a bare Shift tap that toggles its Chinese/English mode.
- `Shift + Space` is forwarded as Apple's native `Option + Shift + H` command only when Apple Pinyin is detected.
- Foreground-app metadata is refreshed only when the active app changes; remote-app and game bypass checks do not poll windows or processes.
- A timed-out event tap recovers automatically; monitoring stops if permissions are revoked.
- A system-disabled event tap is rebuilt safely; changing shortcut settings needs no rebuild.

## Project layout

```text
.github/workflows/build-dmg.yml  GitHub Actions DMG build
VERSION                          Application and Release version
Sources/ShiftIMECore/          Testable pure-Swift logic
Sources/ShiftIME/              AppKit application and system integration
Resources/AppIcon.png            1024px application icon master
Scripts/build-app.sh             .app build script
Scripts/generate-app-icon.sh     ICNS iconset generation script
Scripts/create-dmg.sh            DMG packaging script
Scripts/smoke-test-app.sh        App lifecycle and menu-bar check
Scripts/StateMachineChecks.swift State-machine and Pinyin classification checks
Makefile
Package.swift
```
