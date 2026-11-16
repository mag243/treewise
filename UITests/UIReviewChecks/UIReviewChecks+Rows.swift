import XCTest

#if canImport(AppKit)
    import AppKit
#else
    import UIKit
#endif

/// The UI review's checks of a list's rows (ADR 0103): a row far taller than what it shows,
/// a line of text off its middle, and a text cut short while the row has room after it.
extension UIReviewChecks {
    /// A row far taller than what it shows: room left from a card that was taller.
    static func emptyRows(_ placed: [Placed]) -> [UIReviewFinding] {
        placed.compactMap { item in
            let row = item.snapshot
            guard row.elementType == .tableRow || row.elementType == .cell else { return nil }
            let shown = leafFrames(in: row).reduce(CGRect.null) { $0.union($1) }
            guard !shown.isNull, row.frame.height - shown.height > emptyInRow else { return nil }
            return finding(
                "emptyRow", row, "\(row.frame.height) tall for \(shown.height) of content")
        }
    }

    /// A row of one line whose text sits above or below its middle.
    static func offCentre(_ placed: [Placed]) -> [UIReviewFinding] {
        placed.compactMap { item in
            let row = item.snapshot
            guard row.elementType == .tableRow || row.elementType == .outlineRow else {
                return nil
            }
            let texts = leafFrames(in: row, of: [.staticText, .textField])
            let shown = texts.reduce(CGRect.null) { $0.union($1) }
            // Only a row of one line: a card or a row of several lines has its own layout.
            guard !shown.isNull, texts.allSatisfy({ abs($0.midY - shown.midY) < centreSlack })
            else { return nil }
            let off = shown.midY - row.frame.midY
            guard abs(off) > centreSlack else { return nil }
            return finding("offCentre", row, "text \(off) from the middle of its row")
        }
    }

    /// A text in a row of a list cut short, with `…`, while the row has room after it: the
    /// text could have shown more. The width it needs is measured in the list's font.
    static func cutShortWithRoom(_ placed: [Placed]) -> [UIReviewFinding] {
        placed.compactMap { item in
            let row = item.snapshot
            guard row.elementType == .tableRow || row.elementType == .outlineRow else {
                return nil
            }
            // Only a row's own texts are in the list's font; a group in a row, as a card,
            // has fonts of its own.
            let texts = rowTexts(in: row)
            return texts.lazy.compactMap { text -> UIReviewFinding? in
                guard let words = text.value as? String, !words.isEmpty else { return nil }
                let needs = (words as NSString).size(withAttributes: [.font: listFont]).width
                guard needs > text.frame.width + cutSlack else { return nil }
                // The room after it: up to the next thing in the row, or the row's end.
                let next = texts.map(\.frame.minX).filter { $0 >= text.frame.maxX }.min()
                let room = (next ?? row.frame.maxX) - text.frame.maxX
                guard room > roomLeft else { return nil }
                return finding(
                    "cutShortWithRoom", text,
                    "needs \(Int(needs)) in \(Int(text.frame.width)), with \(Int(room)) free after it"
                )
            }.first
        }
    }

    /// The texts of a row, leaving out those in a group inside it.
    static func rowTexts(in snapshot: any XCUIElementSnapshot) -> [any XCUIElementSnapshot] {
        snapshot.children.flatMap { child -> [any XCUIElementSnapshot] in
            if child.elementType == .group { return [] }
            let own =
                [.staticText, .textField].contains(child.elementType) && !child.frame.isEmpty
            return (own ? [child] : []) + rowTexts(in: child)
        }
    }

    /// The most a text of several lines may sit beside its card's title without counting as
    /// meant to stand elsewhere.
    static let offTitleMost: CGFloat = 40
    /// The least it must sit beside it to count as off the title's line.
    static let offTitleLeast: CGFloat = 2

    /// A text of several lines in a card that starts just beside the card's title instead of
    /// under it, as a body pushed aside by something before the title.
    static func offTitleLine(_ placed: [Placed]) -> [UIReviewFinding] {
        placed.compactMap { item in
            let group = item.snapshot
            guard group.elementType == .group else { return nil }
            let texts = group.children.flatMap { leaves(in: $0, of: [.staticText]) }
            guard let title = texts.first else { return nil }
            let lines = texts.dropFirst().filter { $0.frame.height > 2 * title.frame.height }
            return lines.lazy.compactMap { text -> UIReviewFinding? in
                let off = abs(text.frame.minX - title.frame.minX)
                guard off > offTitleLeast, off < offTitleMost else { return nil }
                return finding(
                    "offTitleLine", text,
                    "starts \(Int(off)) beside its title \(describe(title)) instead of under it")
            }.first
        }
    }
}
