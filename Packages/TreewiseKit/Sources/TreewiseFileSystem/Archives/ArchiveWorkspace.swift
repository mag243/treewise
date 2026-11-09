#if os(macOS)
    import Foundation
    import TreewiseCore

    /// A hidden folder next to where an archive operation ends, so its result
    /// moves into place within the volume. Everything in it is made by Treewise
    /// during one operation, so it is removed rather than trashed (ADR 0074).
    struct ArchiveWorkspace {
        /// The folder.
        let url: URL

        /// Creates an empty workspace in `folder`.
        ///
        /// - Throws: `FileSystemError.notWritable` or `.notFound` for the folder.
        init(in folder: URL) throws {
            url = folder.appendingPathComponent(FileCopier.partialPrefix + UUID().uuidString)
            do {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
            } catch {
                throw TrashService.error(error, for: FileItem.ID(folder.path))
            }
        }

        /// Removes the workspace and what is left in it, also folders an
        /// archive extracted without write permission.
        func discard() {
            Self.remove(url)
        }

        /// Removes a folder Treewise made itself, also one holding folders an
        /// archive extracted without write permission.
        static func remove(_ folder: URL) {
            grantWrite(under: folder, toFiles: false)
            try? FileManager.default.removeItem(at: folder)
        }

        /// Gives the user write permission on a folder and the folders below
        /// it, and on the files when `toFiles` is set. Symbolic links are left
        /// alone: permissions set through one would change what it points to.
        static func grantWrite(under folder: URL, toFiles: Bool) {
            grantWrite(at: folder.path, ownerBits: 0o700)
            let manager = FileManager.default
            for name in (try? manager.contentsOfDirectory(atPath: folder.path)) ?? [] {
                let child = folder.appendingPathComponent(name)
                let attributes = try? manager.attributesOfItem(atPath: child.path)
                switch attributes?[.type] as? FileAttributeType {
                case .typeDirectory: grantWrite(under: child, toFiles: toFiles)
                case .typeRegular where toFiles: grantWrite(at: child.path, ownerBits: 0o200)
                default: break
                }
            }
        }

        private static func grantWrite(at path: String, ownerBits: Int) {
            let manager = FileManager.default
            guard
                let current = (try? manager.attributesOfItem(atPath: path))?[.posixPermissions]
                    as? Int, current & ownerBits != ownerBits
            else { return }
            try? manager.setAttributes(
                [.posixPermissions: current | ownerBits], ofItemAtPath: path)
        }
    }
#endif
