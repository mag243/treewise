import Foundation
import Testing
import TreewiseCore

/// Reading `git diff` and `git show` output, `--no-color` and renames found (`-M`), into
/// the changes a history shows (ADR 0153). The lines are copied from git 2.56's output on
/// scratch repositories.
@Suite struct GitDiffParsingTests {
    private func diff(_ lines: String...) -> GitDiff {
        GitDiff(unified: Data((lines.joined(separator: "\n") + "\n").utf8))
    }

    private let changed = [
        "diff --git a/Notes.md b/Notes.md",
        "index 4c7442b..8fe8312 100644",
        "--- a/Notes.md",
        "+++ b/Notes.md",
        "@@ -1,3 +1,3 @@ # Notes",
        " one",
        "-two",
        "+three",
        " four",
    ]

    private func only(_ diff: GitDiff) throws -> GitFileDiff {
        try #require(diff.files.count == 1)
        return diff.files[0]
    }

    @Test func readsAChangedFilesLines() throws {
        let file = try only(GitDiff(unified: Data((changed.joined(separator: "\n") + "\n").utf8)))
        #expect(file.path == "Notes.md")
        #expect(file.change == .modified)
        #expect(!file.isBinary)
        let hunk = try #require(file.hunks.first)
        #expect(hunk.oldStart == 1)
        #expect(hunk.newStart == 1)
        #expect(hunk.section == "# Notes")
        #expect(hunk.lines.map(\.kind) == [.context, .removed, .added, .context])
        #expect(hunk.lines.map(\.text) == ["one", "two", "three", "four"])
    }

    @Test func numbersEachLineOldAndNew() throws {
        let lines = try #require(
            try only(
                diff("--- a/a.txt", "+++ b/a.txt", "@@ -10,3 +12,3 @@", " a", "-b", "+c", " d")
            )
            .hunks.first?.lines)
        #expect(lines.map(\.oldNumber) == [10, 11, nil, 12])
        #expect(lines.map(\.newNumber) == [12, nil, 13, 14])
    }

    @Test func aHunkWithoutCountsIsOneLine() throws {
        let hunk = try #require(
            try only(diff("--- a/a.txt", "+++ b/a.txt", "@@ -3 +3 @@", "-old", "+new")).hunks.first)
        #expect(hunk.oldStart == 3)
        #expect(hunk.lines.map(\.oldNumber) == [3, nil])
        #expect(hunk.lines.map(\.newNumber) == [nil, 3])
    }

    @Test func readsSeveralHunks() throws {
        let file = try only(
            diff(
                "--- a/a.txt", "+++ b/a.txt", "@@ -1 +1 @@", "-a", "+b", "@@ -20 +20 @@", "-c", "+d"
            ))
        #expect(file.hunks.map(\.oldStart) == [1, 20])
    }

    @Test func aNewFileIsAdded() throws {
        let file = try only(
            diff(
                "diff --git a/a.txt b/a.txt", "new file mode 100644", "index 0000000..814f4a4",
                "--- /dev/null", "+++ b/a.txt", "@@ -0,0 +1,2 @@", "+one", "+two"))
        #expect(file.path == "a.txt")
        #expect(file.change == .added)
        #expect(file.hunks.first?.lines.map(\.newNumber) == [1, 2])
    }

    @Test func aDeletedFileIsDeleted() throws {
        let file = try only(
            diff(
                "diff --git a/a.txt b/a.txt", "deleted file mode 100644", "index 814f4a4..0000000",
                "--- a/a.txt", "+++ /dev/null", "@@ -1 +0,0 @@", "-one"))
        #expect(file.path == "a.txt")
        #expect(file.change == .deleted)
    }

    @Test func aRenameWithoutOtherChangeSaysWhereItCameFrom() throws {
        let file = try only(
            diff(
                "diff --git a/a.txt b/b.txt", "similarity index 100%", "rename from a.txt",
                "rename to b.txt"))
        #expect(file.path == "b.txt")
        #expect(file.change == .renamed(from: "a.txt"))
        #expect(file.hunks.isEmpty)
    }

    @Test func aRenameWithChangesHasItsLines() throws {
        let file = try only(
            diff(
                "diff --git a/b.txt b/c.txt", "similarity index 71%", "rename from b.txt",
                "rename to c.txt", "index 4c7442b..8fe8312 100644", "--- a/b.txt", "+++ b/c.txt",
                "@@ -1,2 +1,3 @@", " one", " three", "+four"))
        #expect(file.change == .renamed(from: "b.txt"))
        #expect(file.hunks.first?.lines.count == 3)
    }

    @Test func aBinaryFileHasNoLines() throws {
        let file = try only(
            diff(
                "diff --git a/Floor plan.pdf b/Floor plan.pdf", "new file mode 100644",
                "index 0000000..8f58c9f",
                "Binary files /dev/null and b/Floor plan.pdf differ"))
        #expect(file.path == "Floor plan.pdf")
        #expect(file.isBinary)
        #expect(file.change == .added)
        #expect(file.hunks.isEmpty)
    }

    @Test func aLineWithoutANewlineAtTheEndIsMarked() throws {
        let lines = try #require(
            try only(
                diff(
                    "--- a/a.txt", "+++ b/a.txt", "@@ -1 +1 @@", "-one", "+two",
                    "\\ No newline at end of file")
            ).hunks.first?.lines)
        #expect(lines.map(\.text) == ["one", "two"])
        #expect(lines.map(\.endsWithoutNewline) == [false, true])
    }

    @Test func aFoldersDiffHoldsEachFile() {
        let read = diff(
            "diff --git a/a.txt b/a.txt", "--- a/a.txt", "+++ b/a.txt", "@@ -1 +1 @@", "-a", "+b",
            "diff --git a/b.txt b/b.txt", "--- a/b.txt", "+++ b/b.txt", "@@ -1 +1 @@", "-c", "+d")
        #expect(read.files.map(\.path) == ["a.txt", "b.txt"])
    }

    @Test func aQuotedNameIsReadWithoutItsQuotes() throws {
        let file = try only(
            diff(
                "diff --git \"a/tab\\there.txt\" \"b/tab\\there.txt\"",
                "--- \"a/tab\\there.txt\"", "+++ \"b/tab\\there.txt\"", "@@ -1 +1 @@", "-a",
                "+b"))
        #expect(file.path == "tab\there.txt")
    }

    @Test func aQuotedNameKeepsItsLettersWrittenAsOctalBytes() throws {
        // `ë` is the bytes 0xC3 0xAB, which git writes as octal with core.quotePath on.
        let file = try only(
            diff(
                "--- \"a/Re\\303\\253l.txt\"", "+++ \"b/Re\\303\\253l.txt\"", "@@ -1 +1 @@", "-a",
                "+b"))
        #expect(file.path == "Reël.txt")
    }

    @Test func linesThatAreNoUTF8AreReadAsWellAsTheyCanBe() throws {
        var data = Data("--- a/a.txt\n+++ b/a.txt\n@@ -1 +1 @@\n-".utf8)
        data.append(contentsOf: [0xFF, 0x41])
        data.append(Data("\n+B\n".utf8))
        let lines = try #require(try only(GitDiff(unified: data)).hunks.first?.lines)
        #expect(lines.count == 2)
        #expect(lines[0].text.hasSuffix("A"))
    }

    @Test func noOutputIsNoChange() {
        #expect(GitDiff(unified: Data()).files.isEmpty)
    }
}
