#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/ShiftInput.app"

if [[ ! -d "$APP" ]]; then
    echo "Missing app bundle: run make app first" >&2
    exit 1
fi

open -n "$APP" --args -shiftToggleEnabled false -pinyinWidthToggleEnabled false -hasLaunchedBefore true

PID=""
for _ in {1..20}; do
    PID="$(pgrep -nx ShiftInput || true)"
    [[ -n "$PID" ]] && break
    sleep 0.1
done

if [[ -z "$PID" ]]; then
    echo "ShiftInput did not enter its application run loop" >&2
    exit 1
fi

cleanup() {
    kill "$PID" 2>/dev/null || true
}
trap cleanup EXIT

sleep 0.5
HEAP="$(heap "$PID")"
grep -q "StatusBarController" <<<"$HEAP" || {
    echo "AppDelegate lifecycle did not create StatusBarController" >&2
    exit 1
}
grep -q "NSStatusBarButton" <<<"$HEAP" || {
    echo "Status bar button was not created" >&2
    exit 1
}

echo "Application lifecycle and status bar smoke test passed (pid $PID)"
