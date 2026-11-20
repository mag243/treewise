import SwiftUI
import TreewiseUI

/// The proposals beneath the name being renamed (ADR 0130): Show Suggestions until they
/// are asked, then the proposals to tap, or why there are none, the current name to go back
/// to, and the overview.
struct NameSheetProposals: View {
    let proposals: NameProposalsAsked
    @Binding var name: String
    /// The item's own name, offered last.
    let current: String
    let ask: () -> Void
    let openOverview: () -> Void

    var body: some View {
        Section {
            switch proposals.state {
            case .notAsked:
                Button(action: ask) {
                    Label("Show Suggestions", systemImage: "text.badge.star")
                }
            case .reading:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Reading the file…").foregroundStyle(.secondary)
                }
            case .answered:
                if let note = proposals.note {
                    Text(note).foregroundStyle(.secondary)
                }
                ForEach(Array(proposals.options.enumerated()), id: \.offset) { index, option in
                    Button {
                        name = option.name
                    } label: {
                        HStack {
                            Text(
                                NameMarkColors.text(
                                    option.name, marks: proposals.marks(of: option.name))
                            )
                            .foregroundStyle(Color.primary)
                            Spacer(minLength: 0)
                            if index == proposals.highlighted || option.name == name {
                                Image(systemName: "checkmark").foregroundStyle(.tint)
                            }
                        }
                    }
                    // The UI tests find it by it.
                    .accessibilityIdentifier("suggestion-\(index)")
                }
                if !proposals.options.contains(where: { $0.name == current }) {
                    currentName
                }
            }
            Button("Open Name Overview…", action: openOverview)
        } header: {
            Text("Suggestions")
        } footer: {
            Text("With a keyboard: ⌥Esc or F5 shows them, ↑ and ↓ choose.")
        }
    }

    /// The item's own name, to go back to after a proposal was taken.
    private var currentName: some View {
        Button {
            name = current
        } label: {
            HStack {
                Text(verbatim: current).foregroundStyle(Color.primary)
                Text("Current Name").foregroundStyle(Color.secondary)
                Spacer(minLength: 0)
                if name == current {
                    Image(systemName: "checkmark").foregroundStyle(.tint)
                }
            }
        }
        // The UI tests find it by it.
        .accessibilityIdentifier("currentName")
    }
}
