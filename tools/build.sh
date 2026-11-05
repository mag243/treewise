#!/usr/bin/env bash
# Checks, builds, tests, and exports Treewise.
#
# Usage: tools/build.sh [command...]
#   check       Formatting (swift-format), lint (SwiftLint), dependency rules, shellcheck.
#   format      Rewrite Swift code with SwiftLint --fix and swift-format (the only
#               command that changes code).
#   test        Package tests (swift test). Followed by a filter, only matching tests:
#               tools/build.sh test TransferPlannerTests
#   crossvolume The cross-volume tests, on a temporary disk image (hdiutil).
#   coverage    Package tests with code coverage; fails when a module is below its
#               line-coverage target (Core 90 %, FileSystem 75 %, UI 70 %; PLAN.md §9.1).
#   build       Build the macOS app with its tests (compiled, not run) and the iOS
#               app (for the Simulator), Debug.
#   apptest     The macOS app's tests, including the XCUITest smoke tests, without
#               the screenshots. Followed by a filter, only those tests, as
#               Class or Class/testName, several separated by commas:
#               tools/build.sh apptest LaunchTests/testSpaceShowsQuickLook
#   iostest     The package tests on the pinned iOS Simulator (tools/versions.env), so
#               the shared code is tested on iOS too (M6a).
#   run         Build the macOS app and start it. Every word after run goes to the
#               app: tools/build.sh run -TreewiseRoot /tmp/fixture. `run sandbox`
#               starts it confined to the sandbox volumes, attached first (ADR 0019).
#   package     Release archive of the macOS app, signed with the Developer ID,
#               notarized and stapled, zipped as build/release/Treewise-<version>-<build>.zip,
#               and a notarized .dmg beside it (ADR 0014, ADR 0030, ADR 0034).
#               Notarizes with the keychain profile treewise-notary
#               (TREEWISE_NOTARY_PROFILE), or with NOTARY_KEY_PATH, NOTARY_KEY_ID and
#               NOTARY_ISSUER_ID when they are set.
#   publish     Release from this Mac (ADR 0035): checks that the tree is clean and the
#               tag v<MARKETING_VERSION> points at HEAD, runs package, then
#               tools/publish.sh: appcast, GitHub Release in mag243/treewise-releases
#               and the Homebrew cask. It pushes to those repositories: the owner runs it.
#   export      Release archive and Developer ID export of the macOS app ->
#               build/TreewiseMac/, with tools/ExportOptions-mac.plist; not notarized.
#   quick       check + test: the gate for a step that leaves the apps alone.
#   verify      check + test + build: the gate for a change to an app. Leaves the
#               screen alone (ADR 0028).
#   ci          check + test + build + apptest: when the owner says the UI tests may
#               take the screen, before a push and at the end of a plan. The default.
#   all         ci + export.
#   screenshots The download page's screenshots (ADR 0041): makes the sandbox volumes
#               afresh, runs ScreenshotTests on them and saves the images as
#               build/screenshots/<name>.png. Takes the screen, as ci does.
#   fixture     Fill build/fixtures/large with 10,000 files and a few folders, for
#               the list's performance: tools/build.sh run -TreewiseRoot "$PWD/build/fixtures/large"
#   sandbox     Attach the two sandbox volumes, Treewise Sandbox HD and T7: disk
#               images in build/sandbox/ with the prototype's demo tree, made when
#               missing (ADR 0019). `sandbox reset` makes them afresh, `sandbox
#               eject` detaches them. Try file operations with tools/build.sh run sandbox.
#   icon        Render the app icons from tools/icon/treewise-icon.svg into the
#               AppIcon sets of both apps.
#   clean       Remove build/.
#
# Commands run in the order given. The script stops at the first failure and
# exits non-zero, so it can gate commits and CI. Output goes to build/logs/,
# build/reports/ and build/DerivedData/; nothing is written loose in build/.

set -euo pipefail

# macOS ships bash 3.2; this script needs bash 4.4+ (mapfile, empty arrays under set -u).
if ((BASH_VERSINFO[0] < 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] < 4))); then
  for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash; do
    [[ -x "$candidate" ]] && exec "$candidate" "$0" "$@"
  done
  echo "bash 4.4 or newer is required. Run tools/setup.sh (installs it via Homebrew)." >&2
  exit 1
fi

# shellcheck source=tools/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SWIFT_DIRS=(Packages Apps UITests)
# Warnings fail the package build here, not in Package.swift: Xcode adds
# -suppress-warnings to package dependencies, which clashes with -warnings-as-errors.
SWIFT_TEST_FLAGS=(-Xswiftc -warnings-as-errors)
DERIVED_DATA="$BUILD_DIR/DerivedData"
LOG_DIR="$BUILD_DIR/logs"
REPORT_DIR="$BUILD_DIR/reports"
EXPORT_OPTIONS="$TOOLS_DIR/ExportOptions-mac.plist"
MAC_DESTINATION="platform=macOS,arch=$(uname -m)"
COMMANDS=" check format test crossvolume coverage build apptest iostest run package export fixture sandbox icon publish screenshots quick verify ci all clean help "
# The UI tests that make the download page's screenshots, not run by apptest (ADR 0041).
SCREENSHOT_TESTS="TreewiseMacUITests/ScreenshotTests"
SCREENSHOT_DIR="$BUILD_DIR/screenshots"
declare -a SUMMARY=()

usage() { sed -n '2,/^$/p' "$0" | sed 's/^# \{0,1\}//'; }

require_package() {
  [[ -f "$PACKAGE_DIR/Package.swift" ]] \
    || fail "No Packages/TreewiseKit/Package.swift."
}

require_project() {
  [[ -d "$XCODE_PROJECT" ]] \
    || fail "No Treewise.xcodeproj."
}

swift_format() {
  local exe
  exe="$(xcrun --find swift-format 2>/dev/null)" || fail "swift-format not found. Run tools/setup.sh."
  "$exe" "$@"
}

# Prints the existing directories from SWIFT_DIRS that hold Swift files, relative to ROOT_DIR.
swift_dirs() {
  local d
  for d in "${SWIFT_DIRS[@]}"; do
    [[ -d "$ROOT_DIR/$d" ]] && find "$ROOT_DIR/$d" -name '*.swift' -print -quit | grep -q . && echo "$d"
  done
  return 0
}

timed() {
  local name="$1"; shift
  local start=$SECONDS
  "$@"
  SUMMARY+=("$(printf '%-12s %4ds' "$name" $((SECONDS - start)))")
}

# Runs xcodebuild on the project with the shared DerivedData, logging to build/logs/[1].log.
# Output is shown through xcbeautify when it is installed.
# Post: fails the build with the log's tail when xcodebuild fails.
xcode() {
  local log="$LOG_DIR/$1.log"; shift
  mkdir -p "$LOG_DIR"
  local rc=0
  if has xcbeautify; then
    (cd "$ROOT_DIR" && xcodebuild -project "$XCODE_PROJECT" -derivedDataPath "$DERIVED_DATA" "$@" 2>&1) |
      tee "$log" | xcbeautify --quiet || rc=${PIPESTATUS[0]}
  else
    (cd "$ROOT_DIR" && xcodebuild -project "$XCODE_PROJECT" -derivedDataPath "$DERIVED_DATA" "$@" >"$log" 2>&1) \
      || rc=$?
  fi
  ((rc == 0)) || { tail -n 30 "$log" >&2; fail "xcodebuild failed; log: ${log#"$ROOT_DIR"/}"; }
}

# Prints a fresh result bundle path under build/reports/ for [1]; xcodebuild refuses an existing one.
result_bundle() {
  local path="$REPORT_DIR/$1.xcresult"
  mkdir -p "$REPORT_DIR"
  rm -rf "$path"
  echo "$path"
}

cmd_format() {
  step "Format"
  local dirs; mapfile -t dirs < <(swift_dirs)
  ((${#dirs[@]} > 0)) || { info "No Swift files yet"; return; }
  has swiftlint || fail "swiftlint not found. Run tools/setup.sh."
  (cd "$ROOT_DIR" && swiftlint lint --fix --quiet)
  (cd "$ROOT_DIR" && swift_format format --in-place --recursive --parallel "${dirs[@]}")
  ok "Formatted"
}

cmd_check() {
  step "Check"
  local dirs; mapfile -t dirs < <(swift_dirs)
  if ((${#dirs[@]} > 0)); then
    (cd "$ROOT_DIR" && swift_format lint --strict --recursive --parallel "${dirs[@]}") \
      || fail "swift-format reported problems. Run: tools/build.sh format"
    ok "swift-format"
    has swiftlint || fail "swiftlint not found. Run tools/setup.sh."
    (cd "$ROOT_DIR" && swiftlint lint --strict --quiet) \
      || fail "SwiftLint reported problems (.swiftlint.yml, ADR 0009)"
    ok "SwiftLint"
  else
    info "No Swift files yet; swift-format and SwiftLint skipped"
  fi
  "$TOOLS_DIR/check_dependencies.sh" || fail "Dependency rules violated (ADR 0001)"
  ok "Dependency rules"
  has shellcheck || fail "shellcheck not found. Run tools/setup.sh."
  shellcheck -x "$TOOLS_DIR"/*.sh "$TOOLS_DIR"/xcode/*.sh "$TOOLS_DIR"/git-hooks/* || fail "shellcheck reported problems"
  ok "shellcheck"
}

# Runs the package tests; an optional filter narrows them to matching suites or tests.
cmd_test() {
  local filter="${1:-}"
  step "Package tests${filter:+ ($filter)}"
  require_package
  mkdir -p "$LOG_DIR"
  local args=(test --package-path "$PACKAGE_DIR" "${SWIFT_TEST_FLAGS[@]}")
  [[ -n "$filter" ]] && args+=(--filter "$filter")
  local rc=0 log="$LOG_DIR/test.log"
  swift "${args[@]}" >"$log" 2>&1 || rc=$?
  if ((rc != 0)); then
    grep -E "✘|error:" "$log" | head -n 40 >&2 || tail -n 40 "$log" >&2
    fail "Package tests failed; log: build/logs/test.log"
  fi
  # One summary line per test bundle; the full output stays in the log.
  grep -E "^✔ Test run with" "$log" | sed "s/^✔ /    /" || true
  ok "Package tests passed"
}

# Line-coverage target per package module, in percent (PLAN.md §9.1).
declare -A COVERAGE_TARGETS=([TreewiseCore]=90 [TreewiseFileSystem]=75 [TreewiseUI]=70)

# Prints the line coverage, in percent, of the package sources of module [1],
# from the last coverage run; "100.00" for a module without executable lines.
line_coverage() {
  local debug="$PACKAGE_DIR/.build/debug" binaries=() bundle
  for bundle in "$debug"/*.xctest; do
    binaries+=("$bundle/Contents/MacOS/$(basename "$bundle" .xctest)")
  done
  ((${#binaries[@]} > 0)) || return 0
  local others=() binary
  for binary in "${binaries[@]:1}"; do others+=(-object "$binary"); done
  # llvm-cov records file names relative to the package; columns 8 and 9 are
  # the line count and the missed lines.
  (cd "$PACKAGE_DIR" && xcrun llvm-cov report -instr-profile "$debug/codecov/default.profdata" \
    "${binaries[0]}" "${others[@]}") |
    awk -v prefix="Sources/$1/" 'index($1, prefix) == 1 { lines += $8; missed += $9 }
      END { printf "%.2f\n", lines ? 100 * (lines - missed) / lines : 100 }'
}

cmd_coverage() {
  step "Coverage"
  require_package
  mkdir -p "$LOG_DIR"
  local rc=0
  swift test --package-path "$PACKAGE_DIR" "${SWIFT_TEST_FLAGS[@]}" --enable-code-coverage \
    >"$LOG_DIR/coverage.log" 2>&1 || rc=$?
  ((rc == 0)) || { tail -n 30 "$LOG_DIR/coverage.log" >&2; fail "Package tests failed; log: build/logs/coverage.log"; }
  local module percent below=0
  for module in "${!COVERAGE_TARGETS[@]}"; do
    percent="$(line_coverage "$module")"
    [[ -n "$percent" ]] || fail "No coverage data for $module"
    if awk -v p="$percent" -v t="${COVERAGE_TARGETS[$module]}" 'BEGIN { exit !(p >= t) }'; then
      ok "$module $percent % (target ${COVERAGE_TARGETS[$module]} %)"
    else
      warn "$module $percent % is below its target of ${COVERAGE_TARGETS[$module]} %"
      below=1
    fi
  done
  ((below == 0)) || fail "Coverage below target"
}

# The cross-volume suites run only when TREEWISE_CROSS_VOLUME=1, so a plain test run
# never needs a disk image or hdiutil.
cmd_crossvolume() {
  step "Cross-volume tests"
  require_package
  mkdir -p "$LOG_DIR"
  local rc=0
  TREEWISE_CROSS_VOLUME=1 swift test --package-path "$PACKAGE_DIR" "${SWIFT_TEST_FLAGS[@]}" --filter CrossVolume 2>&1 |
    tee "$LOG_DIR/crossvolume.log" || rc=${PIPESTATUS[0]}
  ((rc == 0)) || fail "Cross-volume tests failed; log: build/logs/crossvolume.log"
  ok "Cross-volume tests passed"
}

cmd_build() {
  step "Build"
  require_project
  # build-for-testing also compiles the UI tests, without taking the screen (ADR 0028).
  xcode build-mac -scheme "$MAC_SCHEME" -destination "$MAC_DESTINATION" build-for-testing
  ok "$MAC_SCHEME"
  xcode build-ios -scheme "$IOS_SCHEME" -destination 'generic/platform=iOS Simulator' build
  ok "$IOS_SCHEME"
}

cmd_apptest() {
  local filter="${1:-}" only=() tests=() test
  step "macOS app tests${filter:+ ($filter)}"
  require_project
  local bundle; bundle="$(result_bundle "$MAC_SCHEME")"
  IFS=, read -ra tests <<<"$filter"
  for test in "${tests[@]}"; do only+=(-only-testing:"TreewiseMacUITests/$test"); done
  xcode apptest -scheme "$MAC_SCHEME" -destination "$MAC_DESTINATION" -resultBundlePath "$bundle" \
    -skip-testing:"$SCREENSHOT_TESTS" "${only[@]}" test
  ok "$MAC_SCHEME tests passed. Results: ${bundle#"$ROOT_DIR"/}"
}

# The volume names the screenshots show instead of the sandbox's own (ADR 0041).
declare -A SCREENSHOT_VOLUME_NAMES=([HD]="Macintosh HD" [T7]="T7")
# The devices of the sandbox volumes while they carry those names.
SCREENSHOT_DEVICES=()

# A volume's property from diskutil, such as DeviceIdentifier or MountPoint.
volume_info() { diskutil info -plist "$1" | plutil -extract "$2" raw -; }

# Gives the sandbox volumes their sandbox names back.
screenshot_volumes_restore() {
  local index volumes=(HD T7)
  for index in "${!SCREENSHOT_DEVICES[@]}"; do
    diskutil rename "${SCREENSHOT_DEVICES[$index]}" "Treewise Sandbox ${volumes[$index]}" >/dev/null || true
  done
  SCREENSHOT_DEVICES=()
}

# Makes the download page's screenshots on fresh sandbox volumes (ADR 0041),
# named as a Mac's disks for the time it takes.
cmd_screenshots() {
  cmd_sandbox reset
  step "Screenshots"
  require_project
  local volume mounts=()
  trap screenshot_volumes_restore EXIT
  for volume in HD T7; do
    SCREENSHOT_DEVICES+=("$(volume_info "$(sandbox_mount "$volume")" DeviceIdentifier)")
    diskutil rename "${SCREENSHOT_DEVICES[-1]}" "${SCREENSHOT_VOLUME_NAMES[$volume]}" >/dev/null
    mounts+=("$(volume_info "${SCREENSHOT_DEVICES[-1]}" MountPoint)")
  done
  local bundle="$REPORT_DIR/Screenshots.xcresult"
  rm -rf "$bundle" "$SCREENSHOT_DIR"
  mkdir -p "$REPORT_DIR" "$SCREENSHOT_DIR"
  # xcodebuild hands TEST_RUNNER_ variables to the tests without the prefix.
  local -x TEST_RUNNER_TREEWISE_SANDBOX
  TEST_RUNNER_TREEWISE_SANDBOX="${mounts[0]}:${mounts[1]}"
  xcode screenshots -scheme "$MAC_SCHEME" -destination "$MAC_DESTINATION" \
    -resultBundlePath "$bundle" -only-testing:"$SCREENSHOT_TESTS" test
  screenshot_volumes_restore
  trap - EXIT
  local exported="$SCREENSHOT_DIR/attachments"
  xcrun xcresulttool export attachments --path "$bundle" --output-path "$exported" >/dev/null
  python3 -I "$TOOLS_DIR/screenshots/name_attachments.py" "$exported" "$SCREENSHOT_DIR"
  rm -rf "$exported"
  ok "Screenshots in ${SCREENSHOT_DIR#"$ROOT_DIR"/}"
}

cmd_iostest() {
  step "iOS app tests"
  require_project
  local udid; udid="$(ios_simulator_udid)"
  [[ -n "$udid" ]] || fail "Simulator '$IOS_SIMULATOR_NAME' not found. Run tools/setup.sh."
  local bundle; bundle="$(result_bundle "TreewiseKit-iOS")"
  local log="$LOG_DIR/iostest.log" rc=0
  mkdir -p "$LOG_DIR"
  # The package's own scheme holds its test targets; xcodebuild finds it from
  # inside the package folder.
  (cd "$PACKAGE_DIR" && xcodebuild -scheme TreewiseKit-Package -derivedDataPath "$DERIVED_DATA-ios" \
    -destination "id=$udid" -resultBundlePath "$bundle" test >"$log" 2>&1) || rc=$?
  ((rc == 0)) || { tail -n 30 "$log" >&2; fail "iOS package tests failed; log: ${log#"$ROOT_DIR"/}"; }
  ok "Package tests passed on iOS $IOS_SIMULATOR_OS. Results: ${bundle#"$ROOT_DIR"/}"
}

# Builds the macOS app (Debug) and starts it in the foreground with the arguments given.
cmd_run() {
  step "Run"
  require_project
  xcode build-mac -scheme "$MAC_SCHEME" -destination "$MAC_DESTINATION" build
  local app
  app="$(find "$DERIVED_DATA/Build/Products/Debug" -maxdepth 1 -name "$APP_NAME.app" -print -quit 2>/dev/null)"
  [[ -n "$app" ]] || fail "No $APP_NAME.app in build/DerivedData/Build/Products/Debug"
  local exe; exe="$app/Contents/MacOS/$(defaults read "$app/Contents/Info" CFBundleExecutable)"
  if [[ "${1:-}" == sandbox ]]; then
    shift
    cmd_sandbox attach
    set -- -TreewiseSandbox "$(sandbox_mount HD):$(sandbox_mount T7)" "$@"
  fi
  info "Starting ${app#"$ROOT_DIR"/}"
  "$exe" "$@"
}

# Archives the macOS app in Release to build/archives/; prints the archive path.
archive_mac() {
  local archive="$BUILD_DIR/archives/$MAC_SCHEME.xcarchive"
  rm -rf "$archive"
  xcode archive -scheme "$MAC_SCHEME" -configuration Release -destination "generic/platform=macOS" \
    -archivePath "$archive" archive >&2
  echo "$archive"
}

# The certificate that signs a release, and the notary keychain profile (ADR 0030).
SIGNING_CERTIFICATE="Developer ID Application"
NOTARY_PROFILE="${TREEWISE_NOTARY_PROFILE:-treewise-notary}"

require_signing() {
  [[ -f "$EXPORT_OPTIONS" ]] || fail "No tools/ExportOptions-mac.plist"
  security find-identity -v -p codesigning | grep -q "\"$SIGNING_CERTIFICATE: " \
    || fail "No \"$SIGNING_CERTIFICATE\" certificate in the keychain; signing a release needs one."
}

# Archives the app and exports it signed with the Developer ID into $1.
export_mac() {
  local out="$1"
  rm -rf "$out"
  local archive; archive="$(archive_mac)"
  mkdir -p "$LOG_DIR"
  xcodebuild -exportArchive -archivePath "$archive" -exportPath "$out" \
    -exportOptionsPlist "$EXPORT_OPTIONS" >"$LOG_DIR/export.log" 2>&1 \
    || { tail -n 30 "$LOG_DIR/export.log" >&2; fail "Export failed; log: build/logs/export.log"; }
}

# The notarytool arguments for the API key: from the environment in CI, else
# from the keychain profile.
notary_credentials() {
  if [[ -n "${NOTARY_KEY_PATH:-}" ]]; then
    printf '%s\n' --key "$NOTARY_KEY_PATH" --key-id "${NOTARY_KEY_ID:?}" --issuer "${NOTARY_ISSUER_ID:?}"
  else
    printf '%s\n' --keychain-profile "$NOTARY_PROFILE"
  fi
}

# Sends a zip or disk image to Apple's notary service and waits for its
# verdict; a rejection prints the service's log.
notarize_file() {
  local file="$1"
  local name; name="$(basename "$file")"
  local result="$LOG_DIR/notarize-$name.json"
  local credentials; mapfile -t credentials < <(notary_credentials)
  info "Waiting for Apple's notary service ($name)"
  xcrun notarytool submit "$file" "${credentials[@]}" --wait --output-format json >"$result" \
    || { cat "$result" >&2; fail "Could not submit $name for notarization; see the output above."; }
  local status id
  status="$(plutil -extract status raw "$result")"
  id="$(plutil -extract id raw "$result")"
  if [[ "$status" != Accepted ]]; then
    xcrun notarytool log "$id" "${credentials[@]}" "$LOG_DIR/notarize-$name-log.json" >/dev/null 2>&1 || true
    fail "Notarization of $name: $status; log: build/logs/notarize-$name-log.json"
  fi
  ok "Notarized $name ($id)"
}

# Staples the notary's ticket to an app or a disk image, so it opens offline too.
staple() {
  xcrun stapler staple "$1" >"$LOG_DIR/staple.log" 2>&1 \
    || fail "Could not staple the ticket to $(basename "$1"); log: build/logs/staple.log"
}

# Notarizes the app, which the service takes as a zip, and staples it.
notarize_app() {
  local app="$1"
  local upload="$BUILD_DIR/release/$APP_NAME-notarize.zip"
  ditto -c -k --keepParent "$app" "$upload"
  notarize_file "$upload"
  rm -f "$upload"
  staple "$app"
}

# Builds the disk image people install from (ADR 0034): the stapled app and a
# link to Applications on the rendered background, signed with the Developer ID.
make_disk_image() {
  local app="$1" out="$2"
  local work="$BUILD_DIR/dmg"
  rm -rf "$work"
  mkdir -p "$work"
  ensure_dmgbuild
  local scale
  for scale in 1 2; do
    swift "$TOOLS_DIR/dmg/render.swift" "$TOOLS_DIR/dmg/background.svg" "$work/background@${scale}x.png" "$scale" \
      || fail "Could not render the disk image background"
  done
  tiffutil -cathidpicheck "$work/background@1x.png" "$work/background@2x.png" -out "$work/background.tiff" \
    >/dev/null 2>&1 || fail "Could not combine the background images"
  "$DMGBUILD" -s "$TOOLS_DIR/dmg/settings.py" -D app="$app" -D background="$work/background.tiff" \
    "$APP_NAME" "$out" >"$LOG_DIR/dmgbuild.log" 2>&1 \
    || fail "dmgbuild failed; log: build/logs/dmgbuild.log"
  codesign --sign "$SIGNING_CERTIFICATE" --timestamp "$out" 2>"$LOG_DIR/codesign-dmg.log" \
    || fail "Could not sign the disk image; log: build/logs/codesign-dmg.log"
}

# Fails unless the app's signature holds and Gatekeeper lets it open.
verify_release() {
  local app="$1"
  codesign --verify --deep --strict "$app" 2>"$LOG_DIR/codesign.log" \
    || fail "The signature does not verify; log: build/logs/codesign.log"
  spctl --assess --type exec "$app" 2>"$LOG_DIR/spctl.log" \
    || fail "Gatekeeper rejects the app; log: build/logs/spctl.log"
  ok "Gatekeeper accepts $APP_NAME.app"
}

# Fails unless Gatekeeper lets the disk image open.
verify_disk_image() {
  spctl --assess --type open --context context:primary-signature "$1" 2>"$LOG_DIR/spctl-dmg.log" \
    || fail "Gatekeeper rejects the disk image; log: build/logs/spctl-dmg.log"
  ok "Gatekeeper accepts $(basename "$1")"
}

# Exports, notarizes and checks the app, then zips it as
# build/release/Treewise-<version>-<build>.zip for Sparkle and Homebrew, and
# makes, notarizes and checks the .dmg beside it for people (ADR 0034).
cmd_package() {
  step "Package"
  require_project
  require_signing
  local exported="$BUILD_DIR/$MAC_SCHEME"
  local app="$exported/$APP_NAME.app"
  rm -rf "$BUILD_DIR/release"
  mkdir -p "$BUILD_DIR/release"
  export_mac "$exported"
  [[ -d "$app" ]] || fail "No $APP_NAME.app in ${exported#"$ROOT_DIR"/}"
  notarize_app "$app"
  verify_release "$app"
  local version build
  version="$(defaults read "$app/Contents/Info" CFBundleShortVersionString)"
  build="$(defaults read "$app/Contents/Info" CFBundleVersion)"
  local base="$BUILD_DIR/release/$APP_NAME-$version-$build"
  ditto -c -k --keepParent "$app" "$base.zip"
  make_disk_image "$app" "$base.dmg"
  notarize_file "$base.dmg"
  staple "$base.dmg"
  verify_disk_image "$base.dmg"
  ok "$APP_NAME $version ($build) -> ${base#"$ROOT_DIR"/}.zip and .dmg"
}

# Releases the tagged HEAD from this Mac (ADR 0035): what is published is
# exactly the tagged source, with its changelog notes.
cmd_publish() {
  step "Publish checks"
  require_project
  [[ -z "$(git -C "$ROOT_DIR" status --porcelain)" ]] || fail "The working tree has changes; commit them first."
  local version
  version="$(grep -o 'MARKETING_VERSION = [^;]*' "$XCODE_PROJECT/project.pbxproj" | sort -u | sed 's/MARKETING_VERSION = //')"
  local tag="v$version"
  git -C "$ROOT_DIR" rev-parse --quiet --verify "$tag^{commit}" >/dev/null \
    || fail "No tag $tag; tag the release first: git tag $tag"
  [[ "$(git -C "$ROOT_DIR" rev-parse "$tag^{commit}")" == "$(git -C "$ROOT_DIR" rev-parse HEAD)" ]] \
    || fail "The tag $tag does not point at HEAD."
  "$TOOLS_DIR/release_notes.sh" "$version" >/dev/null
  ok "$APP_NAME $version, tag $tag at HEAD"
  cmd_package
  "$TOOLS_DIR/publish.sh"
}

cmd_export() {
  step "Export"
  require_project
  require_signing
  export_mac "$BUILD_DIR/$MAC_SCHEME"
  ok "$MAC_SCHEME -> build/$MAC_SCHEME"
}

# Number of files and folders in the large fixture.
ICON_SOURCE="$ROOT_DIR/tools/icon/treewise-icon.svg"
ICON_MAC="$ROOT_DIR/Apps/TreewiseMac/Resources/Assets.xcassets/AppIcon.appiconset"
ICON_IOS="$ROOT_DIR/Apps/TreewiseiOS/Resources/Assets.xcassets/AppIcon.appiconset"
ICON_MAC_PIXELS=(16 32 64 128 256 512 1024)
ICON_IOS_PIXELS=1024

# Renders the app icons from the SVG: the macOS sizes with the plate as drawn,
# the iOS icon full bleed, which iOS rounds itself. The file names are the ones
# the sets' Contents.json list.
cmd_icon() {
  step "Icon"
  local pixels
  for pixels in "${ICON_MAC_PIXELS[@]}"; do
    swift "$ROOT_DIR/tools/icon/render.swift" "$ICON_SOURCE" "$ICON_MAC/icon_$pixels.png" "$pixels" \
      || fail "Could not render the ${pixels}px macOS icon"
  done
  swift "$ROOT_DIR/tools/icon/render.swift" "$ICON_SOURCE" "$ICON_IOS/icon_$ICON_IOS_PIXELS.png" \
    "$ICON_IOS_PIXELS" --full-bleed || fail "Could not render the iOS icon"
  ok "Rendered ${#ICON_MAC_PIXELS[@]} macOS sizes and the iOS icon"
}

FIXTURE_FILES=10000
FIXTURE_FOLDERS=12

# Fills build/fixtures/large with files of a few kinds and some folders, for
# checking that a folder with 10,000 files scrolls smoothly (M2).
cmd_fixture() {
  step "Fixture"
  local dir="$BUILD_DIR/fixtures/large" i
  rm -rf "$dir"
  mkdir -p "$dir"
  for ((i = 1; i <= FIXTURE_FOLDERS; i++)); do mkdir "$dir/Folder $i"; done
  local names=("IMG_%d.heic" "Report %d.pdf" "notes-%d.md" "Clip %d.mov" "data_%d.csv")
  for ((i = 1; i <= FIXTURE_FILES; i++)); do
    # shellcheck disable=SC2059 # the names are the format strings
    printf "%d" "$i" >"$dir/$(printf "${names[i % ${#names[@]}]}" "$i")"
  done
  ok "$FIXTURE_FILES files and $FIXTURE_FOLDERS folders in ${dir#"$ROOT_DIR"/}"
}

SANDBOX_DIR="$BUILD_DIR/sandbox"
SANDBOX_TREE="$ROOT_DIR/tools/sandbox/demo-tree.tsv"
SANDBOX_SIZE="8g"

# The mount point of a sandbox volume (HD or T7).
sandbox_mount() { printf "/Volumes/Treewise Sandbox %s" "$1"; }

sandbox_image() { printf "%s/%s.sparseimage" "$SANDBOX_DIR" "$1"; }

sandbox_attached() { hdiutil info | grep -qF "$(sandbox_image "$1")"; }

# The disks of every attached sandbox image, also of an image replaced since
# it was attached, which keeps its path in `hdiutil info`.
sandbox_disks() {
  hdiutil info | awk -v dir="$SANDBOX_DIR/" '
    /^image-path/ { mine = index($0, dir) > 0 }
    mine && /^\/dev\/disk[0-9]+[[:space:]]/ { print $1; mine = 0 }'
}

# Attaches a volume's image and checks it got the volume's own name: with
# that name taken, macOS mounts it as "… 1" and the seed would fill the other.
sandbox_attach() {
  local mounted
  # Without -quiet, hdiutil also warns that attach is deprecated; only that line is dropped.
  mounted="$(hdiutil attach "$(sandbox_image "$1")" 2> >(grep -v "is deprecated" >&2) | awk -F '\t' '/\/Volumes\// { sub(/[[:space:]]+$/, "", $NF); print $NF }')"
  [[ "$mounted" == "$(sandbox_mount "$1")" ]] || {
    hdiutil detach "$mounted" -quiet || true
    fail "Another volume is called $(sandbox_mount "$1"); eject it, then try again"
  }
}

# Fills a folder with `count` clips of `size` MiB each: one written, the rest
# APFS clones of it, so seeding stays fast while a copy to another volume
# still moves every byte and takes long enough to show progress.
# A demo picture at `$1`: a landscape drawn by make_image.py, as PNG, JPEG
# or HEIC after the name's extension.
sandbox_image_file() {
  local target="$1" png
  png="$(mktemp -t treewise-image).png"
  python3 -I "$TOOLS_DIR/sandbox/make_image.py" "${target##*/}" "$png"
  case "${target##*.}" in
    png) cp "$png" "$target" ;;
    heic) sips -s format heic "$png" --out "$target" >/dev/null ;;
    *) sips -s format jpeg "$png" --out "$target" >/dev/null ;;
  esac
  rm -f "$png"
}

sandbox_clips() {
  local folder="$1" size="$2" count="$3" stamp="${4//[-: ]/}" index
  mkdir -p "$folder"
  dd if=/dev/zero of="$folder/Clip_0001.mov" bs=1m count="$size" status=none
  for ((index = 2; index <= count; index++)); do
    cp -c "$folder/Clip_0001.mov" "$folder/$(printf 'Clip_%04d.mov' "$index")"
  done
  touch -t "$stamp" "$folder"/*.mov
}

# Fills new sandbox volumes with the demo tree, then gives everything its date.
sandbox_seed() {
  local path kind modified size count target
  while IFS=$'\t' read -r path kind modified size count; do
    [[ -z "$path" || "$path" == \#* ]] && continue
    target="$(sandbox_mount "${path%%/*}")/${path#*/}"
    case "$kind" in
      folder) mkdir -p "$target" ;;
      clips) sandbox_clips "$target" "$size" "$count" "$modified" ;;
      hidden) mkdir -p "$target"; chflags hidden "$target" ;;
      app) mkdir -p "$target/Contents"; printf "APPL????" >"$target/Contents/PkgInfo" ;;
      image) sandbox_image_file "$target" ;;
      file)
        if [[ "$size" == *k ]]; then
          dd if=/dev/zero of="$target" bs=1k count="${size%k}" status=none
        elif [[ -n "$size" ]]; then
          dd if=/dev/zero of="$target" bs=1m count="$size" status=none
        else
          printf "Treewise sandbox: %s\n" "${target##*/}" >"$target"
        fi ;;
      *) fail "Unknown kind '$kind' in ${SANDBOX_TREE#"$ROOT_DIR"/}" ;;
    esac
  done <"$SANDBOX_TREE"
  while IFS=$'\t' read -r path kind modified _; do
    [[ -z "$path" || "$path" == \#* ]] && continue
    touch -t "${modified//[-: ]/}" "$(sandbox_mount "${path%%/*}")/${path#*/}"
  done <"$SANDBOX_TREE"
}

# Attaches the sandbox volumes, making and filling them first when missing;
# `reset` makes them afresh, `eject` detaches them (ADR 0019).
cmd_sandbox() {
  local action="${1:-attach}" volume disk created=0
  step "Sandbox ($action)"
  if [[ "$action" == eject || "$action" == reset ]]; then
    for disk in $(sandbox_disks); do
      hdiutil detach "$disk" -quiet \
        || fail "Could not detach $disk; quit Treewise and close Finder windows on the sandbox"
    done
    [[ "$action" == eject ]] && { ok "Detached the sandbox volumes"; return; }
    rm -rf "$SANDBOX_DIR"
  fi
  mkdir -p "$SANDBOX_DIR"
  for volume in HD T7; do
    if [[ ! -f "$(sandbox_image "$volume")" ]]; then
      hdiutil create -quiet -size "$SANDBOX_SIZE" -type SPARSE -fs APFS \
        -volname "Treewise Sandbox $volume" "$(sandbox_image "$volume")"
      created=1
    fi
    sandbox_attached "$volume" || sandbox_attach "$volume"
  done
  ((created)) && sandbox_seed
  ok "Attached $(sandbox_mount HD) and $(sandbox_mount T7)"
}

cmd_clean() {
  step "Clean"
  if [[ -d "$SANDBOX_DIR" ]]; then cmd_sandbox eject; fi
  rm -rf "${BUILD_DIR:?}"
  ok "Removed build/"
}

run_command() {
  case "$1" in
    check) timed check cmd_check ;;
    format) timed format cmd_format ;;
    test) timed test cmd_test "${2:-}" ;;
    crossvolume) timed crossvolume cmd_crossvolume ;;
    coverage) timed coverage cmd_coverage ;;
    build) timed build cmd_build ;;
    apptest) timed apptest cmd_apptest "${2:-}" ;;
    iostest) timed iostest cmd_iostest ;;
    package) timed package cmd_package ;;
    export) timed export cmd_export ;;
    publish) timed publish cmd_publish ;;
    screenshots) timed screenshots cmd_screenshots ;;
    fixture) timed fixture cmd_fixture ;;
    sandbox) timed sandbox cmd_sandbox "${2:-}" ;;
    icon) timed icon cmd_icon ;;
    clean) timed clean cmd_clean ;;
    quick) run_command check; run_command test ;;
    verify) run_command check; run_command test; run_command build ;;
    ci) run_command verify; run_command apptest ;;
    all) run_command ci; run_command export ;;
    -h|--help|help) usage; exit 0 ;;
    *) usage; fail "Unknown command: $1" ;;
  esac
}

(($# == 0)) && set -- ci
while (($#)); do
  c="$1"; shift
  if [[ "$c" == run ]]; then
    cmd_run "$@"
    exit 0
  elif [[ ( "$c" == test || "$c" == apptest ) && -n "${1:-}" && "$COMMANDS" != *" $1 "* ]]; then
    # test and apptest take an optional filter as their next word, unless that
    # word is a command.
    run_command "$c" "$1"; shift
  elif [[ "$c" == sandbox && ( "${1:-}" == reset || "${1:-}" == eject ) ]]; then
    run_command "$c" "$1"; shift
  else
    run_command "$c"
  fi
done

step "Summary"
for line in "${SUMMARY[@]}"; do info "$line"; done
ok "Build succeeded"
