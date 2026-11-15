import Foundation
import TreewiseCore
import TreewiseFileSystem
import TreewiseModuleInterface
import os

/// What the review overview needs from outside (ADR 0057).
public struct NameReviewDependencies: Sendable {
    /// Builds what a module may see of an item: a file's facts and declared contents.
    public typealias MakeRequest =
        @Sendable (FileItem, [FileItem], Set<ModuleContentKind>) async -> NameRequest
    /// Saves a pattern under a name; returns why not, or nil when it did (ADR 0068).
    public typealias SavePattern = @MainActor @Sendable (String, String) -> SavedPatterns.Problem?
    /// Gives a saved pattern another text.
    public typealias ChangeSavedPattern = @MainActor @Sendable (SavedPattern.ID, String) -> Void

    let operations: any FileOperating
    let host: any AddOnHosting
    let store: any FolderSettingsStoring
    /// The user's pattern for a folder without one.
    let defaultPattern: String
    /// What Approve All does with a name that holds personal data.
    let personalDataInNames: PersonalDataInNames
    let makeRequest: MakeRequest
    /// What Settings decides for the add-ons across the app (ADR 0070).
    let addOns: AddOnPreferences
    /// The licence keys and the trials' dates, for paid modules (ADR 0071, ADR 0088).
    let licence: @MainActor @Sendable () -> LicenceContext
    /// The user's saved patterns (ADR 0068).
    let savedPatterns: @MainActor @Sendable () -> SavedPatterns
    let savePattern: SavePattern
    /// Gives a saved pattern another text.
    let changeSavedPattern: ChangeSavedPattern

    /// Creates the dependencies.
    public init(
        operations: any FileOperating, host: any AddOnHosting,
        store: any FolderSettingsStoring, defaultPattern: String,
        personalDataInNames: PersonalDataInNames = .leaveOutOfApproveAll,
        addOns: AddOnPreferences = AddOnPreferences(),
        licence: @escaping @MainActor @Sendable () -> LicenceContext = { .none },
        savedPatterns: @escaping @MainActor @Sendable () -> SavedPatterns = { .examples() },
        savePattern: @escaping SavePattern = { _, _ in nil },
        changeSavedPattern: @escaping ChangeSavedPattern = { _, _ in },
        makeRequest: @escaping MakeRequest
    ) {
        self.operations = operations
        self.host = host
        self.store = store
        self.defaultPattern = defaultPattern
        self.personalDataInNames = personalDataInNames
        self.makeRequest = makeRequest
        self.addOns = addOns
        self.licence = licence
        self.savedPatterns = savedPatterns
        self.savePattern = savePattern
        self.changeSavedPattern = changeSavedPattern
    }
}
