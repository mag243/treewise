import Foundation
import Testing
import TreewiseCore
import os

/// Pausing, resuming and stopping a transfer (ADR 0026).
@Suite struct TransferControlTests {
    @Test func goesOnAtOnceWhenNotPaused() {
        #expect(TransferControl().waitWhilePaused())
    }

    @Test func waitsWhilePausedUntilResumed() {
        let control = TransferControl()
        control.pause()
        let resumed = DispatchSemaphore(value: 0)
        let result = OSAllocatedUnfairLock(initialState: false)
        Thread.detachNewThread {
            let goesOn = control.waitWhilePaused()
            result.withLock { $0 = goesOn }
            resumed.signal()
        }
        control.resume()
        resumed.wait()
        #expect(result.withLock { $0 })
        #expect(!control.isPaused)
    }

    @Test func stopsAWaitingCopy() {
        let control = TransferControl()
        control.pause()
        let stopped = DispatchSemaphore(value: 0)
        let result = OSAllocatedUnfairLock(initialState: true)
        Thread.detachNewThread {
            let goesOn = control.waitWhilePaused()
            result.withLock { $0 = goesOn }
            stopped.signal()
        }
        control.stop()
        stopped.wait()
        #expect(!result.withLock { $0 })
        #expect(control.isStopped)
    }
}
