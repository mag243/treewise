import Foundation
import Observation
import TreewiseUI

/// One Treewise window (ADR 0134): its own browser over the added folders, with its folder,
/// history and selection, and what it asks or says, which only this window shows. The
/// added folders, the clipboard and undo are the app's, in `Locations`.
@MainActor
@Observable
final class BrowserWindow {
    /// The browser; `nil` while no folder is added.
    var browser: BrowserState?
    /// Asks what to do with a name taken, for this window's operations.
    let conflicts = ConflictQuestions()
    /// Why the last drop on this window was refused as it landed, for an alert (ADR 0047,
    /// amended).
    var dropRefusal: String?
    /// Why the last folder this window added could not be added, for an alert.
    var addFailure: String?
    /// The location this window asks the name of (ADR 0119).
    var naming: LocationNaming?
    /// Where the window opens, until its browser is made: as it was when it was last
    /// shown, or at a folder asked for; `nil` opens it where the last window left off.
    @ObservationIgnored var opening: WindowSnapshot?

    init(opening: WindowSnapshot?) {
        self.opening = opening
    }
}
