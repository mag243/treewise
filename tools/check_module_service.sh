#!/usr/bin/env bash
# Fails unless the app at [1] holds the modules' service with the App Sandbox as its
# only entitlement. The promise to users rests on that signed result (ADR 0057).
set -euo pipefail
# shellcheck source=tools/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

service="${1:?Usage: check_module_service.sh <app>}/Contents/XPCServices/TreewiseModuleHost.xpc"
[[ -d "$service" ]] || fail "No modules' service in the app"
entitlements="$(codesign -d --entitlements - "$service" 2>/dev/null | grep '\[Key\]' || true)"
[[ "$(awk '{print $2}' <<<"$entitlements")" == "com.apple.security.app-sandbox" ]] \
  || fail "The modules' service must hold only the App Sandbox entitlement; it holds: ${entitlements:-nothing}"
ok "The modules' service holds only the App Sandbox entitlement"
