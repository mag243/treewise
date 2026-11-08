import TreewiseCore
import TreewiseModuleInterface
import TreewiseUI

/// The words the overview uses for what the model knows.
@MainActor
enum NameReviewText {
    /// A module's name. The folder pattern module's is here; a paid module brings its own later.
    static func name(of module: NameReviewModule) -> String {
        module.description.name ?? name(ofModule: module.id)
    }

    /// The name of an add-on: its own, or the app's for it.
    static func name(of module: NameModuleDescription) -> String {
        module.name ?? name(ofModule: module.id)
    }

    /// The name of the add-on with this id.
    static func name(ofModule id: String) -> String {
        id == NameModuleDescription.defaultModuleID
            ? String(localized: "Folder Pattern")
            : id.components(separatedBy: ".").last ?? id
    }

    /// Names the modules behind an option.
    static func names(ofModules ids: [String], in model: NameReviewModel) -> String {
        ids.map { id in
            if id == NameProposal.treewiseID { return String(localized: "Treewise") }
            return model.modules.first { $0.id == id }.map(name) ?? id
        }.joined(separator: ", ")
    }

    /// Where a module's pattern comes from.
    static func origin(of module: NameReviewModule) -> String {
        switch module.origin {
        case .derived:
            if !module.isClearlyRecognized, let fit = module.recognizedFit {
                String(localized: "recognized from \(fit.fits) of \(fit.of) names")
            } else {
                String(localized: "recognized in this folder")
            }
        case .moduleDefault: String(localized: "add-on's default")
        case .user: String(localized: "changed by you")
        case .notRecognized: String(localized: "no pattern recognized in this folder")
        case .usersDefault: String(localized: "your default, as files were selected")
        }
    }

    /// Why a pattern cannot be used.
    static func text(for problem: NameTemplate.Problem) -> String {
        switch problem {
        case .nothingRequired: String(localized: "A pattern needs something that is not optional")
        case .unbalancedBraces: String(localized: "Every { needs its }")
        case .unbalancedBrackets: String(localized: "Every [ needs its ]")
        case .nestedOptionalParts: String(localized: "Optional parts cannot nest")
        case .unbalancedAngleBrackets: String(localized: "Every < needs its >")
        case .emptyAlternative: String(localized: "A choice between < and > has an empty part")
        case .nestedChoiceOfParts:
            String(
                localized:
                    "A choice between < and > cannot hold another choice, or [ ] with a field")
        case .unknownField(let field): String(localized: "This add-on has no field {\(field)}")
        case .containsPathSeparator: String(localized: "A pattern cannot hold :")
        case .invalidFormat:
            String(localized: "After : comes a date format, or a number from 2 after {seq}")
        }
    }

    /// Why a name cannot be used.
    static func text(for problem: ProposedNameProblem) -> String? {
        switch problem {
        case .noName, .empty: nil
        case .unchanged: String(localized: "This is the name it already has")
        case .hasGap: String(localized: "Fill in the gap to approve")
        case .containsPathSeparator: String(localized: "A name cannot hold :")
        case .containsControlCharacter: String(localized: "A name cannot hold control characters")
        case .startsWithDot: String(localized: "A name starting with a dot would hide the file")
        case .tooLong: String(localized: "This name is too long")
        }
    }

    /// What a name collides with.
    static func text(for conflict: BatchRenameConflict.Kind) -> String {
        switch conflict {
        case .duplicateInBatch: String(localized: "Another file in this list wants this name")
        case .nameTaken: String(localized: "This folder already has a file with this name")
        }
    }

    /// What personal data a proposed name holds (ADR 0060).
    static func text(for data: PersonalData) -> String {
        switch data {
        case .emailAddress: String(localized: "This name contains an e-mail address")
        case .iban: String(localized: "This name contains a bank account number")
        case .paymentCard: String(localized: "This name contains a payment card number")
        case .phoneNumber: String(localized: "This name contains a phone number")
        }
    }
}
