import Foundation
import Observation
import SwiftUI
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
    /// Whether the folder view shows a sheet, an alert or Quick Look (ADR 0135).
    var isFolderPresenting = false
    /// Whether the window's shell shows Settings or the folder picker (ADR 0135).
    var isShellPresenting = false
    /// How many times Find was chosen; each time the folder view gives the search field the
    /// keyboard (ADR 0135).
    var findRequests = 0
    /// Which columns the window shows, which Show Sidebar changes (ADR 0135).
    var columnVisibility = NavigationSplitViewVisibility.automatic
    /// Asks for a new folder's name in the folder view, for the File menu (ADR 0135).
    @ObservationIgnored var newFolder: (() -> Void)?

    /// Whether the window shows a sheet or an alert, when the menus' commands and the
    /// list's keys act on nothing behind it (ADR 0135).
    var isPresenting: Bool {
        isFolderPresenting || isShellPresenting || conflicts.question != nil
            || dropRefusal != nil || addFailure != nil || naming != nil
    }

    /// Where the window opens, until its browser is made: as it was when it was last
    /// shown, or at a folder asked for; `nil` opens it where the last window left off.
    @ObservationIgnored var opening: WindowSnapshot?

    init(opening: WindowSnapshot?) {
        self.opening = opening
    }
}
