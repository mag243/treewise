/// Work that many requests share: a request while it runs is done by one more run after
/// it, however many arrive, so a burst of a cloud provider's notices reads the sync
/// folders twice rather than once for each (ADR 0144).
///
/// Postcondition of `request()`: a run that started after the request has ended.
@MainActor
public final class CoalescedWork {
    private let work: @MainActor () async -> Void
    private var runs: Task<Void, Never>?
    private var isRequested = false

    /// Work that runs `work` for its requests.
    public init(_ work: @escaping @MainActor () async -> Void) {
        self.work = work
    }

    /// Runs the work, or has it run once more after the run going on; returns when a run
    /// that started after this request has ended.
    public func request() async {
        isRequested = true
        if runs == nil {
            runs = Task {
                while isRequested {
                    isRequested = false
                    await work()
                }
                runs = nil
            }
        }
        await runs?.value
    }
}
