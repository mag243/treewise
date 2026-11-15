import Foundation
import TreewiseCore
import TreewiseModuleInterface
import os

/// Asking the modules for values (ADR 0057, ADR 0073).
extension NameReviewModel {
    /// The most requests open at once for an add-on that reads only names (ADR 0073).
    static let nameReadersAtOnce = 4
    /// The most for one that reads contents, which takes memory and processor time.
    static let contentReadersAtOnce = 2

    /// Asks each module about its files, the modules at the same time and each within its
    /// limit, the selected file first (ADR 0073). A round starts when the one before it is
    /// done, so an older answer never replaces a newer one; one that fails leaves the rest.
    /// Cancelling a round cancels the rounds it waits for too, and every request a
    /// cancelled round does not send leaves `readingCount`.
    func ask(_ pending: [(item: FileItem, module: NameReviewModule)]) {
        guard !pending.isEmpty else { return }
        let previous = reading
        readingCount += pending.count
        let selected = pending.filter { $0.item.id == selectedID }
        let ordered = selected + pending.filter { $0.item.id != selectedID }
        var queues: [[(item: FileItem, module: NameReviewModule)]] = []
        for request in ordered {
            if let index = queues.firstIndex(where: { $0.first?.module.id == request.module.id }) {
                queues[index].append(request)
            } else {
                queues.append([request])
            }
        }
        reading = Task {
            await withTaskCancellationHandler {
                await previous?.value
            } onCancel: {
                previous?.cancel()
            }
            guard !Task.isCancelled else {
                readingCount -= pending.count
                return
            }
            await withTaskGroup(of: Void.self) { group in
                for queue in queues { group.addTask { await self.read(queue) } }
            }
        }
    }

    /// Asks one module about its files, keeping its limit of requests open.
    private func read(_ queue: [(item: FileItem, module: NameReviewModule)]) async {
        guard let module = queue.first?.module else { return }
        let limit =
            module.description.names.neededContent.isEmpty
            ? Self.nameReadersAtOnce : Self.contentReadersAtOnce
        let sent = await withTaskGroup(of: Void.self) { group in
            var next = queue.makeIterator()
            var sent = 0
            func addNext() {
                guard !Task.isCancelled, let request = next.next() else { return }
                sent += 1
                group.addTask {
                    await self.read(request.item, request.module)
                    await self.finishReading()
                }
            }
            for _ in 0..<limit { addNext() }
            while await group.next() != nil { addNext() }
            return sent
        }
        // What a cancelled round did not send is not read either.
        readingCount -= queue.count - sent
    }

    private func finishReading() { readingCount -= 1 }

    /// The values without those that cannot be written, such as a date that is no day;
    /// an add-on's answer comes from another process (ADR 0057).
    static func wellFormed(_ values: [[String: NameTemplate.Value]]) -> [[String: NameTemplate
        .Value]]
    {
        values.map { reading in
            let kept = reading.filter(\.value.isWellFormed)
            if kept.count < reading.count {
                logger.error("An add-on gave a value that cannot be written; it is left out")
            }
            return kept
        }
    }

    private func read(_ item: FileItem, _ module: NameReviewModule) async {
        let visible = folderItems.filter { !$0.isHidden }
        var request = await dependencies.makeRequest(
            item, visible, module.description.names.neededContent)
        request.folderName = folder.name
        request.pattern = module.template?.text
        request.licence = licence
        do {
            let values = try await dependencies.host.fieldValues(
                moduleID: module.id, request: request)
            answers[item.id, default: [:]][module.id] = Self.wellFormed(values)
            refreshProposals(of: item, from: module.id)
            refreshConflicts()
        } catch {
            Self.logger.error("A module gave no answer: \(String(describing: error))")
            moduleFailed = true
        }
    }
}
