import SwiftUI
import TreewiseCore
import TreewiseFileSystem
import TreewiseUI

/// The address bar while a path is typed (M5b): it starts with the folder's
/// path, suggests folder names as they are typed (`TypedPath`), goes there on
/// Return and stops on Escape or when it loses the focus. A path that names
/// no folder inside the boundary (ADR 0019) is refused with a message.
struct AddressField: View {
    /// How long typing pauses before the folder names are read.
    private static let typingPause = Duration.milliseconds(300)

    @FocusState private var isFocused: Bool
    @State private var text = ""
    /// The names of the folders in the folder being completed, read once per
    /// folder; the suggestions are filtered from them as the text changes.
    @State private var names: (folder: String, names: [String])?
    /// The text that named no folder, for the message.
    @State private var refused: String?

    let browser: BrowserState
    let paneIndex: Int
    let folder: FileItem.ID
    /// Ends editing, with or without going anywhere.
    let done: () -> Void

    var body: some View {
        TextField("Address", text: $text)
            .textFieldStyle(.roundedBorder)
            .focused($isFocused)
            .textInputSuggestions {
                ForEach(suggestions, id: \.self) { suggestion in
                    Text(suggestion).textInputCompletion(suggestion + "/")
                }
            }
            .onSubmit(go)
            .onExitCommand(perform: done)
            .onChange(of: isFocused) { _, focused in
                if !focused && refused == nil { done() }
            }
            .task(id: text) { await readNamesAfterPause() }
            .onAppear {
                text = folder.shownPath
                isFocused = true
            }
            .alert(refusalText, isPresented: isRefusing) {
                Button("OK") {
                    refused = nil
                    isFocused = true
                }
            }
    }

    private var home: String { LaunchOptions.homeFolder.path }

    private func go() {
        guard text != folder.shownPath else {
            done()
            return
        }
        let reader = LocalFileSystem(locations: LaunchOptions.locations)
        guard let path = TypedPath.resolve(text, home: home, current: folder.shownPath),
            (try? reader.currentItem(at: FileItem.ID(path)))?.isContainer == true
        else {
            refused = text
            return
        }
        done()
        Task { await browser.navigate(pane: paneIndex, to: FileItem.ID(path)) }
    }

    private var completionFolder: String? {
        TypedPath.completionFolder(for: text, home: home, current: folder.shownPath)
    }

    /// Reads the names to suggest for the folder being completed, once
    /// per folder and only after typing pauses, so the suggestions don't
    /// flicker while a path is typed. Each keystroke cancels the pending
    /// read.
    private func readNamesAfterPause() async {
        guard let parent = completionFolder, names?.folder != parent else { return }
        guard (try? await Task.sleep(for: Self.typingPause)) != nil else { return }
        let read = await browser.subfolders(of: FileItem.ID(parent)).map(\.name)
        guard !Task.isCancelled else { return }
        names = (parent, read)
    }

    /// The suggestions for the text as it is now.
    private var suggestions: [String] {
        guard let parent = completionFolder, let names, names.folder == parent else { return [] }
        return TypedPath.completions(for: text, home: home, current: folder.shownPath) {
            $0 == parent ? names.names : []
        }
    }

    private var refusalText: String {
        let name = refused ?? ""
        return String(
            localized: "Treewise can’t find “\(name)”. Check the spelling and try again.")
    }

    private var isRefusing: Binding<Bool> {
        Binding(get: { refused != nil }, set: { if !$0 { refused = nil } })
    }
}
