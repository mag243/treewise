import AppKit
import TreewiseCore

/// The context menu of Settings' list of name patterns (ADR 0105): Make Default, Duplicate
/// and Delete, for the pattern clicked.
extension SavedPatternsSection {
    func patternMenuItems() -> [NSMenuItem] {
        guard let pattern = selected else { return [] }
        let patterns = settings.savedPatterns
        let makeDefault: () -> Void = { [weak self] in
            self?.settings.savedPatterns.makeDefault(pattern.id)
        }
        let duplicate: () -> Void = { [weak self] in
            guard let self, let copy = settings.savedPatterns.duplicate(pattern.id) else { return }
            choose(copy)
        }
        let delete: () -> Void = { [weak self] in self?.removeSelected() }
        return [
            ClosureMenuItem(
                String(localized: "Make Default"), symbol: "checkmark",
                enabled: pattern.id != patterns.defaultPattern.id, handler: makeDefault),
            ClosureMenuItem(
                String(localized: "Duplicate"), symbol: "plus.square.on.square", handler: duplicate),
            .separator(),
            ClosureMenuItem(
                String(localized: "Delete"), symbol: "trash", enabled: patterns.patterns.count > 1,
                handler: delete),
        ]
    }
}
