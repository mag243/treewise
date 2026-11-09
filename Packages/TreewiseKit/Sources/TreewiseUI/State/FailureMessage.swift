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
        case .archiveReadOnly:
            return String(
                localized: "An archive of this kind can’t be changed. Extract it first.",
                bundle: bundle,
                locale: locale)
        case .unexpected(let description):
            return String(
                localized: "The operation failed: \(description)", bundle: bundle, locale: locale)
        case .notEjected(let id, let reason):
            return String(
                localized: "“\(name(id))” can’t be ejected. \(reason)", bundle: bundle,
                locale: locale)
        case .notFound(let id), .notReadable(let id), .notWritable(let id),
            .alreadyExists(let id), .verificationFailed(let id), .outsideBoundary(let id),
            .trashUnavailable(let id), .notEnoughSpace(let id), .archiveDamaged(let id),
            .archivePasswordProtected(let id), .archiveFormatUnknown(let id),
            .archiveChangedSince(let id):
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
        case .archiveDamaged, .archivePasswordProtected, .archiveFormatUnknown,
            .archiveChangedSince:
            return archiveText(for: failure, name: name, bundle: bundle, locale: locale)
        case .invalidName, .cancelled, .unexpected, .notEjected, .archiveReadOnly:
            preconditionFailure("failure is about one item; text(for:) explains the others")
        }
    }

    /// The explanation of a failure about an archive, naming it.
    private static func archiveText(
        for failure: FileSystemError, name: String, bundle: Bundle, locale: Locale
    ) -> String {
        switch failure {
        case .archivePasswordProtected:
            return String(
                localized: "“\(name)” is protected with a password.", bundle: bundle,
                locale: locale)
        case .archiveChangedSince:
            return String(
                localized: "“\(name)” changed since, so this can’t be undone.", bundle: bundle,
                locale: locale)
        case .archiveFormatUnknown:
            return String(
                localized: "“\(name)” isn’t in a format Treewise can extract.", bundle: bundle,
                locale: locale)
        default:
            return String(
                localized: "“\(name)” is damaged and can’t be extracted.", bundle: bundle,
                locale: locale)
        }
    }

    /// The last path component of an item's identity: its name for the local disk.
    private static func name(_ id: FileItem.ID) -> String {
        id.rawValue.split(separator: "/").last.map(String.init) ?? id.rawValue
    }
}
