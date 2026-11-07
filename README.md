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

## Name suggestions

*Suggest Names…* in a file's or folder's context menu proposes names for its files from a pattern, such as `{date:yyyy.MM.dd} {folder} - {text}`, which Treewise recognizes in the names already there or you type yourself. You approve each name before anything is renamed. While renaming a file, ⌥Esc offers the proposals for that one file.

- **Patterns** hold dates in several forms, also with month names in English, Dutch and German, the folder's name, a running number per year, quarter or month, optional parts and choices between parts.
- **Saved patterns** in Settings > Names: pick one for a folder from the menu beside the pattern. A folder keeps the version it uses and is offered a newer one when you change it.
- **Add-ons** give the values a pattern needs. The free add-on reads the file's date and its current name, and recognizes the patterns of a folder's names. Paid add-ons will follow, with a one-time licence checked on your Mac.

### Privacy

- Add-ons run in a separate service that has no access to the internet and sees only the files it handles, one at a time; it never gets a path, only names and what it needs from the file.
- Treewise sends nothing about you or your files.

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
| `Packages/TreewiseKit` | The shared modules: `TreewiseCore`, `TreewiseFileSystem`, `TreewiseUI`, `TreewiseTestSupport`, the add-on interface `TreewiseModuleInterface` and its XPC connection `TreewiseModuleXPC`, and the free add-on `TreewiseFolderPatternModule` |
| `Apps/TreewiseModuleHost`, `Packages/TreewiseModuleCatalog` | The service that runs the add-ons, and the list of add-ons it holds |
| `UITests/` | XCUITest smoke tests for the macOS app |
| `tools/` | Setup, build, and check scripts, pinned versions, git hooks |

Comments refer to `ADR NNNN` and `PLAN.md`: the project's internal decision log and plan, which are not part of this repository.

## License

The source is under the [Mozilla Public License 2.0](LICENSE). The name Treewise and its icon are not covered by that license: a fork needs its own name and icon.
