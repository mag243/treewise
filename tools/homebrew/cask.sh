#!/usr/bin/env bash
# Prints the Homebrew cask for a release zip (ADR 0033): the template with the
# version and build number from the zip's name and the zip's SHA-256.
#
# Usage: tools/homebrew/cask.sh build/release/Treewise-<version>-<build>.zip
set -euo pipefail
# shellcheck source=tools/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/../lib.sh"

zip="${1:-}"
[[ -f "$zip" ]] || fail "Usage: tools/homebrew/cask.sh <Treewise-<version>-<build>.zip>"
name="$(basename "$zip" .zip)"
[[ "$name" =~ ^$APP_NAME-([0-9]+\.[0-9]+\.[0-9]+)-([0-9.]+)$ ]] \
  || fail "$name is not named $APP_NAME-<version>-<build>.zip"
version="${BASH_REMATCH[1]}"
build="${BASH_REMATCH[2]}"
sha256="$(shasum -a 256 "$zip" | cut -d ' ' -f 1)"

sed -e "s/@VERSION@/$version/" -e "s/@BUILD@/$build/" -e "s/@SHA256@/$sha256/" \
  "$TOOLS_DIR/homebrew/treewise.rb.template"
