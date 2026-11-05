import Foundation
import TreewiseCore

/// The text the window shows when an operation fails, naming the item.
public enum FailureMessage {
    /// Returns the explanation of `failure` in the language of `locale`.
    public static func text(for failure: FileSystemError, locale: Locale) -> String {
        let bundle = Bundle.module.localizationBundle(for: locale)
        switch failure {
        case .invalidName(let name):
            return String(
                localized: "The name “\(name)” can’t be used.", bundle: bundle, locale: locale)
        case .cancelled:
            return String(localized: "The operation was stopped.", bundle: bundle, locale: locale)
        case .unexpected(let description):
            return String(
                localized: "The operation failed: \(description)", bundle: bundle, locale: locale)
        case .notEjected(let id, let reason):
            return String(
                localized: "“\(name(id))” can’t be ejected. \(reason)", bundle: bundle,
                locale: locale)
        case .notFound(let id), .notReadable(let id), .notWritable(let id),
            .alreadyExists(let id), .verificationFailed(let id), .outsideBoundary(let id),
            .trashUnavailable(let id), .notEnoughSpace(let id):
            return itemText(for: failure, name: name(id), bundle: bundle, locale: locale)
        }
    }

    /// The explanation of a failure about one item, naming it.
    private static func itemText(
        for failure: FileSystemError, name: String, bundle: Bundle, locale: Locale
    ) -> String {
        switch failure {
        case .notFound:
            return String(localized: "“\(name)” can’t be found.", bundle: bundle, locale: locale)
        case .notReadable:
            return String(
                localized: "You don’t have permission to see “\(name)”.", bundle: bundle,
                locale: locale)
        case .notWritable:
            return String(
                localized: "You don’t have permission to change “\(name)”.", bundle: bundle,
                locale: locale)
        case .alreadyExists:
            return String(
                localized: "An item named “\(name)” already exists in this location.",
                bundle: bundle, locale: locale)
        case .verificationFailed:
            return String(
                localized: "“\(name)” could not be copied completely, so it stayed where it was.",
                bundle: bundle, locale: locale)
        case .outsideBoundary:
            return String(
                localized: "“\(name)” is outside the folders Treewise may use now.",
                bundle: bundle, locale: locale)
        case .trashUnavailable:
            return String(
                localized: "“\(name)” can’t be moved to the Trash because its volume has no Trash.",
                bundle: bundle, locale: locale)
        case .notEnoughSpace:
            return String(
                localized: "There isn’t enough space to copy “\(name)”.", bundle: bundle,
                locale: locale)
        case .invalidName, .cancelled, .unexpected, .notEjected:
            preconditionFailure("failure is about one item; text(for:) explains the others")
        }
    }

    /// The last path component of an item's identity: its name for the local disk.
    private static func name(_ id: FileItem.ID) -> String {
        id.rawValue.split(separator: "/").last.map(String.init) ?? id.rawValue
    }
}
