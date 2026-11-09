#!/usr/bin/env bash
# Verifies the import rules of ADR 0001 that Package.swift cannot express:
#   - TreewiseCore imports only Foundation (no UI frameworks, no other module).
#   - TreewiseFileSystem imports no UI framework and not TreewiseUI.
#   - TreewiseModuleInterface imports only Foundation and TreewiseCore, and names
#     no way to reach a file, so a module receives data only (ADR 0057).
#   - TreewiseModuleXPC, the module catalog and the modules' service reach no file
#     system or UI code, and the service's entitlements are the App Sandbox alone.
#   - removeItem( appears only in TreewiseFileSystem's FileOperationRunner, the
#     one place that removes a user's file without the Trash (ADR 0004, 0018),
#     and for folders Treewise made itself (ADR 0020, 0074).
# Package.swift already enforces the dependency direction between the modules.
set -euo pipefail
# shellcheck source=tools/lib.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SOURCES="$PACKAGE_DIR/Sources"
UI_FRAMEWORKS='AppKit|UIKit|SwiftUI|Cocoa'

# Prints "file:line: import" for every import in the Swift files under [1].
imports_in() {
  [[ -d "$1" ]] || return 0
  grep -rnE --include='*.swift' '^[[:space:]]*(@[A-Za-z_]+[[:space:]]+)*import[[:space:]]' "$1" || true
}

# Prints the imports under [1] whose module matches the regex [2], relative to ROOT_DIR.
violations() {
  imports_in "$1" | grep -E "import[[:space:]]+(class |struct |enum |protocol |func |var )?($2)([.[:space:]]|$)" |
    sed "s|^$ROOT_DIR/||" || true
}

found=0
report() {
  local rule="$1" lines="$2"
  [[ -n "$lines" ]] || return 0
  printf '%s:\n%s\n' "$rule" "$lines" >&2
  found=1
}

if [[ ! -d "$SOURCES" ]]; then
  info "No Packages/TreewiseKit/Sources yet; dependency check skipped"
  exit 0
fi

core_non_foundation="$(imports_in "$SOURCES/TreewiseCore" |
  grep -vE 'import[[:space:]]+Foundation([.[:space:]]|$)' | sed "s|^$ROOT_DIR/||" || true)"
report "TreewiseCore may import only Foundation" "$core_non_foundation"
report "TreewiseFileSystem may not import a UI framework or TreewiseUI" \
  "$(violations "$SOURCES/TreewiseFileSystem" "$UI_FRAMEWORKS|TreewiseUI")"

interface_imports="$(imports_in "$SOURCES/TreewiseModuleInterface" |
  grep -vE 'import[[:space:]]+(Foundation|TreewiseCore)([.[:space:]]|$)' | sed "s|^$ROOT_DIR/||" || true)"
report "TreewiseModuleInterface may import only Foundation and TreewiseCore" "$interface_imports"
report "TreewiseModuleInterface may not name a way to reach a file" \
  "$(grep -rnE --include='*.swift' '\b(URL|FileManager|FileHandle|FileItem)\b' \
    "$SOURCES/TreewiseModuleInterface" 2>/dev/null | sed "s|^$ROOT_DIR/||" || true)"

# Prints the imports under [1] other than the modules named by the regex [2].
imports_besides() {
  imports_in "$1" | grep -vE "import[[:space:]]+($2)([.[:space:]]|\$)" | sed "s|^$ROOT_DIR/||" || true
}

report "TreewiseModuleXPC may import only Foundation, Synchronization, os, TreewiseCore and TreewiseModuleInterface" \
  "$(imports_besides "$SOURCES/TreewiseModuleXPC" 'Foundation|Synchronization|os|TreewiseCore|TreewiseModuleInterface')"
report "TreewiseFolderPatternModule may import only Foundation, TreewiseCore and TreewiseModuleInterface" \
  "$(imports_besides "$SOURCES/TreewiseFolderPatternModule" 'Foundation|TreewiseCore|TreewiseModuleInterface')"
report "The module catalog may import only TreewiseModuleInterface and TreewiseFolderPatternModule" \
  "$(imports_besides "$ROOT_DIR/Packages/TreewiseModuleCatalog/Sources" 'TreewiseModuleInterface|TreewiseFolderPatternModule')"
# TreewiseCore and TreewiseModuleInterface are for the probe build's module (tools/build.sh probe).
report "The modules' service may import only Foundation, TreewiseCore, the interface, the catalog and TreewiseModuleXPC" \
  "$(imports_besides "$ROOT_DIR/Apps/TreewiseModuleHost" 'Foundation|TreewiseCore|TreewiseModuleInterface|TreewiseModuleCatalog|TreewiseModuleXPC')"

service_entitlements="$ROOT_DIR/Apps/TreewiseModuleHost.entitlements"
if [[ "$(grep -c '<key>' "$service_entitlements" || true)" != "1" ]] \
  || ! grep -q '<key>com.apple.security.app-sandbox</key>' "$service_entitlements"; then
  report "The modules' service may hold only the App Sandbox entitlement" "$service_entitlements"
fi

removals="$(grep -rn --include='*.swift' 'removeItem(' "$SOURCES" "$ROOT_DIR/Apps" 2>/dev/null |
  grep -v "$SOURCES/TreewiseFileSystem/FileOperationRunner.swift:" |
  grep -v "$SOURCES/TreewiseFileSystem/FileCopier.swift:" |
  grep -v "$SOURCES/TreewiseFileSystem/PromiseInbox.swift:" |
  grep -v "$SOURCES/TreewiseFileSystem/Archives/ArchiveWorkspace.swift:" |
  grep -v "$SOURCES/TreewiseTestSupport/" | sed "s|^$ROOT_DIR/||" || true)"
report "Only FileOperationRunner, its FileCopier, PromiseInbox and ArchiveWorkspace may call removeItem (ADR 0004, 0020, 0074); use TrashService" \
  "$removals"

((found == 0)) || exit 1
