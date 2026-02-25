#!/usr/bin/env bash
# reset-state.sh — Reset LightsUp to a fresh-install state for testing.
# Clears calendar permission (TCC) and all UserDefaults (onboarding, calendar selection).
set -euo pipefail

BUNDLE_ID="ohwow.LightsUp"

echo "==> Resetting calendar permission (TCC)…"
tccutil reset Calendar "$BUNDLE_ID"

echo "==> Resetting UserDefaults…"
defaults delete "$BUNDLE_ID" 2>/dev/null || true

echo "✓ Fresh state. Next launch will show onboarding and re-prompt for calendar access."
