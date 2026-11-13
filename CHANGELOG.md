# Changelog

All notable changes to Treewise are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added
- The Advanced Folder Pattern add-on learns a series that starts again each year from a complete year: where it ends, a list of numbers it skips, and how wide they are written, as `{seq:24:1}` or `{seq:5,10,15,20}`. In a folder per year it can read the names in the same folder a year before, as `Administration/2025/Tax` beside `Administration/2026/Tax`, so a new year's folder gets last year's pattern at once. Settings > Add-ons has Also read names in the same folder a year before, on by default; only names are read.
- Halves after an H, as `H1` and `H2`, continue as a series of two.

### Changed
- Settings > Add-ons shows each add-on as a card with its licence as a coloured badge and a switch. Selecting a card opens it and folds the others; the list fills the tab and scrolls to the card selected. What an add-on recognizes shows with an example of each field, as `{seq:4}` 1–4, coloured by kind.
- Advanced Folder Pattern learns a list from one complete year whose numbers step evenly, as 2, 4, 6, 8, and such a list comes before the months.
- The sidebar can be made wider, up to 400 points, and starts at 260. Each window keeps its sidebar's width, also after a restart, and a new window starts at the width last chosen. When the window is made narrower, the sidebar gives way first. The sidebar's button stands at the right over the sidebar, away from the window's buttons.

### Fixed
- The Settings window is titled by the tab chosen, instead of Untitled.

## [0.8.0] - 2026-11-13

### Added
- The Advanced Folder Pattern add-on comes with Treewise. It recognizes more in a folder's names than the free add-on: years, quarters after a Q and months after a year that continue a series, and names that follow one of several patterns. Try it for 14 days with Try for 14 Days in Settings > Add-ons or in the overview of proposed names; after that it works with a licence key, entered with Enter Licence Key…. It is not for sale yet.
- A licence key can have an end date; Settings then says until when it counts, and how many days are left in its last week.
- Settings > Add-ons says what each add-on does and what it recognizes in a folder's names.
- `{seq}` takes a range, a list or an open end: `{seq:2-4}`, `{seq:2,4,6,8}`, `{seq:5-}`, and its width by leading zeros or a second colon: `{seq:001-}`, `{seq:5-:3}`.
- `{year:yy}` writes the year in two digits, `{folder:2}` is the folder above the one that holds the file, and `:lower`, `:upper` and `:title` write a field's text in small letters, capitals or with a capital at each word.

### Changed
- A name fits a pattern with `{seq}` only when its number is one the series can give, so `Q5` no longer fits `Q{seq:4}`.
- The overview says when a folder has too few names to recognize a pattern in: it needs at least 3.

### Fixed
- The buttons at the foot of the overview of proposed names have room around them again, instead of touching the window's edge.

## [0.7.0] - 2026-11-12

### Added
- Extract All… unpacks zip, tar, `.tar.gz`, `.tar.bz2`, `.tar.xz`, 7z, rar, iso, cpio and xar archives to a new folder, from the command bar, the context menu and the File menu. Nothing lands in the destination unless the whole archive extracted.
- Compress to ZIP puts an archive next to the selection and starts renaming it; Compress to also makes 7z and `.tar.gz` files. A zip or 7z leaves out `__MACOSX`, `._` files, `.DS_Store` and extended attributes.
- Suggest Names for Whole Folder… in the context menu and the File menu, for a folder so full that a right click always lands on a file.
- A double click opens an archive as a folder, and the sidebar's tree unfolds it. Inside it you can browse, sort, search, preview with Quick Look and copy or drag files out; Extract All extracts that archive. Zip, tar and 7z archives can be changed like a folder: add, replace, rename, move, copy, make folders and delete, with undo. A failed change leaves the archive as it was, and the first change puts a copy of the original in the Trash. Rar, iso, cpio and xar stay read-only.
- The sidebar's tree opens down to the folder or archive a tab shows; Settings can turn this off.
- A Go menu with Back, Forward and Enclosing Folder, as in Finder.
- Edit > Spelling and Grammar checks the spelling of a name you are typing; checking while typing is off until you turn it on.

### Changed
- Treewise's windows, menus, toolbar, Settings and everything in them are built the way Mac apps build them, which keeps a menu held open while a change ends from closing Treewise on macOS 26.
- Settings are laid out as other Mac apps lay out theirs: labels on the left, checkboxes and menus on the right.
- Treewise always opens again with the windows and tabs it had when it quit, whatever the system's setting for keeping windows says.
- On macOS 26 the progress panel and the badge on a drag stand on Liquid Glass.

### Fixed
- The first window opens on the main screen, not on the screen another display happened to give it.
- Ending a drag over the sidebar no longer closes Treewise.
- A change to a folder made while Treewise was reading it shows up, and an older reading no longer replaces a newer one.
- Renaming no longer offers one-time codes from AutoFill, which on macOS 26 could take the keyboard away from the name, so that ⌥Esc and Escape seemed to do nothing.
- A new archive, an extracted folder, a new folder and a renamed item are scrolled into view, also when sorting puts them far from where you were working.

## [0.6.0] - 2026-11-09

### Added
- Suggest Names… proposes names for a folder's files from a pattern that Treewise recognizes in the names already there, or that you type; you approve each name before anything is renamed. While renaming one file, ⌥Esc offers its proposals.
- Patterns with dates in several forms, also with month names in English, Dutch and German, the folder's name, a running number per year, quarter or month, optional parts and choices between parts. A name that nearly fits the pattern is offered written right. Fixed text in an optional part, as `[ correction]`, goes into a proposal only when the file's name already has it.
- Saved patterns in Settings > Names, to pick for a folder from the menu beside its pattern. A folder keeps the version it uses, is offered a newer one, and can update the saved pattern.
- Add-ons give the values for a pattern, and run in a separate service without internet access. Settings > Add-ons turns them on or off and sets their order. The free add-on reads a file's date and its current name, and recognizes the patterns of a folder's names when most of its files fit one.
- Settings > Names can clear what Treewise keeps for each folder you suggest names in. The settings of a folder not seen for 30 days on an attached disk go by themselves.
- The address bar starts at your home folder or a cloud folder, shows This Mac as an icon, and puts the parts that do not fit in a menu.

### Changed
- Settings has tabs: General, Names and Add-ons.
- The home folder shows a blue house in the sidebar and the address bar, so it stands out from the folders around it.

### Fixed
- Copying a folder, or moving it to another volume, keeps the folder's Finder tags and other extended attributes.
- A file name with a dot but no extension, like `2026.04.28 Permit`, gets `copy` at its end when a name is taken.

## [0.5.3] - 2026-11-05

### Added
- About Treewise links to the website and to the source code, which is now open under the Mozilla Public License 2.0.

### Changed
- Downloads and updates now come from the `mag243/treewise` repository.

## [0.5.2] - 2026-11-04

### Changed
- The website is now at treewise.m-domain.me, and updates are read from there.

## [0.5.1] - 2026-11-04

### Fixed
- The Settings window fits its contents, without a scroll bar.

## [0.5.0] - 2026-11-04

### Added
- Open in Terminal: the File menu (⌃⌘T), the command bar and context menus open a new terminal window in the folder. Choose Terminal, iTerm, Ghostty, Warp, kitty or Alacritty in Settings.
- Context menus show an icon beside every command.

## [0.4.0] - 2026-11-04

### Added
- The About panel shows the copyright line.
- Your home folder is under This Mac in the sidebar, after the volumes and before the cloud folders.
- Favorites are your own: add a folder from its context menu or by dragging it between the rows, drag to reorder, and remove any favorite without touching its folder. Restore Default Favorites brings the original list back.
- A small cloud marks a file that is only online, in the list and the icon view, and a ring shows its progress while it downloads. Browsing a cloud folder downloads nothing.
- Dropbox, Nextcloud, OneDrive, Google Drive and other cloud folders appear under Locations. They, iCloud Drive and your home folder cannot be renamed, moved to the Trash, cut or copied from Treewise.

### Fixed
- Clicking a folder in the sidebar's tree keeps the selection there when the folder is also a favorite, and going back or up to such a folder selects it in the tree if the tree shows it.

## [0.3.3] - 2026-11-01

### Added
- This Mac, as This PC in Explorer: click it in the sidebar, or go up from a volume, to see the volumes. The address bar starts with it.
- Eject a volume from Treewise: the eject button beside it in the sidebar, Eject in its context menu, or File > Eject (⌘E).

### Fixed
- A volume ejected or mounted while Treewise runs now leaves or joins the sidebar at once, and a window showing a folder on an ejected volume goes to This Mac.

## [0.3.2] - 2026-10-31

### Changed
- The arrow between two folders in the address bar points down while its menu of subfolders is open, as in Explorer, and is a little larger.

## [0.3.1] - 2026-10-30

### Fixed
- New Tab (⌘T) while a window shows a message, such as a path the address bar can't find, could make Treewise quit. A window that shows a message takes no new tab and is not put beside another until the message is answered, as on every Mac.

## [0.3.0] - 2026-10-30

### Added
- Refresh (⌘R) in the toolbar reads the folder again.
- A details pane at the right of the window (View > Show Details, ⇧⌘P, or Details in the command bar): a Quick Look preview and the selection's kind, size, date and folder, or the count and total size of several items.
- The address bar on a row of its own under the tab bar, as in Explorer: the path as buttons that take drops, a menu of the subfolders behind each arrow, and a field to type a path in (click its empty part or press ⌘L) that suggests folder names once typing pauses. The path bar at the bottom is gone.
- The command bar is a row under the address bar, as in Explorer: New, the actions, Sort and View menus with a label, and Window Beside; in a narrow window the buttons show only their icons. The view buttons left the toolbar for the View menu and the status bar.
- The status bar shows the item count at the left and icon buttons for List and Icons at the right, as in Explorer.
- A click on the name of the selected item renames it after a short wait, as in Finder and Explorer, in the list and in the icon view.

### Changed
- Tabs are macOS's window tabs: ⌘T and the + button open one, a tab tears off into its own window and Window > Merge All Windows joins them, as in Finder. ⌃⇥ shows the next tab. A file can no longer be dropped on a tab.
- After a restart every window comes back with its tabs, each with its folder, sort order and view; before, only the window that changed last did.
- Cut in one window and paste in another moves the items, as between tabs.
- Split view is gone: Window > Window Beside (⌥⌘N) opens a second window and puts the two on the halves of the screen, as two Explorer windows. Open in Other Window, ⌥-double-click and ⌥⌘↓ open a folder in the most recently active other window, and the double-click setting chooses between this window and the other one.
- Edit > Copy to Other Window and Move to Other Window, also in the context menu, copy or move the selection into the folder of the other window, with undo.
- Undo and Redo are shared by all windows, as in Finder: ⌘Z in any window undoes the last move, copy, rename, new folder or trash, also after a drag from one window to another.
- A window can't be made so narrow that the folder no longer fits beside the sidebar.

### Fixed
- New Window (⌘N) opens a second window; in 0.2.0 Treewise quit. The toolbar can no longer be customized.

## [0.2.0] - 2026-10-29

### Added
- A command bar in the toolbar, as in Windows 11 File Explorer: New Folder, Cut, Copy, Paste, Rename, Share and Move to Trash. The toolbar can be customized.
- Help > Treewise Website opens the download page.

### Fixed
- A click on empty space in a pane, below its last row, makes that pane the active one.

## [0.1.2] - 2026-10-29

### Fixed
- Check for Updates… can be chosen; in 0.1.1 it stayed disabled. The setting for checking automatically shows whether it is on.
- Installing with Homebrew no longer warns about deprecated forms in the cask.

## [0.1.1] - 2026-10-29

The first beta: Treewise browses, copies and moves like Windows Explorer, signed and notarized so it opens without a warning.

### Added
- A disk image to install from: drag Treewise into Applications. Started from elsewhere, Treewise offers once to move itself there.
- Updates through Sparkle: Check for Updates… in the Treewise menu, and a daily check that can be turned off in Settings.
- Copying and moving by dragging onto the list, the sidebar, a tab, the path bar or empty space, with a "Move to"/"Copy to" badge that follows ⌥ and ⌘; dragging to and from Finder, and from Mail and other apps that drag promised files.
- Cut, copy and paste, also through the system pasteboard; ⌥⌘V moves what ⌘C copied. New folder, inline rename and Move to Trash, all undoable.
- A conflict dialog with Replace, Keep Both and Stop, and Apply to All.
- A progress panel for long transfers, in bytes and naming the file being copied, with Pause, Resume and Stop, also inside a large file.
- An icon view with thumbnails beside the list (⌘1 and ⌘2), Quick Look with Space, and context menus.
- Keyboard shortcuts for tabs, panes, opening and searching, listed in the README; split view is ⌥⌘\. Settings has a button to System Settings, where any menu item can get a key of its own.
- Settings (⌘,): hidden files, file extensions, row size, the start folder, and where a double-clicked folder opens.
- The last window's panes, tabs, sort order and view come back after a restart.
- The app icon.
- Browsing the disk on macOS: a sidebar with Favorites and a Locations tree from This Mac, tabs per pane, split view with two panes, a sortable list (Name, Date Modified, Size, Kind), a path bar and a status bar; folders update live when their contents change.
- Dutch and German, following the system language.
- The core model and rules: drag move-or-copy, "copy" names for conflicts, per-tab history, tabs and split panes, sorting, and date, size and kind formatting.

## [0.1.0] - 2026-10-26

First build: an empty Treewise window, with the project, tooling and release pipeline behind it.

### Added
- Project skeleton: the macOS and iOS app targets, the `TreewiseKit` package with its four modules, and one test per module.
- `tools/setup.sh` and `tools/build.sh` to set up the environment and to check, build, and test from the command line.
- swift-format and SwiftLint rules, and git hooks that run the checks and enforce the commit message rules.
- A CI workflow that runs on release tags and by hand.
- Build numbers from the build's date and time (`YYYY.MMDD.HHMMNN`), and a release workflow that publishes the zipped macOS app on a version tag.
