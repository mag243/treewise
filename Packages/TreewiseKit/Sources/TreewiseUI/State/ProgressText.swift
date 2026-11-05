import Foundation
import TreewiseCore

/// The line of the progress panel: "Copying “Clip_0042.mov” — 84 MB of 6 GB",
/// with sizes in decimal units as the list shows them (ADR 0021).
public enum ProgressText {
    /// Returns the text for `progress` in the language of `locale`; while the
    /// transfer `isPaused`, it says so instead of naming the file (ADR 0026).
    public static func text(
        for progress: OperationProgress, isPaused: Bool = false, locale: Locale
    ) -> String {
        let bundle = Bundle.module.localizationBundle(for: locale)
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

    private static func size(_ bytes: Int64, _ locale: Locale) -> String {
        bytes.formatted(.byteCount(style: .file).locale(locale))
    }
}
