#!/usr/bin/env bash
# Shared helpers for tools/setup.sh and tools/build.sh.
# Pre: sourced from a script inside tools/; ROOT_DIR is set by this file.
# The paths and names below are used by the scripts that source this file.
# shellcheck disable=SC2034

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$ROOT_DIR/tools"
BUILD_DIR="$ROOT_DIR/build"

# shellcheck source=tools/versions.env
source "$TOOLS_DIR/versions.env"

# GitHub Actions sets CI=true; its runner carries an older Xcode than the local pin.
if [[ "${CI:-}" == true ]]; then
  EXPECTED_XCODE_VERSION="$CI_XCODE_VERSION"
else
  EXPECTED_XCODE_VERSION="$XCODE_VERSION"
fi

PACKAGE_DIR="$ROOT_DIR/Packages/TreewiseKit"
XCODE_PROJECT="$ROOT_DIR/Treewise.xcodeproj"
MAC_SCHEME="TreewiseMac"
IOS_SCHEME="TreewiseiOS"
APP_NAME="Treewise"

if [[ -t 1 ]]; then
  C_BOLD=$'\033[1m'; C_RED=$'\033[31m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RESET=$'\033[0m'
else
  C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_RESET=""
fi

step()  { printf '\n%s==> %s%s\n' "$C_BOLD" "$*" "$C_RESET"; }
info()  { printf '    %s\n' "$*"; }
ok()    { printf '    %s✓ %s%s\n' "$C_GREEN" "$*" "$C_RESET"; }
warn()  { printf '    %s! %s%s\n' "$C_YELLOW" "$*" "$C_RESET" >&2; }
fail()  { printf '%s✗ %s%s\n' "$C_RED" "$*" "$C_RESET" >&2; exit 1; }

has() { command -v "$1" >/dev/null 2>&1; }

# Succeeds when version [1] is at least version [2]; both dotted numbers.
version_at_least() {
  [[ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n 1)" == "$2" ]]
}

# Prints the version of the selected Xcode, e.g. "27.1".
xcode_version() {
  xcodebuild -version 2>/dev/null | sed -n 's/^Xcode \([0-9][0-9.]*\).*/\1/p' | head -n 1
}

# Prints the UDID of the Treewise test simulator, or nothing when it does not exist.
ios_simulator_udid() {
  xcrun simctl list devices available 2>/dev/null |
    grep -F "    $IOS_SIMULATOR_NAME (" |
    grep -oE '[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}' | head -n 1 || true
}

# The virtual environment that holds dmgbuild (ADR 0034); Homebrew's Python
# refuses packages installed system-wide.
DMGBUILD_ENV="$BUILD_DIR/tools/dmgbuild"
DMGBUILD="$DMGBUILD_ENV/bin/dmgbuild"

# Installs dmgbuild at the pinned version when it is missing or another version.
ensure_dmgbuild() {
  if [[ -x "$DMGBUILD" ]] \
    && [[ "$("$DMGBUILD_ENV/bin/python" -m pip show dmgbuild 2>/dev/null | sed -n 's/^Version: //p')" == "$DMGBUILD_VERSION" ]]; then
    return
  fi
  rm -rf "$DMGBUILD_ENV"
  python3 -m venv "$DMGBUILD_ENV" || fail "Could not make a Python environment in ${DMGBUILD_ENV#"$ROOT_DIR"/}"
  "$DMGBUILD_ENV/bin/python" -m pip install --quiet --disable-pip-version-check "dmgbuild==$DMGBUILD_VERSION" \
    || fail "Could not install dmgbuild $DMGBUILD_VERSION"
}
