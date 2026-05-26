#!/usr/bin/env bash
# Re-vendor the C++ core from the monorepo and verify the package builds for iOS,
# all in one step. Run this whenever you change the shared C++ core, BEFORE you
# commit/tag/push.
#
# Usage:
#   scripts/update.sh [path-to-monorepo-core]
#
# It does NOT commit, tag, or push — you do that yourself after it passes:
#   git add -A && git commit -m "Sync C++ core <what changed>"
#   git tag 1.0.1 && git push origin main 1.0.1
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"   # package root

echo "==> [1/2] Syncing C++ core into the package"
"$HERE/scripts/sync_core.sh" "$@"

echo
echo "==> [2/2] Building target UniTrack for the iOS simulator"
# Core has `import UIKit` etc., so it only builds for iOS/tvOS — not the macOS
# host. Target only `UniTrack` so SPM does not pull the heavy Firebase/Snowplow
# binaries (which slow resolution and can time out).
SDK="$(xcrun --sdk iphonesimulator --show-sdk-path)"
TARGET="arm64-apple-ios13.0-simulator"

if swift build \
      --package-path "$HERE" \
      --target UniTrack \
      --sdk "$SDK" \
      -Xswiftc -target -Xswiftc "$TARGET" \
      -Xcc -target -Xcc "$TARGET"; then
  echo
  echo "✅ Build passed. The vendored core is up to date and compiles."
  echo "   Next, commit and tag a new version, then push:"
  echo "     git add -A && git commit -m \"Sync C++ core <what changed>\""
  echo "     git tag <new-version>   # e.g. 1.0.1"
  echo "     git push origin main <new-version>"
else
  echo
  echo "❌ Build failed. Fix the C++ core, then re-run scripts/update.sh." >&2
  exit 1
fi
