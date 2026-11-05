#!/bin/bash
# Run Script build phase that stamps CFBundleVersion in the built Info.plist
# with a monotonic, App Store-valid date and counter (ADR 0013).
#
# Format: YYYY.MMDD.HHMMNN (three period-separated integers)
#   YYYY   = year
#   MMDD   = month and day, zero-padded
#   HHMMNN = hour, minute, and a two-digit build counter within that minute
#
# The counter starts at 01 each minute, so a second build in the same minute
# gets ...HHMM02: greater than ...HHMM01 and smaller than the next minute's
# ...01. CFBundleVersion therefore increases strictly, which the App Store
# requires, without seconds in the readable part.
#
# The counter lives in $SRCROOT/.build-counter (gitignored) as
# "<YYYYMMDDHHMM>|<counter>", shared by the macOS and iOS targets: a build of
# both in one minute gives one target ...01 and the other ...02.
#
# On a target with the build setting COPYRIGHT_HOLDER it also stamps
# NSHumanReadableCopyright as "© <year of the build> <holder>" (ADR 0048).
#
# The phase needs ENABLE_USER_SCRIPT_SANDBOXING = NO on its target, because
# the sandbox blocks writing the counter file.

set -euo pipefail

COUNTER_FILE="${SRCROOT}/.build-counter"
MAX_BUILDS_PER_MINUTE=99

# The finished product's plist is the primary path. Xcode sometimes runs this
# phase before the plist lands there (GENERATE_INFOPLIST_FILE = YES writes it
# to INFOPLIST_OUTPUT_PATH first); later phases copy whichever one is stamped.
PLIST=""
for candidate in \
    "${TARGET_BUILD_DIR:-}/${INFOPLIST_PATH:-}" \
    "${INFOPLIST_OUTPUT_PATH:-}" \
    "${BUILT_PRODUCTS_DIR:-}/${INFOPLIST_PATH:-}"; do
    if [ "${candidate}" = "/" ] || [ -z "${candidate}" ]; then
        continue
    fi
    if [ -f "${candidate}" ]; then
        PLIST="${candidate}"
        break
    fi
done

if [ -z "${PLIST}" ]; then
    echo "warning: Info.plist not found at ${TARGET_BUILD_DIR:-}/${INFOPLIST_PATH:-} (or the fallbacks), build not stamped"
    exit 0
fi

current_minute=$(date +"%Y%m%d%H%M")

stored_minute=""
stored_counter=0
if [ -f "${COUNTER_FILE}" ]; then
    IFS='|' read -r stored_minute stored_counter < "${COUNTER_FILE}" || true
fi

if [ "${stored_minute}" = "${current_minute}" ]; then
    counter=$((stored_counter + 1))
else
    counter=1
fi

if [ "${counter}" -gt "${MAX_BUILDS_PER_MINUTE}" ]; then
    echo "error: build counter overflow (more than ${MAX_BUILDS_PER_MINUTE} builds in the minute ${current_minute})" >&2
    exit 1
fi

echo "${current_minute}|${counter}" > "${COUNTER_FILE}"

bundle_version="$(date +"%Y.%m%d.%H%M")$(printf "%02d" "${counter}")"

copyright=""
if [ -n "${COPYRIGHT_HOLDER:-}" ]; then
    copyright="© $(date +"%Y") ${COPYRIGHT_HOLDER}"
fi

plutil -convert xml1 "${PLIST}"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${bundle_version}" "${PLIST}"
if [ -n "${copyright}" ]; then
    plutil -replace NSHumanReadableCopyright -string "${copyright}" "${PLIST}"
fi
plutil -convert binary1 "${PLIST}"

# Read the value back: if Xcode regenerates the plist after this phase,
# CFBundleVersion falls back to CURRENT_PROJECT_VERSION ("1"). Fail the build
# rather than ship an unstamped one.
actual=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "${PLIST}" 2>/dev/null || echo "<missing>")
if [ "${actual}" != "${bundle_version}" ]; then
    echo "error: stamp verification failed: CFBundleVersion is '${actual}', expected '${bundle_version}' in ${PLIST}" >&2
    exit 1
fi

if [ -n "${copyright}" ]; then
    actual=$(/usr/libexec/PlistBuddy -c "Print :NSHumanReadableCopyright" "${PLIST}" 2>/dev/null || echo "<missing>")
    if [ "${actual}" != "${copyright}" ]; then
        echo "error: stamp verification failed: NSHumanReadableCopyright is '${actual}', expected '${copyright}' in ${PLIST}" >&2
        exit 1
    fi
fi

echo "stamped CFBundleVersion=${bundle_version} into ${PLIST}"
