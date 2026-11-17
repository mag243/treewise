import SwiftUI
import TreewiseCore
import TreewiseUI

/// The saved patterns (ADR 0068), as the Mac's Settings list them: their names, the default
/// marked, each pattern beneath in the colours of its fields; put in order and removed in
/// Edit, made the default with a swipe. The last pattern stays.
struct SavedPatternsList: View {
    let settings: BrowserSettings
    @State private var added: SavedPattern.ID?

    private var patterns: SavedPatterns { settings.savedPatterns }

    var body: some View {
        List {
            ForEach(patterns.patterns) { pattern in
                NavigationLink {
                    SavedPatternEditor(settings: settings, id: pattern.id)
                } label: {
                    row(pattern)
                }
                .swipeActions(edge: .leading) {
                    if pattern.id != patterns.defaultPattern.id {
                        Button("Make Default") { settings.savedPatterns.makeDefault(pattern.id) }
                            .tint(.accentColor)
                    }
                }
                .deleteDisabled(patterns.patterns.count == 1)
            }
            .onDelete { offsets in
                for id in offsets.map({ patterns.patterns[$0].id }) {
                    _ = settings.savedPatterns.remove(id)
                }
            }
            .onMove { settings.savedPatterns.move(fromOffsets: $0, toOffset: $1) }
        }
        .navigationTitle(Text("Saved Patterns"))
        .navigationDestination(item: $added) { id in
            SavedPatternEditor(settings: settings, id: id)
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                EditButton()
                Button(action: addPattern) {
                    Label("Add Pattern", systemImage: "plus")
                }
            }
        }
    }

    private func row(_ pattern: SavedPattern) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(pattern.name)
                if pattern.id == patterns.defaultPattern.id {
                    Text("Default")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(NameMarkColors.text(pattern.text, marks: NameMark.inPattern(pattern.text)))
                .font(.caption.monospaced())
        }
    }

    private func addPattern() {
        if case .success(let id) = settings.savedPatterns.save(
            name: String(localized: "New Pattern"), text: "{date:yyyy.MM.dd} {text}")
        {
            added = id
        }
    }
}

/// A saved pattern's name and pattern. A pattern is kept when the user commits it, with
/// Return or by leaving, not with each key, as each change of the text is a version that
/// folders are offered (ADR 0068); an empty name is not taken.
private struct SavedPatternEditor: View {
    let settings: BrowserSettings
    let id: SavedPattern.ID
    @State private var name = ""
    @State private var text = ""

    var body: some View {
        Form {
            Section {
                TextField("Name", text: $name)
                    .onChange(of: name) { _ = settings.savedPatterns.rename(id, to: name) }
            } header: {
                Text("Name")
            }
            Section {
                NameTextField(
                    text: $text, marks: NameMark.inPattern(text),
                    style: .init(
                        font: .monospacedSystemFont(
                            ofSize: UIFont.preferredFont(forTextStyle: .body).pointSize,
                            weight: .regular),
                        placeholder: String(localized: "Pattern"), identifier: "pattern"),
                    onSubmit: commit)
            } header: {
                Text("Pattern")
            } footer: {
                if let problem = NameTemplate.problemInForm(of: text) {
                    Text(NameReviewText.text(for: problem)).foregroundStyle(.red)
                }
            }
        }
        .navigationTitle(Text(name))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard let saved = settings.savedPatterns.patterns.first(where: { $0.id == id })
            else { return }
            name = saved.name
            text = saved.text
        }
        .onDisappear(perform: commit)
    }

    /// Keeps the typed pattern when it can be read; the same text makes no new version.
    private func commit() {
        guard NameTemplate.problemInForm(of: text) == nil else { return }
        settings.savedPatterns.change(id, to: text)
    }
}
