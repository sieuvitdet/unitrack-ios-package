#!/usr/bin/env bash
# Re-vendors the shared C++ core into Sources/UniTrackCore as REAL files
# (not symlinks), so this package stays self-contained when cloned over SPM.
#
# Usage:
#   scripts/sync_core.sh [path-to-monorepo-core]
#
# Defaults to ../unitrack-sdk/core relative to this package. Override by passing
# the monorepo's core/ directory as the first argument.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"            # package root
CORE="${1:-$HERE/../unitrack-sdk/core}"

if [[ ! -d "$CORE/src" || ! -d "$CORE/include" ]]; then
  echo "[sync_core] core not found at: $CORE" >&2
  echo "            pass the monorepo core/ path: scripts/sync_core.sh /path/to/core" >&2
  exit 1
fi

DEST="$HERE/Sources/UniTrackCore"
rm -rf "$DEST/src" "$DEST/include/unitrack"
mkdir -p "$DEST/src" "$DEST/include/unitrack"

# -L dereferences any symlinks in the source tree.
cp -RL "$CORE/src/." "$DEST/src/"
cp -L  "$CORE/include/unitrack/unitrack.h" "$DEST/include/unitrack.h"
cp -RL "$CORE/include/unitrack/." "$DEST/include/unitrack/"

echo "[sync_core] vendored C++ core from $CORE into $DEST"
