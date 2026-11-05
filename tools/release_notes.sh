#!/usr/bin/env bash
# Prints the CHANGELOG.md section of one version, the body of its GitHub Release.
#
# Usage: tools/release_notes.sh <version>     e.g. tools/release_notes.sh 0.1.0
#
# Fails when CHANGELOG.md has no "## [<version>]" heading or the section is
# empty, so a release cannot go out without its notes (ADR 0014).
set -euo pipefail
# shellcheck source=tools/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

version="${1:-}"
[[ -n "$version" ]] || fail "Usage: tools/release_notes.sh <version>"

notes="$(awk -v heading="## [$version]" '
  index($0, heading) == 1 { found = 1; next }
  found && /^## \[/ { exit }
  found { print }
' "$ROOT_DIR/CHANGELOG.md" | sed -e '/./,$!d')"

[[ -n "${notes//[[:space:]]/}" ]] \
  || fail "CHANGELOG.md has no notes under \"## [$version]\". Add them before tagging v$version."
printf '%s\n' "$notes"
