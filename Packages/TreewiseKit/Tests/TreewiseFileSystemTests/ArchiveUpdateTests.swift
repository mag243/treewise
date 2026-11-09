#if os(macOS)
    import Foundation
    import Testing
    import TreewiseCore
    import TreewiseFileSystem
    import TreewiseTestSupport

    /// Changing what an archive holds (ADR 0078), inside a TempDirectory.
    @Suite struct ArchiveUpdateTests: ArchiveTesting {
        private static let changeable = ArchiveFixtures.writable.filter {
            ArchiveNaming.canChange(name: $0.name)
        }

        private func options(_ name: String) throws -> [String] {
            try #require(ArchiveFixtures.writable.first { $0.name == name }).options
        }

        private func listed(_ directory: TempDirectory, _ name: String) throws -> Set<String> {
            let entries = try ArchiveFixtures.list(directory.url(name)).map { entry in
                entry.hasPrefix("./") ? String(entry.dropFirst(2)) : entry
            }
            return Set(entries.map { $0.hasSuffix("/") ? String($0.dropLast()) : $0 })
                .subtracting([""])
        }

        private func contents(
            _ directory: TempDirectory, _ name: String, _ entry: String
        ) throws -> String {
            let out = directory.url("check-\(UUID().uuidString)")
            try manager.createDirectory(at: out, withIntermediateDirectories: false)
            try ArchiveFixtures.tar(["-xf", directory.url(name).path, "-C", out.path])
            return try String(contentsOf: out.appendingPathComponent(entry), encoding: .utf8)
        }

        private func addition(
            _ directory: TempDirectory, file: String, contents text: String, as path: String
        ) throws -> ArchiveAddition {
            try directory.makeFolder("new")
            return ArchiveAddition(
                source: try directory.makeFile("new/\(file)", contents: text), path: path)
        }

        @Test(arguments: changeable.map(\.name))
        func addsAFile(_ name: String) async throws {
            let directory = try TempDirectory()
            try makeArchive(directory, name, options: try options(name))
            let new = try addition(directory, file: "n.txt", contents: "new", as: "Photos/n.txt")

            try await apply(.add([new]), to: name, in: directory)

            #expect(try listed(directory, name).contains("Photos/n.txt"))
            #expect(try listed(directory, name).contains("Photos/a.txt"))
            #expect(try contents(directory, name, "Photos/n.txt") == "new")
            #expect(try contents(directory, name, "Photos/a.txt") == "hello")
        }

        @Test(arguments: changeable.map(\.name))
        func replacesAFile(_ name: String) async throws {
            let directory = try TempDirectory()
            try makeArchive(directory, name, options: try options(name))
            let new = try addition(directory, file: "a.txt", contents: "other", as: "Photos/a.txt")

            try await apply(.add([new]), to: name, in: directory)

            #expect(try contents(directory, name, "Photos/a.txt") == "other")
            let all = try ArchiveFixtures.list(directory.url(name))
            #expect(all.filter { $0.hasSuffix("Photos/a.txt") }.count == 1)
        }

        @Test(arguments: changeable.map(\.name))
        func addsAFolderWithWhatIsInIt(_ name: String) async throws {
            let directory = try TempDirectory()
            try makeArchive(directory, name, options: try options(name))
            try directory.makeFolder("new")
            let folder = try directory.makeFolder("new/Sub")
            try directory.makeFile("new/Sub/in.txt", contents: "in")
            try directory.makeFile("new/Sub/.DS_Store", contents: "junk")

            try await apply(
                .add([ArchiveAddition(source: folder, path: "Sub")]), to: name, in: directory)

            let paths = try listed(directory, name)
            #expect(paths.isSuperset(of: ["Sub", "Sub/in.txt"]))
            #expect(!paths.contains("Sub/.DS_Store"))
        }

        @Test(arguments: changeable.map(\.name))
        func removesAFile(_ name: String) async throws {
            let directory = try TempDirectory()
            try makeArchive(directory, name, options: try options(name))

            try await apply(.remove(["Photos/a.txt"]), to: name, in: directory)

            let paths = try listed(directory, name)
            #expect(!paths.contains("Photos/a.txt"))
            #expect(paths.contains("Photos/run.sh"))
        }

        @Test(arguments: changeable.map(\.name))
        func removingAPathLeavesTheSameNameInAnotherFolder(_ name: String) async throws {
            let directory = try TempDirectory()
            try directory.makeFolder("src")
            try directory.makeFolder("src/d")
            try directory.makeFile("src/a.txt", contents: "top")
            try directory.makeFile("src/d/a.txt", contents: "deep")
            try ArchiveFixtures.tar(
                try options(name) + [
                    "-cf", directory.url(name).path, "-C", directory.url("src").path, ".",
                ])

            try await apply(.remove(["a.txt"]), to: name, in: directory)

            #expect(try listed(directory, name) == ["d", "d/a.txt"])
        }

        @Test(arguments: changeable.map(\.name))
        func removesAFolder(_ name: String) async throws {
            let directory = try TempDirectory()
            try makeArchive(directory, name, options: try options(name))

            try await apply(.remove(["Photos/empty"]), to: name, in: directory)

            #expect(!(try listed(directory, name).contains("Photos/empty")))
        }

        @Test(arguments: changeable.map(\.name))
        func renamesAFile(_ name: String) async throws {
            let directory = try TempDirectory()
            try makeArchive(directory, name, options: try options(name))

            try await apply(
                .relocate(from: "Photos/a.txt", to: "Photos/b.txt"), to: name, in: directory)

            let paths = try listed(directory, name)
            #expect(paths.contains("Photos/b.txt"))
            #expect(!paths.contains("Photos/a.txt"))
            #expect(try contents(directory, name, "Photos/b.txt") == "hello")
        }

        @Test(arguments: changeable.map(\.name))
        func renamesAFolderWithWhatIsInIt(_ name: String) async throws {
            let directory = try TempDirectory()
            try makeArchive(directory, name, options: try options(name))

            try await apply(.relocate(from: "Photos", to: "Pictures"), to: name, in: directory)

            let paths = try listed(directory, name)
            #expect(paths.contains("Pictures/a.txt"))
            #expect(!paths.contains { $0.hasPrefix("Photos") })
        }

        @Test func aLinkKeepsWhatItPointsToWhenItsFolderIsRenamed() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory, "Photos.zip")

            try await apply(
                .relocate(from: "Photos", to: "Pictures"), to: "Photos.zip", in: directory)

            let out = try directory.makeFolder("out")
            try ArchiveFixtures.tar(["-xf", directory.url("Photos.zip").path, "-C", out.path])
            #expect(
                try manager.destinationOfSymbolicLink(
                    atPath: out.appendingPathComponent("Pictures/link").path) == "a.txt")
        }

        @Test(arguments: changeable.map(\.name))
        func makesANewFolder(_ name: String) async throws {
            let directory = try TempDirectory()
            try makeArchive(directory, name, options: try options(name))

            try await apply(.newFolder("Photos/Fresh"), to: name, in: directory)

            #expect(try listed(directory, name).contains("Photos/Fresh"))
        }

        @Test(arguments: ["Photos.zip", "Photos.tar.gz", "Photos.7z"])
        func namesWithOddCharactersMeanOnlyThemselves(_ name: String) async throws {
            let directory = try TempDirectory()
            try directory.makeFolder("src")
            for file in ["we[ir]d*.txt", "weird.txt", "-dash.txt", "sp ace.txt", "a&b.txt"] {
                try directory.makeFile("src/\(file)", contents: file)
            }
            try ArchiveFixtures.tar(
                try options(name) + [
                    "-cf", directory.url(name).path, "-C", directory.url("src").path, ".",
                ])
            let added = try addition(directory, file: "-new*.txt", contents: "n", as: "-new*.txt")

            try await apply(.remove(["we[ir]d*.txt"]), to: name, in: directory)
            try await apply(.add([added]), to: name, in: directory)
            try await apply(.relocate(from: "a&b.txt", to: "x&y.txt"), to: name, in: directory)
            try await apply(.remove(["-dash.txt"]), to: name, in: directory)

            #expect(
                try listed(directory, name) == ["weird.txt", "sp ace.txt", "x&y.txt", "-new*.txt"])
        }

        @Test func aNameWithAnAccentCanBeAddedAndRemoved() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let added = try addition(
                directory, file: "n\u{E9}.txt", contents: "n", as: "n\u{E9}.txt")

            try await apply(.add([added]), to: "Photos.zip", in: directory)
            #expect(try listed(directory, "Photos.zip").contains("n\u{E9}.txt"))

            try await apply(.remove(["n\u{E9}.txt"]), to: "Photos.zip", in: directory)
            #expect(!(try listed(directory, "Photos.zip").contains("n\u{E9}.txt")))
        }

        @Test func aZipStaysClean() async throws {
            let directory = try TempDirectory()
            try makeArchive(directory)
            let new = try addition(directory, file: "n.txt", contents: "new", as: "n.txt")
            try manager.setExtendedAttribute(on: new.source)

            try await apply(.add([new]), to: "Photos.zip", in: directory)

            let all = try ArchiveFixtures.list(directory.url("Photos.zip"))
            #expect(!all.contains { $0.contains("__MACOSX") || $0.contains("._") })
        }

        /// `zip` writes a zip that `tar` cannot read when a tar-made zip holds
        /// an entry over 4 GB; the check finds it and tar does the work.
        @Test func aLargeEntryFromTarFallsBackAndStaysReadable() async throws {
            let directory = try TempDirectory()
            let big = directory.url("big.bin")
            manager.createFile(atPath: big.path, contents: nil)
            let handle = try FileHandle(forWritingTo: big)
            try handle.truncate(atOffset: 5_000_000_000)
            try handle.close()
            try ArchiveFixtures.tar([
                "--format", "zip", "-cf", directory.url("Big.zip").path, "-C", directory.path,
                "big.bin",
            ])
            try manager.removeItem(at: big)

            try await apply(.newFolder("Fresh"), to: "Big.zip", in: directory)

            #expect(try listed(directory, "Big.zip") == ["big.bin", "Fresh"])
        }
    }

    extension FileManager {
        /// Gives a file an extended attribute, which a clean zip leaves out.
        fileprivate func setExtendedAttribute(on file: URL) throws {
            let value = Data("x".utf8)
            let result = value.withUnsafeBytes {
                setxattr(file.path, "me.treewise.test", $0.baseAddress, value.count, 0, 0)
            }
            guard result == 0 else { throw CocoaError(.fileWriteUnknown) }
        }
    }
#endif
