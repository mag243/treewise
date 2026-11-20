import Foundation
import Testing
import TreewiseCore

/// A folder's settings as the parts that merge on their own (ADR 0144).
@Suite struct FolderSettingsPartsTests {
    private static var full: FolderSettings {
        var settings = FolderSettings(
            enabledModules: ["dates", "advanced"], templates: ["dates": "{date} {text}"])
        settings.moduleOrder = ["advanced", "dates"]
        settings.savedPatternLinks = ["dates": SavedPatternLink(id: "p1", version: 2)]
        settings.alwaysSkipped = ["a.pdf", "b.pdf"]
        settings.newFolders = .template(id: "t1")
        settings.templateBarClosed = true
        settings.missingFoldersClosed = [["2026", "Tax"]]
        settings.offersNoMissingFolders = true
        settings.namesKeptApart = [["tax", "taxes"]]
        settings.madeFrom = ["t1", "t2"]
        return settings
    }

    @Test func readsBackFromItsParts() {
        #expect(FolderSettings(syncParts: Self.full.syncParts) == Self.full)
    }

    @Test func aModulesTemplateAndThePatternItCameFromAreOnePart() {
        let parts = Self.full.syncParts
        #expect(parts["module/dates"] != nil)
        #expect(!parts.keys.contains { $0.hasPrefix("templates") || $0.hasPrefix("savedPattern") })
    }

    @Test func eachSkippedFileIsAPartOfItsOwn() {
        var one = Self.full
        one.alwaysSkipped.insert("c.pdf")
        let changes = SyncParts.changes(
            of: .folder("X"), from: Self.full.syncParts, to: one.syncParts)
        #expect(changes == [SyncKey(.folder("X"), "alwaysSkipped/c.pdf"): .bool(true)])
    }

    @Test func savingTheSameSettingsAgainChangesNoPart() {
        let again =
            FolderSettings(syncParts: Self.full.syncParts)
            ?? FolderSettings(
                enabledModules: [], templates: [:])
        #expect(
            SyncParts.changes(of: .folder("X"), from: Self.full.syncParts, to: again.syncParts)
                .isEmpty)
    }

    @Test func twoDevicesSkippingDifferentFilesKeepBoth() {
        var mac = Self.full.syncParts
        var ipad = Self.full.syncParts
        mac["alwaysSkipped/mac.pdf"] = .bool(true)
        ipad["alwaysSkipped/ipad.pdf"] = .bool(true)
        let merged = mac.merging(ipad) { first, _ in first }
        let settings = FolderSettings(syncParts: merged)
        #expect(settings?.alwaysSkipped.isSuperset(of: ["mac.pdf", "ipad.pdf"]) == true)
    }

    @Test func partsItDoesNotKnowAreLeftOut() {
        var parts = Self.full.syncParts
        parts["somethingNew"] = .string("x")
        #expect(FolderSettings(syncParts: parts) == Self.full)
    }
}
