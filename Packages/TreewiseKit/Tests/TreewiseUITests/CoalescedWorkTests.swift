import Testing

@testable import TreewiseUI

/// Requests that arrive while the work runs are done by one run after it, as a burst of a
/// cloud provider's notices reads the sync folders twice, not once for each (ADR 0144).
@MainActor
@Suite struct CoalescedWorkTests {
    /// Work that holds each run until the test lets it go, and counts the runs.
    @MainActor
    private final class HeldWork {
        var runs = 0
        private var held: [CheckedContinuation<Void, Never>] = []

        func run() async {
            runs += 1
            await withCheckedContinuation { held.append($0) }
        }

        /// Waits until `count` runs have started.
        func waitForRuns(_ count: Int) async {
            while runs < count { await Task.yield() }
        }

        /// Lets the waiting run go, once it waits.
        func release() async {
            while held.isEmpty { await Task.yield() }
            held.removeFirst().resume()
        }
    }

    @Test func requestsDuringARunAreDoneByOneMoreRun() async {
        let work = HeldWork()
        let coalesced = CoalescedWork { await work.run() }
        let first = Task { await coalesced.request() }
        await work.waitForRuns(1)
        var asked = 0
        let during = (0..<4).map { _ in
            Task {
                asked += 1
                await coalesced.request()
            }
        }
        // A request is recorded before it first waits, so all are in once counted.
        while asked < during.count { await Task.yield() }
        await work.release()
        await work.release()
        await first.value
        for request in during { await request.value }

        #expect(work.runs == 2)
    }

    @Test func aRequestAfterTheRunsEndedRunsAgain() async {
        let work = HeldWork()
        let coalesced = CoalescedWork { await work.run() }
        let first = Task { await coalesced.request() }
        await work.release()
        await first.value
        let second = Task { await coalesced.request() }
        await work.release()
        await second.value

        #expect(work.runs == 2)
    }

    @Test func aRequestDuringARunReturnsOnlyAfterTheNextRun() async {
        let work = HeldWork()
        let coalesced = CoalescedWork { await work.run() }
        _ = Task { await coalesced.request() }
        await work.waitForRuns(1)
        var isDone = false
        let late = Task {
            await coalesced.request()
            isDone = true
        }
        await work.release()
        await work.waitForRuns(2)
        #expect(!isDone)
        await work.release()
        await late.value

        #expect(isDone)
    }
}
