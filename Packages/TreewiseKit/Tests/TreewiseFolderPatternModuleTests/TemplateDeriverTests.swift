import Testing
import TreewiseCore
import TreewiseFolderPatternModule

/// Recognizing a pattern in a folder's names (ADR 0057). The names are invented, in the
/// shapes real folders have.
@Suite struct TemplateDeriverTests {
    private func derive(_ names: [String], folder: String = "Documents") -> String? {
        TemplateDeriver.template(fromNames: names, folderName: folder)
    }

    private static let taxes = [
        "2026.01.16 Taxes - VAT 2025.Q4.pdf", "2026.01.21 Taxes - Payroll 2025.12.pdf",
        "2026.02.18 Taxes - Payroll 2026.01.pdf", "2026.04.16 Taxes - VAT 2026.Q1.pdf",
    ]
    private static let project = [
        "2025.03.17 Green Advice - Offer survey - 9 Oak Lane.pdf",
        "2025.07.31 Purchase agreement 9 Oak Lane.pdf",
        "2025.11.04 Nature Co - P25024 - Quick scan 9 Oak Lane.pdf",
        "2026.03.19 Municipality - Final advice.pdf",
        "2026.06.17 Bank overview.png",
    ]

    @Test func findsADateAndWhatEveryNameShares() {
        #expect(derive(Self.taxes) == "{date:yyyy.MM.dd} Taxes - {text}")
    }

    @Test func findsOnlyTheDateWhenNothingElseIsShared() {
        #expect(derive(Self.project) == "{date:yyyy.MM.dd} {text}")
    }

    @Test func toleratesAFewNamesThatDoNotFollow() {
        let names = Self.project + ["Budget tracker.xlsx"]
        #expect(derive(names) == "{date:yyyy.MM.dd} {text}")
    }

    @Test(arguments: [
        ("2026-11-02", "{date:yyyy-MM-dd}"), ("02-11-2026", "{date:dd-MM-yyyy}"),
        ("20261102", "{date:yyyyMMdd}"), ("02.11.2026", "{date:dd.MM.yyyy}"),
    ])
    func recognizesDateFormats(_ date: String, _ field: String) {
        let names = ["a", "b", "c"].map { "\(date) \($0).pdf" }
        #expect(derive(names) == "\(field) {text}")
    }

    @Test func aDateThatDoesNotExistIsNoDate() {
        #expect(derive(["2026.13.45 a.pdf", "2026.14.46 b.pdf", "2026.15.47 c.pdf"]) == nil)
    }

    @Test func findsAWordAndANumber() {
        #expect(derive(["Scan 12.pdf", "Scan 13.pdf", "Scan 14.pdf"]) == "Scan {seq}")
    }

    @Test func findsTheFolderAndANumber() {
        let names = ["Holiday 2026 01.heic", "Holiday 2026 02.heic", "Holiday 2026 03.heic"]
        #expect(derive(names, folder: "Holiday 2026") == "{folder} {seq}")
    }

    @Test func findsADateAndTheFolder() {
        let names = [
            "2026.08.14 Holiday 2026 - a.heic", "2026.08.15 Holiday 2026 - b.heic",
            "2026.08.16 Holiday 2026 - c.heic",
        ]
        #expect(derive(names, folder: "Holiday 2026") == "{date:yyyy.MM.dd} {folder} - {text}")
    }

    @Test func findsADateAndTheFolderBetweenDashes() {
        let names = [
            "2026.08.14 - Holiday 2026 - a.heic", "2026.08.15 - Holiday 2026 - b.heic",
            "2026.08.16 - Holiday 2026 - c.heic",
        ]
        #expect(
            derive(names, folder: "Holiday 2026") == "{date:yyyy.MM.dd} - {folder} - {text}")
    }

    @Test func findsNoPatternInVariedNames() {
        #expect(derive(["notes.txt", "Beach.jpg", "Budget tracker.xlsx", "letter.pdf"]) == nil)
    }

    @Test func needsEnoughNames() {
        #expect(derive(["2026.01.01 a.pdf", "2026.01.02 b.pdf"]) == nil)
        #expect(derive([]) == nil)
    }

    @Test func aMinorityIsNotEnough() {
        let names = ["2026.01.01 a.pdf", "2026.01.02 b.pdf", "c.pdf", "d.pdf", "e.pdf"]
        #expect(derive(names) == nil)
    }

    @Test func halfIsNotEnough() {
        let names = [
            "2026.01.01 a.pdf", "2026.01.02 b.pdf", "2026.01.03 c.pdf", "d.pdf", "e.pdf", "f.pdf",
        ]
        #expect(derive(names) == nil)
    }

    @Test func aMajorityOfAtLeastThreeIsEnough() {
        let names = ["2026.01.01 a.pdf", "2026.01.02 b.pdf", "2026.01.03 c.pdf", "d.pdf", "e.pdf"]
        #expect(derive(names) == "{date:yyyy.MM.dd} {text}")
    }

    @Test func oneOddNameInFourLeavesThePattern() {
        let names = ["Scan 1.pdf", "Scan 2.pdf", "Scan 3.pdf", "Lighthouse.heic"]
        #expect(derive(names) == "Scan {seq}")
    }

    @Test func aSharedWordNeedsAMajorityOfTheNames() {
        let names = [
            "2026.01.01 Taxes - a.pdf", "2026.01.02 Taxes - b.pdf", "2026.01.03 Bank - c.pdf",
            "2026.01.04 Bank - d.pdf",
        ]
        #expect(derive(names) == "{date:yyyy.MM.dd} {text}")
    }

    @Test func aSharedWordOfAMajorityIsKept() {
        let names = [
            "2026.01.01 Taxes - a.pdf", "2026.01.02 Taxes - b.pdf", "2026.01.03 Taxes - c.pdf",
            "2026.01.04 Bank - d.pdf",
        ]
        #expect(derive(names) == "{date:yyyy.MM.dd} Taxes - {text}")
    }

    @Test func ignoresExtensionsWhenLooking() {
        #expect(derive(["Scan 1.pdf", "Scan 2.PNG", "Scan 3"]) == "Scan {seq}")
    }

    @Test func whatItDerivesAlwaysParses() throws {
        for names in [Self.taxes, Self.project, ["Scan: 1.pdf", "Scan: 2.pdf", "Scan: 3.pdf"]] {
            guard let text = derive(names) else { continue }
            #expect(throws: Never.self) {
                try NameTemplate.parse(text, fields: FolderPatternModule.fields + [.folder]).get()
            }
        }
    }

    @Test func comesBackAfterApplyingATemplate() throws {
        let text = "{date:yyyy.MM.dd} Taxes - {text}"
        let template = try NameTemplate.parse(text, fields: FolderPatternModule.fields).get()
        let names = (1...5).compactMap { day in
            template.name(from: [
                "date": .date(year: 2026, month: 3, day: day), "text": .text("Item \(day)"),
            ])
        }
        #expect(derive(names) == text)
    }
}
