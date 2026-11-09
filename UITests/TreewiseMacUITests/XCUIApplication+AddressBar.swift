import XCTest

extension XCUIApplication {
    /// Goes to `path`, relative to the window's folder, by typing it in the address bar one
    /// key at a time; a tilde would be a dead key on some keyboard layouts.
    @MainActor
    func go(to path: String, timeout: TimeInterval) {
        let folder = String(path.split(separator: "/").last ?? "")
        typeKey("l", modifierFlags: .command)
        XCTAssertTrue(textFields["Address"].waitForExistence(timeout: timeout))
        typeKey("a", modifierFlags: .command)
        for character in path + "/" {
            let key = String(character)
            let isUpper = key != key.lowercased()
            typeKey(key.lowercased(), modifierFlags: isUpper ? .shift : [])
        }
        typeKey(.return, modifierFlags: [])
        XCTAssertTrue(
            windows(titled: folder).firstMatch.waitForExistence(timeout: timeout),
            "the window shows \(folder)")
    }
}
