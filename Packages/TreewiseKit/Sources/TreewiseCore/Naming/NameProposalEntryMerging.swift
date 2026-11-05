extension NameProposalSession.Entry {
    /// Adds proposals without changing what is chosen, except that the first valid
    /// proposal becomes the choice while there is none.
    mutating func add(_ newProposals: [NameProposal], moduleOrder: [String]) {
        for proposal in newProposals { add(proposal, moduleOrder: moduleOrder) }
        let rank = { (option: Option) in
            moduleOrder.firstIndex { option.moduleIDs.first == $0 } ?? moduleOrder.count
        }
        let gap = { (option: Option) in option.name.contains(NameTemplate.gap) ? 1 : 0 }
        // The offset keeps each module's ranking as it arrived.
        proposals = proposals.enumerated().sorted {
            (rank($0.element), gap($0.element), $0.offset)
                < (rank($1.element), gap($1.element), $1.offset)
        }.map(\.element)
        mergeEdit()
        selectBestIfNone()
    }

    /// Replaces what one module proposed. A chosen name that is gone gives way to the
    /// best one, unless it was approved: then it stays, as the user's own.
    mutating func replaceProposals(
        _ newProposals: [NameProposal], from moduleID: String, moduleOrder: [String]
    ) {
        let previous = currentName
        for index in proposals.indices {
            proposals[index].moduleIDs.removeAll { $0 == moduleID }
        }
        proposals.removeAll { $0.moduleIDs.isEmpty }
        for proposal in newProposals { add(proposal, moduleOrder: moduleOrder) }
        if case .proposal = selection, currentName == nil {
            if state == .approved, let previous {
                edit = previous
                selection = .edit
            } else {
                selection = .none
            }
        }
        add([], moduleOrder: moduleOrder)
    }

    /// Ends an edit: an empty one goes away, and one equal to a proposal merges with it.
    mutating func finishEditing() {
        guard let text = edit else { return }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            discardEdit()
        } else {
            mergeEdit()
        }
    }

    /// Removes the edit and returns to the best proposal.
    mutating func discardEdit() {
        edit = nil
        selection = .none
        state = .pending
        selectBestIfNone()
    }

    private mutating func add(_ proposal: NameProposal, moduleOrder: [String]) {
        guard
            case .success(let name) = ProposedName.resolve(
                proposal, for: originalName, kind: kind),
            name != ProposedName.shownName(fromDisk: originalName)
        else { return }
        let key = Self.key(name)
        guard let index = proposals.firstIndex(where: { Self.key($0.name) == key }) else {
            proposals.append(
                Option(name: name, moduleIDs: [proposal.moduleID], dateSource: proposal.dateSource))
            return
        }
        guard !proposals[index].moduleIDs.contains(proposal.moduleID) else { return }
        let rank = { (id: String) in moduleOrder.firstIndex(of: id) ?? moduleOrder.count }
        if let first = proposals[index].moduleIDs.first, rank(proposal.moduleID) < rank(first) {
            proposals[index].name = name
            proposals[index].dateSource = proposal.dateSource
        }
        proposals[index].moduleIDs.append(proposal.moduleID)
        proposals[index].moduleIDs.sort { rank($0) < rank($1) }
    }

    /// An edit equal to a proposal stops being an option of its own. A name that differs
    /// in case stays the user's, because that is usually deliberate.
    private mutating func mergeEdit() {
        guard let text = edit, proposals.contains(where: { $0.name == text }) else { return }
        if selection == .edit { selection = .proposal(key: Self.key(text)) }
        edit = nil
    }

    private mutating func selectBestIfNone() {
        if selection == .none, let best = proposals.first {
            selection = .proposal(key: Self.key(best.name))
        }
    }
}
