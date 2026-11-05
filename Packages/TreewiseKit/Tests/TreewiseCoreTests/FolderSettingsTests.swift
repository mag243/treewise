import Foundation
import Testing
import TreewiseCore

/// How settings find their folder through the id on it (ADR 0057).
@Suite struct FolderSettingsTests {
    private func place(
        idOnFolder: String? = "id", path: String = "/new", recordedPath: String? = nil,
        idAtRecordedPath: String? = nil
    ) -> FolderSettings.Place {
        FolderSettings.place(
            idOnFolder: idOnFolder, path: path, recordedPath: recordedPath,
            idAtRecordedPath: idAtRecordedPath)
    }

    @Test func aFolderWithoutAnIDIsNew() {
        #expect(place(idOnFolder: nil) == .noID)
    }

    @Test func anIDNobodyRecordedIsSomeoneElses() {
        #expect(place(recordedPath: nil) == .unknownID)
    }

    @Test func theSamePathIsTheSameFolder() {
        #expect(place(path: "/old", recordedPath: "/old", idAtRecordedPath: "id") == .same)
    }

    @Test func anEmptyOldPathMeansMoved() {
        #expect(place(recordedPath: "/old", idAtRecordedPath: nil) == .moved)
    }

    @Test func anotherFolderAtTheOldPathMeansMoved() {
        #expect(place(recordedPath: "/old", idAtRecordedPath: "other") == .moved)
    }

    @Test func theSameIDStillAtTheOldPathMeansACopy() {
        #expect(place(recordedPath: "/old", idAtRecordedPath: "id") == .copy)
    }

    @Test func settingsSurviveEncoding() throws {
        let settings = FolderSettings(enabledModules: ["a"], templates: ["a": "{number}"])
        let data = try JSONEncoder().encode(settings)
        #expect(try JSONDecoder().decode(FolderSettings.self, from: data) == settings)
    }
}
