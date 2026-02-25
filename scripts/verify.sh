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

echo "==> Running tests..."
xcodebuild test \
  -project LightsUp.xcodeproj \
  -scheme LightsUp \
  -destination "platform=macOS" \
  -only-testing:LightsUpTests 2>&1 \
  | grep -E "(Test [Cc]ase .* passed|Test [Cc]ase .* failed|Test [Ss]uite .* (passed|failed)|passed \([0-9]|failed \([0-9]|Executed [0-9])" \
  | tail -20

echo "==> All checks passed."
