#if os(macOS)
    import Foundation
    import Testing

    @testable import TreewiseModuleXPC

    /// A reply, an error, a timeout and a cancellation race for one wait: the first
    /// outcome counts, in whichever order they come.
    @Suite struct PendingReplyTests {
        private struct Failure: Error, Equatable {
            let name: String
        }

        private static let reply = Data("reply".utf8)
        private static let otherReply = Data("other".utf8)
        /// How many outcomes race in the test of many at once.
        private static let racers = 100

        @Test func anOutcomeBeforeTheWaitIsKept() async throws {
            let pending = PendingReply()
            pending.finish(.success(Self.reply))
            #expect(try await pending.wait() == Self.reply)
        }

        @Test func anOutcomeDuringTheWaitEndsIt() async throws {
            let pending = PendingReply()
            async let waited = pending.wait()
            pending.finish(.success(Self.reply))
            #expect(try await waited == Self.reply)
        }

        @Test func theFirstOutcomeCountsOverALaterReply() async throws {
            let pending = PendingReply()
            pending.finish(.failure(Failure(name: "timeout")))
            pending.finish(.success(Self.reply))
            await #expect(throws: Failure(name: "timeout")) { try await pending.wait() }
        }

        @Test func theFirstOutcomeCountsOverALaterError() async throws {
            let pending = PendingReply()
            pending.finish(.success(Self.reply))
            pending.finish(.failure(Failure(name: "cancelled")))
            #expect(try await pending.wait() == Self.reply)
        }

        @Test func noReplyIsAnOutcomeToo() async throws {
            let pending = PendingReply()
            pending.finish(.success(nil))
            pending.finish(.success(Self.reply))
            #expect(try await pending.wait() == nil)
        }

        @Test func manyOutcomesAtOnceEndTheWaitOnce() async throws {
            let pending = PendingReply()
            async let waited = pending.wait()
            await withTaskGroup(of: Void.self) { group in
                for index in 0..<Self.racers {
                    group.addTask {
                        pending.finish(
                            index.isMultiple(of: 2)
                                ? .success(Self.reply) : .success(Self.otherReply))
                    }
                }
            }
            let outcome = try await waited
            #expect(outcome == Self.reply || outcome == Self.otherReply)
        }
    }
#endif
