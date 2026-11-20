import Foundation
import TreewiseCore
import TreewiseFileSystem

/// How a change another device replaced reads in the safety net (ADR 0144): what it is
/// about, which part, this device's value and the one that holds now.
public struct SyncConflictText: Sendable {
    /// The folder, pattern or template it is about.
    public let title: String
    /// The part of it that both devices changed.
    public let part: String
    /// This device's value, which Restore brings back.
    public let yours: String
    /// The value that holds now.
    public let now: String

    /// The text of `entry`; `names` gives the name of a pattern or template the app knows.
    public init(
        _ entry: SyncConflictStore.Entry, names: (SyncElement) -> String?,
        locale: Locale = .current
    ) {
        let bundle = Bundle.module.localizationBundle(for: locale)
        func text(_ key: String.LocalizationValue) -> String {
            String(localized: key, bundle: bundle, locale: locale)
        }
        let key = entry.conflict.mine.key
        title = Self.title(of: key.element, names: names, text: text)
        part = Self.part(key.part, of: key.element, text: text)
        let isPresence = key.part == SyncKey.exists
        yours = Self.value(entry.conflict.mine.value, isPresence: isPresence, text: text)
        now = Self.value(entry.conflict.winner.value, isPresence: isPresence, text: text)
    }

    private static func title(
        of element: SyncElement, names: (SyncElement) -> String?,
        text: (String.LocalizationValue) -> String
    ) -> String {
        switch element {
        case .folder(let path): path
        case .pattern: names(element) ?? text("A saved pattern")
        case .patternList: text("Saved Patterns")
        case .template: names(element) ?? text("A template")
        case .templateFolder(let template, _): names(.template(template)) ?? text("A template")
        }
    }

    /// The words for the parts named the same in every element.
    private static let partNames: [String: String.LocalizationValue] = [
        SyncKey.exists: "Whether it is there", "name": "Name", "text": "Pattern",
        "place": "Place in the list", "default": "Default pattern", "parent": "Folder it is in",
        "names": "Name settings", "enabledModules": "Add-ons that are on",
        "moduleOrder": "Order of the add-ons", "newFolders": "New folders are offered",
        "madeFrom": "Made from",
    ]

    private static func part(
        _ part: String, of element: SyncElement, text: (String.LocalizationValue) -> String
    ) -> String {
        if case .templateFolder = element, part == "name" { return text("Folder name") }
        if let name = partNames[part] { return text(name) }
        if let module = part.after("module/") { return text("Pattern of \(module)") }
        if let name = part.after("alwaysSkipped/") { return text("Always skips \(name)") }
        return text("A setting of this folder")
    }

    private static func value(
        _ value: JSONValue, isPresence: Bool, text: (String.LocalizationValue) -> String
    ) -> String {
        switch value {
        case .bool(let isOn) where isPresence: return isOn ? text("Kept") : text("Removed")
        case .bool(let isOn): return isOn ? text("On") : text("Off")
        case .null: return text("None")
        case .string(let string): return string
        case .number(let number): return number.formatted()
        case .array(let values):
            return values.map { Self.value($0, isPresence: false, text: text) }.joined(
                separator: ", ")
        case .object(let fields):
            for name in ["text", "template"] {
                if case .string(let string)? = fields[name] { return string }
            }
            return text("Other settings")
        }
    }
}

extension String {
    fileprivate func after(_ prefix: String) -> String? {
        hasPrefix(prefix) ? String(dropFirst(prefix.count)) : nil
    }
}
