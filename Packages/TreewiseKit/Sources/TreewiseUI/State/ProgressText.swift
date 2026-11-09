import Foundation
import TreewiseCore

/// The line of the progress panel: "Copying “Clip_0042.mov” — 84 MB of 6 GB",
/// with sizes in decimal units as the list shows them (ADR 0021), or with the
/// entries of an archive (ADR 0074).
public enum ProgressText {
    /// Returns the text for `progress` in the language of `locale`; while the
    /// transfer `isPaused`, it says so instead of naming the file (ADR 0026).
    public static func text(
        for progress: OperationProgress, isPaused: Bool = false, locale: Locale
    ) -> String {
        let bundle = Bundle.module.localizationBundle(for: locale)
        guard progress.kind == .copying else {
            return archiveText(for: progress, isPaused: isPaused, bundle: bundle, locale: locale)
        }
        let done = size(progress.completedBytes, locale)
        let total = size(progress.totalBytes, locale)
        if isPaused {
            return String(localized: "Paused — \(done) of \(total)", bundle: bundle, locale: locale)
        }
        guard let name = progress.currentName else {
            return String(
                localized: "Copying — \(done) of \(total)", bundle: bundle, locale: locale)
        }
        return String(
            localized: "Copying “\(name)” — \(done) of \(total)", bundle: bundle, locale: locale)
    }

    /// The line for an archive operation, which counts entries (ADR 0074).
    private static func archiveText(
        for progress: OperationProgress, isPaused: Bool, bundle: Bundle, locale: Locale
    ) -> String {
        let (done, total) = (progress.completedBytes, progress.totalBytes)
        if isPaused {
            return String(
                localized: "Paused — \(done) of \(total) items", bundle: bundle, locale: locale)
        }
        let isExtracting = progress.kind == .extracting
        guard total > 0, let name = progress.currentName else {
            return isExtracting
                ? String(localized: "Extracting…", bundle: bundle, locale: locale)
                : String(localized: "Compressing…", bundle: bundle, locale: locale)
        }
        return isExtracting
            ? String(
                localized: "Extracting “\(name)” — \(done) of \(total) items", bundle: bundle,
                locale: locale)
            : String(
                localized: "Compressing “\(name)” — \(done) of \(total) items", bundle: bundle,
                locale: locale)
    }

    private static func size(_ bytes: Int64, _ locale: Locale) -> String {
        bytes.formatted(.byteCount(style: .file).locale(locale))
    }
}
