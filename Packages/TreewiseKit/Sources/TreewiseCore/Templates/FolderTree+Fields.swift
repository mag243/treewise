/// A template's fields across its tree, what they are filled in with, and what the sheet
/// proposes for them (ADR 0095, ADR 0096).
extension FolderTree {
    /// The years a folder's own name counts as one, as in ADR 0090.
    private static let years = 1900...2099
    private static let yearDigits = 4

    /// The fields of the tree, each once, in the order they first appear from the root down.
    /// A name with a field it cannot read counts as plain text here; `checkTemplate()` says
    /// why.
    public var fields: [FolderTemplateField] {
        var found: [FolderTemplateField] = []
        collectFields(into: &found)
        return found
    }

    private func collectFields(into found: inout [FolderTemplateField]) {
        for field in (try? FolderNameFields(name))?.fields ?? [] where !found.contains(field) {
            found.append(field)
        }
        for folder in folders { folder.collectFields(into: &found) }
    }

    /// The fields below the root, for a template that fills a folder already there, whose
    /// name stays as it is (ADR 0095, ADR 0097).
    public var fieldsBelowRoot: [FolderTemplateField] {
        FolderTree(name: "", folders: folders).fields
    }

    /// The tree with its root named `name`, for filling a folder of that name that is
    /// already there: only the folders below it are made (ADR 0095, ADR 0097).
    public func filling(folderNamed name: String) -> FolderTree {
        FolderTree(name: name, folders: folders)
    }

    /// Whether a name in the tree holds `{year}` or `{year:yy}`.
    public var hasYear: Bool { fields.contains(.year) }

    /// The tree with each field that has a value written in, in its format; a field without
    /// one stays as written.
    public func filling(_ values: FolderTemplateValues) -> FolderTree {
        FolderTree(
            name: (try? FolderNameFields(name))?.filled(with: values) ?? name,
            folders: folders.map { $0.filling(values) })
    }

    /// The tree with its year written in, and its other fields as written.
    public func filling(year: Int) -> FolderTree {
        filling(FolderTemplateValues(year: year))
    }

    /// The number the root's `{seq}` proposes among `names`, the folders beside it: the one
    /// after the highest that fits the root's name with `values` written in, so a number
    /// counts within the year chosen; nil when the root has no `{seq}` (ADR 0096).
    public func proposedNumber(beside names: [String], values: FolderTemplateValues)
        -> FolderTemplateValues.Number?
    {
        guard let read = try? FolderNameFields(name) else { return nil }
        var hasNumber = false
        let parts: [NameTemplate.Part] = read.pieces.map { piece in
            switch piece {
            case .text(let text): return .text(text)
            case .number(let series, _):
                hasNumber = true
                return .counter(series)
            case .field(let field, let format, _):
                if let filled = FolderNameFields.write(field, format, values) {
                    return .text(filled)
                }
                return .field(Self.patternField(field), format: format)
            }
        }
        guard hasNumber else { return nil }
        let context = NameTemplate.Context(siblingNames: names, currentName: "", fileYear: nil)
        guard let seq = NameTemplate.nextPeriod(for: parts, context: context, fixed: [:]).seq,
            let value = Int(seq)
        else { return nil }
        return FolderTemplateValues.Number(value: value, width: seq.count)
    }

    private static func patternField(_ field: FolderTemplateField) -> NameTemplate.Field {
        switch field {
        case .year: NameTemplate.Field.year
        case .text: NameTemplate.Field(name: "text", kind: .text)
        case .date: NameTemplate.Field(name: "date", kind: .date)
        case .number: NameTemplate.Field.seq
        }
    }

    /// The year the sheet proposes for making the tree in a folder holding `contents`: the
    /// highest year among its folders when that one lacks folders of the tree, else the one
    /// after it, and `currentYear` when no folder's name is a year. A tree with fields
    /// besides the year cannot say what a year lacks, so it proposes the one after.
    public func proposedYear(in contents: FolderContents, currentYear: Int) -> Int {
        let years = contents.folderNames.compactMap { name -> Int? in
            guard name.count == Self.yearDigits, name.allSatisfy({ $0.isASCII && $0.isNumber }),
                let year = Int(name), Self.years.contains(year)
            else { return nil }
            return year
        }
        guard let highest = years.max() else { return currentYear }
        guard fields.allSatisfy({ $0 == .year }) else { return highest + 1 }
        let plan = FolderTemplatePlan(making: filling(year: highest), in: contents)
        let lacks = plan.entries.contains { $0.state == .new }
        return lacks && contents.folder(named: String(highest)) != nil ? highest : highest + 1
    }
}
