#!/usr/bin/env bash
#
# Builds the app, then packages build/Caffeine.dmg.
# Requires the create-dmg CLI: npm install -g create-dmg
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v create-dmg >/dev/null 2>&1; then
    echo "error: create-dmg not found. Install with: npm install -g create-dmg" >&2
    exit 1
fi

sh "$ROOT/scripts/build-app.sh" "$@"

cd "$ROOT/build"

flags=(--overwrite --no-version-in-filename)
if [ "${CI:-}" = "true" ]; then
    flags+=(--no-code-sign)
fi
create-dmg "${flags[@]}" Caffeine.app
