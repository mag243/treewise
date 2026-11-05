import SwiftUI
import TreewiseCore

/// The question of `ConflictQuestions`: the taken name, Keep Both, Replace
/// and Stop, and "Apply to All", with the Mac's words.
struct ConflictSheet: View {
    let questions: ConflictQuestions
    let name: String
    @State private var appliesToAll = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Do you want to replace it with the one you’re moving or copying?")
                    Toggle("Apply to All", isOn: $appliesToAll)
                } header: {
                    Text("An item named “\(name)” already exists in this location.")
                        .textCase(nil)
                        .font(.headline)
                }
                Section {
                    Button("Keep Both") { answer(.keepBoth) }
                    Button("Replace", role: .destructive) { answer(.replace) }
                    Button("Stop", role: .cancel) { answer(.stop) }
                }
            }
        }
        .presentationDetents([.medium])
        .interactiveDismissDisabled()
    }

    private func answer(_ decision: ConflictDecision) {
        questions.answer(decision, appliesToAll: appliesToAll)
    }
}
