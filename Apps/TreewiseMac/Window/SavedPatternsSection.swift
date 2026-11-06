import SwiftUI
import TreewiseCore
import TreewiseUI

/// The saved patterns in Settings (ADR 0068): each with its name and its pattern in the
/// colours of its fields, the default chosen with its radio button, put in order by
/// dragging, added to and removed from. The last pattern stays.
struct SavedPatternsSection: View {
    @Bindable var settings: BrowserSettings

    var body: some View {
        Section {
            ForEach(settings.savedPatterns.patterns) { pattern in
                SavedPatternRow(settings: settings, pattern: pattern)
            }
            .onMove { settings.savedPatterns.move(fromOffsets: $0, toOffset: $1) }
            Button("Add Pattern") {
                _ = settings.savedPatterns.save(
                    name: String(localized: "New Pattern"), text: "{date:yyyy.MM.dd} {text}")
            }
        } header: {
            Text("Name Patterns")
        } footer: {
            Text(
                "The default is offered to a folder without a pattern of its own. Folders keep their own copy of a pattern."
            )
            .font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// One saved pattern.
private struct SavedPatternRow: View {
    @Bindable var settings: BrowserSettings
    let pattern: SavedPattern
    @State private var name = ""
    @State private var text = ""

    private var patterns: SavedPatterns { settings.savedPatterns }
    private var isDefault: Bool { patterns.defaultPattern.id == pattern.id }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Button {
                settings.savedPatterns.makeDefault(pattern.id)
            } label: {
                Image(systemName: isDefault ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isDefault ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(isDefault ? Text("The default") : Text("Make Default"))
            .accessibilityLabel(Text("Default"))
            .accessibilityValue(isDefault ? Text("On") : Text("Off"))
            VStack(alignment: .leading, spacing: 2) {
                TextField("Name", text: $name)
                    // An empty name is not taken: the last one given stays.
                    .onChange(of: name) { _, new in
                        settings.savedPatterns.rename(pattern.id, to: new)
                    }
                PatternField(text: $text, insertion: nil, onSubmit: {})
                    .frame(height: 20)
                    .onChange(of: text) { _, new in
                        if NameTemplate.problemInForm(of: new) == nil {
                            settings.savedPatterns.change(pattern.id, to: new)
                        }
                    }
                if let problem = NameTemplate.problemInForm(of: text) {
                    Text(NameReviewText.text(for: problem))
                        .font(.caption).foregroundStyle(.red)
                }
            }
            Button {
                settings.savedPatterns.remove(pattern.id)
            } label: {
                Image(systemName: "minus.circle")
            }
            .buttonStyle(.plain)
            .disabled(patterns.patterns.count == 1)
            .help(Text("Remove"))
            .accessibilityLabel(Text("Remove \(pattern.name)"))
        }
        .onAppear {
            name = pattern.name
            text = pattern.text
        }
        .accessibilityActions {
            Button("Move Up") { move(by: -1) }
            Button("Move Down") { move(by: 1) }
        }
    }

    private func move(by offset: Int) {
        guard let index = patterns.patterns.firstIndex(where: { $0.id == pattern.id }) else {
            return
        }
        let target = index + offset
        guard patterns.patterns.indices.contains(target) else { return }
        settings.savedPatterns.move(
            fromOffsets: IndexSet(integer: index), toOffset: offset > 0 ? target + 1 : target)
    }
}
