import Foundation
import Testing
import TreewiseFileSystem

/// Runs git for a test, apart from the user's own settings, with a name to commit under;
/// `input` goes to git's standard input, as `fast-import` reads it.
@discardableResult
func git(_ arguments: [String], in folder: String, input: Data? = nil) throws -> String {
    let tool = try #require(GitTool.find())
    let output = Pipe()
    let process = Process()
    process.executableURL = URL(fileURLWithPath: tool.executable)
    process.arguments =
        ["-C", folder, "-c", "user.name=Test", "-c", "user.email=test@example.com"] + arguments
    process.environment = [
        "GIT_CONFIG_GLOBAL": "/dev/null", "GIT_CONFIG_NOSYSTEM": "1", "LC_ALL": "C",
    ]
    process.standardOutput = output
    process.standardError = output
    let feed = Pipe()
    if input != nil { process.standardInput = feed }
    try process.run()
    if let input {
        feed.fileHandleForWriting.write(input)
        try feed.fileHandleForWriting.close()
    }
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    let text = String(bytes: data, encoding: .utf8) ?? ""
    guard process.terminationStatus == 0 else {
        throw GitTestFailure(arguments: arguments, output: text)
    }
    return text
}

struct GitTestFailure: Error, CustomStringConvertible {
    let arguments: [String]
    let output: String
    var description: String { "git \(arguments.joined(separator: " ")): \(output)" }
}
