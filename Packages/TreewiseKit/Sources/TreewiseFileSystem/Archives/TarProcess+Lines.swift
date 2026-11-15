#if os(macOS)
    import Foundation
    import TreewiseCore

    /// Reading `tar`'s lines and writing names it reads, for every archive operation.
    extension TarProcess {
        /// What `tar` and `zip` read as a pattern in a name.
        private static let patternCharacters: Set<Character> = ["\\", "[", "]", "*", "?"]

        /// A name as `tar` and `zip` match it literally: names in a list are patterns.
        static func literalPattern(_ name: String) -> String {
            escaped(name, patternCharacters)
        }

        /// `text` with each of `characters` after a backslash.
        static func escaped(_ text: String, _ characters: Set<Character>) -> String {
            String(text.flatMap { characters.contains($0) ? ["\\", $0] : [$0] })
        }

        /// Runs `body`, which runs `tar` and blocks until it ends, off Swift's cooperative
        /// pool; cancelling the task stops `control`, and with it `tar`.
        static func offThePool<Value: Sendable>(
            control: TransferControl, _ body: @escaping @Sendable () throws -> Value
        ) async throws -> Value {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    DispatchQueue.global(qos: .userInitiated).async {
                        continuation.resume(with: Result { try body() })
                    }
                }
            } onCancel: {
                control.stop()
            }
        }

        /// Counts the entries `tar` reports done, of `total`, failures left out.
        struct EntryCounter {
            let total: Int
            private var completed = 0

            init(total: Int) {
                self.total = total
            }

            /// The progress after `line`, when it reports an entry done.
            mutating func read(_ line: String) -> ArchiveProgress? {
                guard TarProcess.isEntry(line), !TarProcess.isFailure(line) else { return nil }
                completed += 1
                return ArchiveProgress(
                    completedEntries: completed, totalEntries: total,
                    currentName: TarProcess.entryName(line))
            }
        }
    }

    /// What keeps an archive clean for other systems: no `__MACOSX` folder, no `._` files,
    /// no `.DS_Store`, and no extended attributes or flags.
    enum MacMetadata {
        /// The options that keep `tar` from writing the Mac's own data.
        static let tarOptions = ["--no-mac-metadata", "--no-xattrs", "--no-fflags"]
        /// The names `tar` leaves out.
        static let excludedNames = [".DS_Store", "._*", "__MACOSX"]

        /// Whether a file or folder is the Mac's own, left behind for no one else.
        static func isLeftover(_ name: String) -> Bool {
            name == ".DS_Store" || name == "__MACOSX" || name.hasPrefix("._")
        }
    }
#endif
