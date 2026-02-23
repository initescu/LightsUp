#!/bin/bash
# verify.sh — lint + build check. Run from repo root or scripts/.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Linting..."
swiftlint lint --config .swiftlint.yml

echo "==> Building..."
xcodebuild \
  -project LightsUp.xcodeproj \
  -scheme LightsUp \
  -configuration Debug \
  -destination "platform=macOS" \
  build 2>&1 \
  | grep -E "(error:|warning:|BUILD SUCCEEDED|BUILD FAILED)" \
  | grep -v appintentsmetadata

echo "==> All checks passed."
