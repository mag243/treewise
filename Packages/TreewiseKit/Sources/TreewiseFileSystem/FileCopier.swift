import Darwin
import Foundation
import TreewiseCore
import os

/// Copies files for `FileOperationRunner` on a serial queue of its own, so a
/// paused copy, or an access waiting for a File Provider (ADR 0047), blocks
/// that queue's thread and never one of Swift's cooperative pool (ADR 0026). Regular files go through `copyfile(3)`, which clones on
/// the same volume and otherwise reports, pauses and stops inside the file.
enum FileCopier {
    /// The start of a partial copy's name; a leading dot keeps it out of other apps' lists.
    static let partialPrefix = ".treewise-partial-"

    private static let logger = Logger(subsystem: "me.m-domain.treewise", category: "FileCopier")

    private static let queue = DispatchQueue(
        label: "me.m-domain.treewise.copy", qos: .userInitiated)

    /// Runs `body` on the copy queue. Cancelling the task stops `control`, which
    /// is how a stop reaches a copy that runs outside the task.
    static func run<Value: Sendable>(
        control: TransferControl, _ body: @escaping @Sendable () throws -> Value
    ) async throws -> Value {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                queue.async { continuation.resume(with: Result { try body() }) }
            }
        } onCancel: {
            control.stop()
        }
    }

    /// Runs `body` on the copy queue, for a change that is not a transfer
    /// and cannot be paused or stopped, such as a coordinated rename that
    /// waits for a File Provider (ADR 0047).
    static func run<Value: Sendable>(_ body: @escaping @Sendable () throws -> Value) async throws
        -> Value
    {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { continuation.resume(with: Result { try body() }) }
        }
    }

    /// Copies `source` into `folder` as `name`, through a hidden partial copy.
    ///
    /// Postcondition: either the complete copy exists under `name`, or nothing new does.
    static func copyCompletely(
        _ source: URL, into folder: URL, as name: String, onFile: @escaping FileCopyProgress,
        control: TransferControl
    ) throws -> URL {
        let partial = folder.appendingPathComponent(partialPrefix + UUID().uuidString)
        let destination = folder.appendingPathComponent(name)
        do {
            var copied: Int64 = 0
            try copyTree(source, to: partial, onFile: onFile, control: control, copied: &copied)
            guard !FileManager.default.fileExists(atPath: destination.path) else {
                throw FileSystemError.alreadyExists(FileItem.ID(destination.path))
            }
            try FileManager.default.moveItem(at: partial, to: destination)
            return destination
        } catch {
            try? FileManager.default.removeItem(at: partial)
            throw error is FileSystemError
                ? error : TrashService.error(error, for: FileItem.ID(source.path))
        }
    }

    /// The total size and number of items of a file or folder, for verifying a copy.
    static func footprint(of url: URL) -> (size: Int, items: Int) {
        let keys: Set<URLResourceKey> = [.fileSizeKey, .isSymbolicLinkKey]
        var size = (try? url.resourceValues(forKeys: keys).fileSize) ?? 0
        var items = 1
        let entries = FileManager.default.enumerator(
            at: url, includingPropertiesForKeys: Array(keys))
        while let entry = entries?.nextObject() as? URL {
            size += (try? entry.resourceValues(forKeys: keys).fileSize) ?? 0
            items += 1
        }
        return (size, items)
    }

    /// Copies a folder file by file, waiting while paused and ending when
    /// stopped before each file; `onFile` hears of each file and of its bytes.
    /// Packages and symbolic links are copied whole, links as links. `copied`
    /// counts the bytes copied so far.
    private static func copyTree(
        _ source: URL, to destination: URL, onFile: @escaping FileCopyProgress,
        control: TransferControl,
        copied: inout Int64
    ) throws {
        guard control.waitWhilePaused() else { throw FileSystemError.cancelled }
        let values = try source.resourceValues(forKeys: [
            .isDirectoryKey, .isSymbolicLinkKey, .isPackageKey, .isRegularFileKey,
        ])
        let name = source.lastPathComponent
        let before = copied
        if values.isRegularFile == true, values.isSymbolicLink != true {
            onFile(name, before)
            try copyFile(source, to: destination, control: control) { onFile(name, before + $0) }
        } else if values.isDirectory != true || values.isPackage == true {
            onFile(name, before)
            try FileManager.default.copyItem(at: source, to: destination)
        } else {
            try FileManager.default.createDirectory(
                at: destination, withIntermediateDirectories: false)
            copyExtendedAttributes(from: source, to: destination)
            for child in try FileManager.default.contentsOfDirectory(
                at: source, includingPropertiesForKeys: nil)
            {
                try copyTree(
                    child, to: destination.appendingPathComponent(child.lastPathComponent),
                    onFile: onFile, control: control, copied: &copied)
            }
            return
        }
        copied += Int64(footprint(of: source).size)
    }

    /// Copies a folder's extended attributes, such as Finder tags. A folder is made
    /// anew so its items can report progress, which would leave these behind. A volume
    /// that refuses them does not stop the copy: the files are what matters.
    private static func copyExtendedAttributes(from source: URL, to destination: URL) {
        guard
            copyfile(source.path, destination.path, nil, copyfile_flags_t(COPYFILE_XATTR)) != 0
        else { return }
        logger.error("Extended attributes not copied, errno \(errno)")
    }

    /// Copies one regular file with `copyfile(3)`.
    ///
    /// - Throws: `FileSystemError.cancelled` when `control` stopped it, or the
    ///   error `copyfile` met, as a `POSIXError`.
    private static func copyFile(
        _ source: URL, to destination: URL, control: TransferControl,
        report: @escaping (Int64) -> Void
    ) throws {
        guard let state = copyfile_state_alloc() else { throw POSIXError(.ENOMEM) }
        defer { copyfile_state_free(state) }
        let context = CopyContext(control: control, report: report)
        let status: copyfile_callback_t = copyfileStatus
        let result = withExtendedLifetime(context) {
            copyfile_state_set(
                state, UInt32(COPYFILE_STATE_STATUS_CB),
                unsafeBitCast(status, to: UnsafeRawPointer.self))
            copyfile_state_set(
                state, UInt32(COPYFILE_STATE_STATUS_CTX),
                Unmanaged.passUnretained(context).toOpaque())
            return copyfile(
                source.path, destination.path, state,
                copyfile_flags_t(COPYFILE_ALL | COPYFILE_CLONE | COPYFILE_NOFOLLOW))
        }
        guard result != 0 else { return }
        if let failure = context.failure { throw POSIXError(failure) }
        throw errno == ECANCELED
            ? FileSystemError.cancelled : POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
}

/// What the `copyfile` callback needs, passed to it as an unmanaged pointer.
/// It is used on the copy queue's thread only.
private final class CopyContext {
    let control: TransferControl
    let report: (Int64) -> Void
    /// The error `copyfile` met, kept because quitting replaces `errno` with `ECANCELED`.
    var failure: POSIXErrorCode?

    init(control: TransferControl, report: @escaping (Int64) -> Void) {
        self.control = control
        self.report = report
    }
}

/// The `copyfile` status callback: reports the bytes copied, waits while the
/// transfer is paused, and quits when it is stopped or `copyfile` met an error,
/// which returning "continue" would ignore.
private let copyfileStatus: copyfile_callback_t = { what, stage, state, _, _, context in
    guard let context else { return COPYFILE_CONTINUE }
    let copy = Unmanaged<CopyContext>.fromOpaque(context).takeUnretainedValue()
    if stage == COPYFILE_ERR {
        copy.failure = POSIXErrorCode(rawValue: errno) ?? .EIO
        return COPYFILE_QUIT
    }
    if what == COPYFILE_COPY_DATA, stage == COPYFILE_PROGRESS, let state {
        var copied: off_t = 0
        copyfile_state_get(state, UInt32(COPYFILE_STATE_COPIED), &copied)
        copy.report(Int64(copied))
    }
    return copy.control.waitWhilePaused() ? COPYFILE_CONTINUE : COPYFILE_QUIT
}
