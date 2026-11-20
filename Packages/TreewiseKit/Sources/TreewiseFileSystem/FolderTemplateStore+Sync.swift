import Foundation
import TreewiseCore
import os

/// What the user changed in the templates, told to a sync in order (ADR 0144).
public enum FolderTemplateNotice: Hashable, Sendable {
    case saved(FolderTemplate)
    case deleted(id: String)
}

extension FolderTemplateStore {
    private static let syncLogger = Logger(subsystem: LogSubsystem.name, category: "Sync")

    /// Tells `handle` of every change the user makes from now on, one at a time and in
    /// order; a change taken over from another device is not told.
    public func tellChanges(to handle: @escaping @Sendable (FolderTemplateNotice) async -> Void) {
        notices?.finish()
        notices = NoticeLine(handle: handle)
    }

    /// Returns once every change told so far has been handled.
    public func changesTold() async {
        await notices?.told()
    }

    /// Stops telling changes.
    public func stopTellingChanges() {
        notices?.finish()
        notices = nil
    }

    /// Takes over another device's change to the template `id`, without telling it: the
    /// template saved, or its file put in the Trash when nil.
    public func takeOver(_ template: FolderTemplate?, id: String) {
        let telling = notices
        notices = nil
        defer { notices = telling }
        do {
            if let template {
                try save(template)
            } else if FileManager.default.fileExists(atPath: file(of: id).path) {
                try delete(id: id)
            }
        } catch {
            Self.syncLogger.error("Template not taken over: \(error.localizedDescription)")
        }
    }
}
