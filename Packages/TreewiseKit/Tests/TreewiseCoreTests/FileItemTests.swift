import Foundation
import Testing
import TreewiseCore

@Suite struct FileItemTests {
    @Test func takesContainerAndMovabilityFromItsKind() {
        let folder = FileItem(id: "projects", name: "Projects", kind: .folder, volume: "hd")
        let volume = FileItem(id: "usb", name: "SAMSUNG T7", kind: .volume, volume: "usb")

        #expect(folder.isContainer && folder.isMovable)
        #expect(volume.isContainer && !volume.isMovable)
    }

    @Test func identifiersCompareByTheirRawValue() {
        #expect(FileItem.ID("a") == FileItem.ID("a"))
        #expect(FileItem.ID("a") != FileItem.ID("b"))
        #expect(VolumeID("hd").description == "hd")
    }

    @Test func thisMacIsATopLevelLocationOfItsOwn() {
        let thisMac = FileItem.computer(locale: Locale(identifier: "en"))
        #expect(thisMac.id == .computer)
        #expect(thisMac.kind == .computer)
        #expect(thisMac.parentID == nil)
        #expect(thisMac.name == "This Mac")
    }

    @Test func itemsCannotBeEjectedUnlessTheProviderSaysSo() {
        #expect(!FileItem(id: "usb", name: "T7", kind: .volume, volume: "usb").isEjectable)
    }
}
