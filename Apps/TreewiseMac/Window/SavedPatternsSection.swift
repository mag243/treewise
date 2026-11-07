import SwiftUI
import TreewiseCore
import TreewiseUI

/// The saved patterns in Settings (ADR 0068), as Mail lists its rules: a list of their
/// names, the default marked, put in order by dragging; + and − below it, Make Default,
/// and the selected one's name and pattern in labelled fields beneath, the pattern in the
/// colours of its fields and with the problem of its form. The last pattern stays.
struct SavedPatternsSection: View {
    private static let listHeight: CGFloat = 150

    @Bindable var settings: BrowserSettings
    @State private var selection: SavedPattern.ID?

    private var patterns: SavedPatterns { settings.savedPatterns }
    private var selected: SavedPattern? {
        patterns.patterns.first { $0.id == selection } ?? patterns.patterns.first
    }

    var body: some View {
        Section {
            List(selection: $selection) {
                ForEach(patterns.patterns) { pattern in
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .foregroundStyle(Color.accentColor)
                            .opacity(pattern.id == patterns.defaultPattern.id ? 1 : 0)
                            .accessibilityHidden(pattern.id != patterns.defaultPattern.id)
                            .accessibilityLabel(Text("Default"))
                        Text(pattern.name)
                    }
                    .tag(pattern.id)
                }
                .onMove { settings.savedPatterns.move(fromOffsets: $0, toOffset: $1) }
            }
            .frame(height: Self.listHeight)
            .listStyle(.bordered)
            HStack(spacing: 4) {
                Button {
                    if case .success(let id) = settings.savedPatterns.save(
                        name: String(localized: "New Pattern"), text: "{date:yyyy.MM.dd} {text}")
                    {
                        selection = id
                    }
                } label: {
                    Image(systemName: "plus")
                }
                .help(Text("Add Pattern"))
                .accessibilityLabel(Text("Add Pattern"))
                Button {
                    guard let selected else { return }
                    settings.savedPatterns.remove(selected.id)
                    selection = settings.savedPatterns.patterns.first?.id
                } label: {
                    Image(systemName: "minus")
                }
                .disabled(patterns.patterns.count == 1)
                .help(Text("Remove"))
                .accessibilityLabel(Text("Remove Pattern"))
                Spacer()
                Button("Make Default") {
                    if let selected { settings.savedPatterns.makeDefault(selected.id) }
                }
                .disabled(selected?.id == patterns.defaultPattern.id)
            }
            .buttonStyle(.borderless)
            if let selected {
                SavedPatternEditor(settings: settings, pattern: selected).id(selected.id)
            }
        } header: {
            Text("Name Patterns")
        } footer: {
            Text(
                "The default is offered to a folder without a pattern of its own. A folder keeps the version of a pattern it uses, and is offered a newer one."
            )
            .font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// The name and the pattern of the selected saved pattern. A pattern is kept when the user
/// commits it, with Return, by leaving the field or by leaving the pattern, not with each
/// key, as each change of the text is a version that folders are offered (ADR 0068).
private struct SavedPatternEditor: View {
    @Bindable var settings: BrowserSettings
    let pattern: SavedPattern
    @State private var name = ""
    @State private var text = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Name") {
                TextField("Name", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .labelsHidden()
                    // An empty name is not taken: the last one given stays.
                    .onChange(of: name) { _, new in
                        settings.savedPatterns.rename(pattern.id, to: new)
                    }
            }
            LabeledContent("Pattern") {
                VStack(alignment: .leading, spacing: 4) {
                    PatternField(
                        text: $text, insertion: nil, onSubmit: commit, onEndEditing: commit
                    )
                    .frame(height: 22)
                    .accessibilityLabel(Text("Pattern"))
                    if let problem = NameTemplate.problemInForm(of: text) {
                        Text(NameReviewText.text(for: problem))
                            .font(.caption).foregroundStyle(.red)
                    }
                }
            }
        }
        .onAppear {
            name = pattern.name
            text = pattern.text
        }
        .onDisappear(perform: commit)
    }

    /// Keeps the typed pattern when it can be read; the same text makes no new version.
    private func commit() {
        guard NameTemplate.problemInForm(of: text) == nil else { return }
        settings.savedPatterns.change(pattern.id, to: text)
    }
}
