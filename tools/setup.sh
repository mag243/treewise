#!/usr/bin/env bash
# Sets up the Treewise development environment.
#
# Verifies, at the versions pinned in tools/versions.env:
#   - Xcode (selected with xcode-select, first launch done), with Swift and swift-format
# Installs:
#   - bash, shellcheck, swiftlint, xcbeautify (via Homebrew), and duoctl (from the
#     skarol/tap tap, not with --no-simulator), which folds the iPhone Duo simulator
#     (ADR 0145)
#   - the iOS Simulator runtime and the test simulator the iOS tests run on
# and configures git to use the hooks in tools/git-hooks.
#
# Safe to run repeatedly: steps that are already done are skipped.
# Supported: macOS only (development and CI); Xcode itself is installed by hand.

set -euo pipefail
# shellcheck source=tools/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

WITH_SIMULATOR=1

usage() {
  cat <<EOF
Usage: tools/setup.sh [options]

Options:
  --no-simulator    Do not install the iOS Simulator runtime or create the test
                    simulator (enough for the package and macOS tests).
  -h, --help        Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-simulator) WITH_SIMULATOR=0 ;;
    -h|--help) usage; exit 0 ;;
    *) usage; fail "Unknown option: $1" ;;
  esac
  shift
done

[[ "$(uname -s)" == Darwin ]] || fail "Treewise builds on macOS only (Xcode is required)."

check_xcode() {
  step "Xcode $EXPECTED_XCODE_VERSION"
  local dir
  dir="$(xcode-select -p 2>/dev/null)" \
    || fail "No developer directory selected. Install Xcode $EXPECTED_XCODE_VERSION, then run: sudo xcode-select -s /Applications/Xcode.app"
  [[ "$dir" == */Xcode*.app/Contents/Developer ]] \
    || fail "xcode-select points at $dir, not at Xcode. Run: sudo xcode-select -s /Applications/Xcode.app"
  local version; version="$(xcode_version)"
  [[ "$version" == "$EXPECTED_XCODE_VERSION" || "$version" == "$EXPECTED_XCODE_VERSION".* ]] \
    || fail "Xcode $version is selected; Treewise pins $EXPECTED_XCODE_VERSION (tools/versions.env). Install it, or select it with: sudo xcode-select -s <path to Xcode.app>"
  ok "Xcode $version ($dir)"
  xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1 \
    || fail "Xcode's first launch is not finished. Run: sudo xcodebuild -runFirstLaunch"
  ok "First launch done"
  local swift_format
  swift_format="$(xcrun --find swift-format 2>/dev/null)" || fail "swift-format not found in Xcode $version"
  ok "swift-format ($swift_format)"
  ok "$(swift --version 2>/dev/null | grep -o 'Swift version [0-9.]*' | head -n 1)"
}

# Prints the version a Homebrew formula's command reports.
tool_version() {
  case "$1" in
    bash) "$(brew --prefix)/bin/bash" --version 2>/dev/null | sed -n 's/.*version \([0-9]*\.[0-9]*\).*/\1/p' | head -n 1 ;;
    shellcheck) shellcheck --version 2>/dev/null | sed -n 's/^version: //p' ;;
    swiftlint) swiftlint version 2>/dev/null ;;
    xcbeautify) xcbeautify --version 2>/dev/null ;;
    duoctl) brew list --versions duoctl 2>/dev/null | awk '{ print $2 }' ;;
  esac
}

# Prints the name Homebrew installs a tool by: a tap's formula with the tap before it.
homebrew_formula() {
  case "$1" in
    duoctl) echo "skarol/tap/duoctl" ;;
    *) echo "$1" ;;
  esac
}

install_homebrew_tools() {
  step "Command-line tools (Homebrew)"
  has brew || fail "Homebrew missing. Install it from https://brew.sh, then run this script again."
  local pkg minimum version
  local pkgs=(bash shellcheck swiftlint xcbeautify)
  # duoctl only works the simulators, which --no-simulator leaves alone, as on CI.
  ((WITH_SIMULATOR)) && pkgs+=(duoctl)
  for pkg in "${pkgs[@]}"; do
    if brew list --formula "$pkg" >/dev/null 2>&1; then
      ok "$pkg"
    else
      info "Installing $pkg"
      brew install "$(homebrew_formula "$pkg")"
      ok "$pkg (installed)"
    fi
    case "$pkg" in
      bash) minimum="$BASH_MIN_VERSION" ;;
      shellcheck) minimum="$SHELLCHECK_MIN_VERSION" ;;
      swiftlint) minimum="$SWIFTLINT_MIN_VERSION" ;;
      xcbeautify) minimum="$XCBEAUTIFY_MIN_VERSION" ;;
      duoctl) minimum="$DUOCTL_MIN_VERSION" ;;
    esac
    version="$(tool_version "$pkg")"
    if [[ -z "$version" ]] || ! version_at_least "$version" "$minimum"; then
      fail "$pkg ${version:-?} is older than $minimum. Run: brew upgrade $(homebrew_formula "$pkg")"
    fi
  done
}

# Prints the identifier of the installed iOS runtime for version [1], or nothing.
ios_runtime_id() {
  xcrun simctl list runtimes available 2>/dev/null |
    grep -E "^iOS ${1//./\\.} " |
    grep -oE 'com\.apple\.CoreSimulator\.SimRuntime\.iOS-[0-9]+(-[0-9]+)*$' | head -n 1 || true
}

# The runtime of identifier [1] when it is installed and available.
ios_own_runtime() {
  xcrun simctl list runtimes available 2>/dev/null |
    grep -oE "${1//./\\.}\$" | head -n 1 || true
}

install_simulators() {
  if ((WITH_SIMULATOR == 0)); then
    step "iOS Simulators"
    info "Skipped (--no-simulator)"
    return
  fi
  install_simulator "$IOS_SIMULATOR_OS" "$IOS_SIMULATOR_DEVICE_TYPE" "$IOS_SIMULATOR_NAME"
  install_simulator "$IOS_REVIEW_SIMULATOR_OS" "$IOS_REVIEW_SIMULATOR_DEVICE_TYPE" \
    "$IOS_REVIEW_SIMULATOR_NAME"
  install_simulator "$IOS_IPHONE_SIMULATOR_OS" "$IOS_IPHONE_SIMULATOR_DEVICE_TYPE" \
    "$IOS_IPHONE_SIMULATOR_NAME"
  install_simulator "$IOS_DUO_SIMULATOR_OS" "$IOS_DUO_SIMULATOR_DEVICE_TYPE" \
    "$IOS_DUO_SIMULATOR_NAME" "$IOS_DUO_SIMULATOR_RUNTIME"
}

# Installs the runtime of iOS [1] when missing and creates the simulator [3] of device type [2],
# on the runtime of identifier [4] when the device has one of its own, as the iPhone Duo does.
install_simulator() {
  local os="$1" type="$2" name="$3" own="${4:-}"
  step "iOS Simulator $os ($type)"
  local runtime
  if [[ -n "$own" ]]; then
    runtime="$(ios_own_runtime "$own")"
    [[ -n "$runtime" ]] ||
      fail "Runtime $own missing: install the $type's iOS $os from Xcode > Settings > Components"
  else
    runtime="$(ios_runtime_id "$os")"
  fi
  if [[ -n "$runtime" ]]; then
    ok "Runtime $runtime"
  else
    info "Downloading the iOS $os runtime (several GB)"
    xcodebuild -downloadPlatform iOS -buildVersion "$os" \
      || fail "Could not download the iOS $os runtime"
    runtime="$(ios_runtime_id "$os")"
    [[ -n "$runtime" ]] || fail "iOS $os runtime still missing after the download"
    ok "Installed $runtime"
  fi
  local udid; udid="$(ios_simulator_udid "$name")"
  if [[ -n "$udid" ]]; then
    ok "Simulator '$name' ($udid)"
  else
    udid="$(xcrun simctl create "$name" "$type" "$runtime")" \
      || fail "Could not create simulator '$name'"
    ok "Created simulator '$name' ($udid)"
  fi
}

configure_git() {
  step "Git hooks"
  if ! git -C "$ROOT_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    warn "Not a git repository yet. Run 'git init' and then this script again to install hooks."
    return
  fi
  chmod +x "$TOOLS_DIR"/*.sh "$TOOLS_DIR"/xcode/*.sh "$TOOLS_DIR"/git-hooks/*
  git -C "$ROOT_DIR" config core.hooksPath tools/git-hooks
  ok "core.hooksPath = tools/git-hooks"
}

resolve_package() {
  step "Swift package"
  if [[ ! -f "$PACKAGE_DIR/Package.swift" ]]; then
    info "No Packages/TreewiseKit yet; skipped"
    return
  fi
  swift package --package-path "$PACKAGE_DIR" resolve >/dev/null \
    || fail "Could not resolve the package dependencies"
  ok "Dependencies resolved"
}

install_dmgbuild() {
  step "dmgbuild $DMGBUILD_VERSION"
  ensure_dmgbuild
  ok "dmgbuild $DMGBUILD_VERSION (${DMGBUILD_ENV#"$ROOT_DIR"/})"
}

check_xcode
install_homebrew_tools
install_simulators
configure_git
resolve_package
install_dmgbuild

step "Done"
info "Next: tools/build.sh"
