import TreewiseCore
import TreewiseModuleInterface

/// The words the overview uses for what the model knows.
@MainActor
public enum NameReviewText {
    /// A module's name. The folder pattern module's is here; a paid module brings its own later.
    public static func name(of module: NameReviewModule) -> String {
        module.description.name ?? name(ofModule: module.id)
    }

    /// The name of an add-on: its own, or the app's for it.
    public static func name(of module: AddOnDescription) -> String {
        module.name ?? name(ofModule: module.id)
    }

    /// The name of the add-on with this id.
    public static func name(ofModule id: String) -> String {
        id == AddOnDescription.defaultModuleID
            ? String(localized: "Folder Pattern", bundle: .module)
            : id.components(separatedBy: ".").last ?? id
    }

    /// Names the modules behind an option.
    public static func names(ofModules ids: [String], in model: NameReviewModel) -> String {
        ids.map { id in
            if id == NameProposal.treewiseID {
                return String(localized: "Treewise", bundle: .module)
            }
            return model.modules.first { $0.id == id }.map(name) ?? id
        }.joined(separator: ", ")
    }

    /// Where a module's pattern comes from.
    public static func origin(of module: NameReviewModule) -> String {
        switch module.origin {
        case .derived:
            if module.recognizedInYearBefore {
                String(localized: "recognized in the same folder a year before", bundle: .module)
            } else if !module.isClearlyRecognized, let fit = module.recognizedFit {
                String(localized: "recognized from \(fit.fits) of \(fit.of) names", bundle: .module)
            } else {
                String(localized: "recognized in this folder", bundle: .module)
            }
        case .moduleDefault: String(localized: "add-on's default", bundle: .module)
        case .user: String(localized: "changed by you", bundle: .module)
        case .notRecognized:
            if module.hasTooFewNamesForAPattern {
                String(
                    localized:
                        "no pattern yet: a pattern needs at least \(PatternFit.minimumFits) names")
            } else {
                String(localized: "no pattern recognized in this folder", bundle: .module)
            }
        case .usersDefault:
            String(localized: "your default, as files were selected", bundle: .module)
        }
    }

    /// Why a pattern cannot be used.
    public static func text(for problem: NameTemplate.Problem) -> String {
        switch problem {
        case .nothingRequired:
            String(localized: "A pattern needs something that is not optional", bundle: .module)
        case .unbalancedBraces: String(localized: "Every { needs its }", bundle: .module)
        case .unbalancedBrackets: String(localized: "Every [ needs its ]", bundle: .module)
        case .nestedOptionalParts: String(localized: "Optional parts cannot nest", bundle: .module)
        case .unbalancedAngleBrackets: String(localized: "Every < needs its >", bundle: .module)
        case .emptyAlternative:
            String(localized: "A choice between < and > has an empty part", bundle: .module)
        case .nestedChoiceOfParts:
            String(
                localized:
                    "A choice between < and > cannot hold another choice, or [ ] with a field")
        case .unknownField(let field):
            String(localized: "This add-on has no field {\(field)}", bundle: .module)
        case .containsPathSeparator: String(localized: "A pattern cannot hold :", bundle: .module)
        case .invalidFormat:
            String(
                localized:
                    "After : comes a date format; 4, 2-4, 2,4,6, 5- or 001- after {seq}, with :3 for a width; yy after {year}; a number after {folder}; or lower, upper or title"
            )
        }
    }

    /// Why a name cannot be used.
    public static func text(for problem: ProposedNameProblem) -> String? {
        switch problem {
        case .noName, .empty: nil
        case .unchanged: String(localized: "This is the name it already has", bundle: .module)
        case .hasGap: String(localized: "Fill in the gap to approve", bundle: .module)
        case .containsPathSeparator: String(localized: "A name cannot hold :", bundle: .module)
        case .containsControlCharacter:
            String(localized: "A name cannot hold control characters", bundle: .module)
        case .startsWithDot:
            String(localized: "A name starting with a dot would hide the file", bundle: .module)
        case .tooLong: String(localized: "This name is too long", bundle: .module)
        }
    }

    /// What a name collides with.
    public static func text(for conflict: BatchRenameConflict.Kind) -> String {
        switch conflict {
        case .duplicateInBatch:
            String(localized: "Another file in this list wants this name", bundle: .module)
        case .nameTaken:
            String(localized: "This folder already has a file with this name", bundle: .module)
        }
    }

    /// What personal data a proposed name holds (ADR 0060).
    public static func text(for data: PersonalData) -> String {
        switch data {
        case .emailAddress:
            String(localized: "This name contains an e-mail address", bundle: .module)
        case .iban: String(localized: "This name contains a bank account number", bundle: .module)
        case .paymentCard:
            String(localized: "This name contains a payment card number", bundle: .module)
        case .phoneNumber: String(localized: "This name contains a phone number", bundle: .module)
        }
    }
}
