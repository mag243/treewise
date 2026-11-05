# Treewise

A file manager for macOS, and later iPadOS and iOS, that works like Windows Explorer and looks like a native Mac app: a real folder tree, macOS's window tabs, two windows side by side, drag to move or copy with a visible indication of which, and cut/paste for files.

Download it from <https://treewise.m-domain.me/>, or with Homebrew: `brew install --cask mag243/tap/treewise`. It needs macOS 15 or later. The iPadOS and iOS versions are in development.

## Keyboard shortcuts

The specification of the app's keys (ADR 0022).

| Keys | Action |
| --- | --- |
| ⌘N | New window |
| ⌘T | New tab on the current folder: one of macOS's window tabs, which tear off and merge as in Finder |
| ⌘W | Close the tab; the window with its last tab |
| ⌃⇥ / ⌃⇧⇥ | Next / previous tab |
| ⌥⌘N | Window beside: a second window on the current folder, the two on the halves of the screen |
| ⌘1 / ⌘2 | Icons / list |
| ⇧⌘P | Show or hide the details pane: a preview and the selection's kind, size, date and folder |
| ⌘[ / ⌘] | Back / forward |
| ⌘↑ | Enclosing folder; above a volume is This Mac, which lists the volumes |
| ⌘R | Refresh: read the folder again |
| ⌘↓ | Open the selection; ⌥⌘↓ opens a folder in the other window |
| Double-click | Open, in the window the setting chooses; ⌥ the other window, ⌘ a new tab |
| Return | Rename; a click on the name of the selected item also renames it, after a short wait, as in Finder |
| Space | Quick Look |
| ⌘F | Search in the current folder |
| ⌘L | Type a path in the address bar: `~`, relative paths and folder-name completion; Return goes, Escape stops |
| ⌘⇧N | New folder |
| ⌘⌫ | Move to Trash |
| ⌘E | Eject the selected volumes; volumes also have an eject button in the sidebar and Eject in their context menu |
| ⌘X, ⌘C, ⌘V | Cut, copy, paste |
| ⌥⌘V | Move the copied items here |
| ⌘A | Select all |
| ⌘Z / ⌘⇧Z | Undo / redo |
| ⌃⌘S | Show or hide the sidebar |
| ⌘, | Settings |

## Toolbar

The toolbar has Back, Forward, Enclosing Folder, Refresh and search. Under the tab bar are the address bar and Explorer's command bar: *New* (New Folder), Cut, Copy, Paste, Rename, Share and Move to Trash, each enabled when its menu item is, *Sort* (column and direction), *View* (icons or list, row size, hidden files, file extensions), *Window Beside* and *Details*, the details pane at the right of the window. *Help > Treewise Website* opens the download page.

## Building from source

- macOS with Xcode 27.1 (the exact version is pinned in [`tools/versions.env`](tools/versions.env))
- [Homebrew](https://brew.sh)

```sh
tools/setup.sh          # checks Xcode; installs SwiftLint, shellcheck, xcbeautify, bash,
                        # the iOS test simulator, and the git hooks
tools/build.sh          # check + package tests + build both apps + macOS app tests
tools/build.sh run      # build and start the macOS app
tools/build.sh --help   # every command
```

`tools/setup.sh --no-simulator` skips the iOS Simulator runtime (several GB) when you only work on macOS.

`tools/build.sh verify` runs the checks and tests and builds both apps. `tools/build.sh ci` also runs the UI tests, which take over the screen.

## Layout

| Path | Contents |
|---|---|
| `Apps/TreewiseMac`, `Apps/TreewiseiOS` | The app shells |
| `Packages/TreewiseKit` | The shared modules: `TreewiseCore`, `TreewiseFileSystem`, `TreewiseUI`, `TreewiseTestSupport` |
| `UITests/` | XCUITest smoke tests for the macOS app |
| `tools/` | Setup, build, and check scripts, pinned versions, git hooks |

Comments refer to `ADR NNNN` and `PLAN.md`: the project's internal decision log and plan, which are not part of this repository.

## License

The source is under the [Mozilla Public License 2.0](LICENSE). The name Treewise and its icon are not covered by that license: a fork needs its own name and icon.
