import Testing
import TreewiseCore

/// Personal data in a proposed name (ADR 0060).
@Suite struct PersonalDataTests {
    @Test(arguments: [
        ("Invoice jan.de-vries@example.com", PersonalData.emailAddress),
        ("Statement NL91ABNA0417164300", .iban),
        ("Statement NL91 ABNA 0417 1643 00 March", .iban),
        ("Card 4111 1111 1111 1111", .paymentCard),
        ("Card 4111-1111-1111-1111", .paymentCard),
        ("Call +31 6 12345678", .phoneNumber),
        ("Call 06-12345678", .phoneNumber),
        ("Office 020 123 4567", .phoneNumber),
        ("Office (020) 123 4567", .phoneNumber),
    ])
    func findsPersonalData(_ name: String, kind: PersonalData) {
        #expect(PersonalData.found(in: name) == [kind])
    }

    @Test(arguments: [
        "2026.08.14 Holiday - Beach",
        "Invoice F26009",
        "Order 26G0320014-1",
        "Scan 20260814",
        "Order 1234567",
        "Amount 1.234,56",
        "Report v2.0 (final)",
        "Meeting 14-08-2026",
        // The check digits do not add up.
        "Statement NL91ABNA0417164301",
        "Card 4111 1111 1111 1112",
    ])
    func leavesOtherNamesAlone(_ name: String) {
        #expect(PersonalData.found(in: name).isEmpty)
    }

    @Test func anIBANIsNotAlsoAPhoneNumber() {
        // Its last groups, `0417 1643 00`, look like one on their own.
        #expect(PersonalData.found(in: "NL91 ABNA 0417 1643 00") == [.iban])
    }

    @Test func findsEachKindOnce() {
        let name = "a@example.com b@example.com 06-12345678 NL91ABNA0417164300"
        #expect(PersonalData.found(in: name) == [.emailAddress, .iban, .phoneNumber])
    }
}
