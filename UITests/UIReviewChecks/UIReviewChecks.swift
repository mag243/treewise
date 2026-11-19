import XCTest

#if canImport(AppKit)
    import AppKit
#else
    import UIKit
#endif

/// What the UI review found wrong on one screen (ADR 0103).
struct UIReviewFinding: Codable, Hashable {
    /// The check that found it, as `outsideParent`.
    let check: String
    /// The element, as `staticText "File Name Patterns"`.
    let element: String
    /// What is wrong, with the sizes.
    let detail: String
}

/// The checks of the UI review (ADR 0103), on the frames of a window's elements: quirks a
/// screenshot shows and a behaviour test does not. Each looks at the elements on screen
/// only; a list's rows scrolled out of sight are left alone.
@MainActor
enum UIReviewChecks {
    /// What a frame may be off by, in points, as frames are rounded.
    private static let tolerance: CGFloat = 1
    /// The least room between a text or control and the side of the list holding it.
    static let listMargin: CGFloat = 4
    /// The least room between a text or control and the side of the window.
    static let windowMargin: CGFloat = 12
    /// The most a row may be taller than what it shows.
    static let emptyInRow: CGFloat = 40
    /// The least overlap, in square points, that counts as two elements overlapping.
    private static let overlapArea: CGFloat = 4
    /// The least depth of an overlap, in points, as text frames touch by a point.
    private static let overlapDepth: CGFloat = 2
    /// What a list may hold beyond its height without a scroller, as its insets.
    private static let scrollSlack: CGFloat = 4
    /// How far a line of text may sit from the middle of its row.
    static let centreSlack: CGFloat = 3
    /// The font of a list's rows, to measure what a text needs: the platform's own
    /// (ADR 0115).
    #if canImport(AppKit)
        static let listFont = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    #else
        static let listFont = UIFont.preferredFont(forTextStyle: .body)
    #endif
    /// How much wider than its frame a text must need to count as cut short; a heading in
    /// a smaller font than the list's needs less than it is measured at.
    static let cutSlack: CGFloat = 6
    /// The room after a text cut short that it could have used: more than the gap a list
    /// keeps before its next column.
    static let roomLeft: CGFloat = 24
    /// The margin a Settings pane keeps on either side, as `SettingsForm.margin`.
    static let settingsMargin: CGFloat = 20

    /// The elements that show something of their own, which are checked one by one.
    private static let leafTypes: Set<XCUIElement.ElementType> = [
        .staticText, .button, .checkBox, .radioButton, .textField, .secureTextField,
        .popUpButton, .menuButton, .image, .switch, .slider, .stepper, .link, .comboBox,
        .searchField, .textView, .toggle,
    ]
    /// The elements that hold others, which these must lie inside.
    private static let holderTypes: Set<XCUIElement.ElementType> = [
        .cell, .tableRow, .outlineRow, .group,
    ]

    /// An element on screen, with what holds it.
    struct Placed {
        let snapshot: any XCUIElementSnapshot
        /// The list it is in, if any.
        let list: CGRect?
        /// Whether that list has a scroller, so what it cuts off can be scrolled to.
        let listScrolls: Bool
        /// The nearest row, cell or group it is in, if any.
        let holder: (any XCUIElementSnapshot)?
    }

    /// The findings in `window`, or in the sheet on it. In a Settings pane, `isSettingsPane`
    /// also asks every list to take the pane's width between its margins and everything to
    /// keep the window's margin, as the panes share one layout. `readableLines` also asks
    /// running text to keep to a readable width, as on the iPad's wide screen (ADR 0115).
    static func findings(
        in window: any XCUIElementSnapshot, isSettingsPane: Bool = false,
        readableLines: Bool = false
    ) -> [UIReviewFinding] {
        var placed: [Placed] = []
        var lists: [any XCUIElementSnapshot] = []
        collect(window, in: nil, holder: nil, into: &placed, lists: &lists)
        let leaves = placed.filter { leafTypes.contains($0.snapshot.elementType) }
        var found: [UIReviewFinding] = []
        found += collapsed(leaves)
        found += outside(leaves, window: window.frame)
        found += overlapping(leaves)
        found += tooClose(leaves, window: window.frame, windowToo: isSettingsPane)
        found += emptyRows(placed)
        found += offCentre(placed)
        found += cutShortWithRoom(placed)
        #if canImport(UIKit)
            found += cutShort(placed)
        #endif
        found += offTitleLine(placed)
        found += withoutScroller(lists)
        found += twiceInAList(lists)
        if isSettingsPane { found += notSpanning(lists, window: window.frame) }
        if readableLines { found += overlongLines(placed) }
        return found
    }

    /// The list an element is in: its frame, and whether it has a scroller.
    private typealias InList = (frame: CGRect, scrolls: Bool)

    private static func collect(
        _ snapshot: any XCUIElementSnapshot, in list: InList?,
        holder: (any XCUIElementSnapshot)?, into placed: inout [Placed],
        lists: inout [any XCUIElementSnapshot]
    ) {
        let frame = snapshot.frame
        // What a list scrolled out of sight, above or below it, is not on screen; beside it,
        // it is cut off.
        if let list, !frame.isEmpty, frame.maxY <= list.frame.minY || frame.minY >= list.frame.maxY
        {
            return
        }
        placed.append(
            Placed(
                snapshot: snapshot, list: list?.frame, listScrolls: list?.scrolls ?? false,
                holder: holder))
        var list = list
        if snapshot.elementType == .scrollView {
            lists.append(snapshot)
            list = (frame, snapshot.children.contains { $0.elementType == .scrollBar })
        }
        let holds = holderTypes.contains(snapshot.elementType) ? snapshot : holder
        for child in snapshot.children {
            collect(child, in: list, holder: holds, into: &placed, lists: &lists)
        }
    }

    /// A text or field with words in it but no room to show them.
    private static func collapsed(_ leaves: [Placed]) -> [UIReviewFinding] {
        leaves.compactMap { leaf in
            let snapshot = leaf.snapshot
            guard snapshot.elementType == .staticText || snapshot.elementType == .textField,
                let words = snapshot.value as? String, !words.isEmpty,
                snapshot.frame.width < tolerance * 2 || snapshot.frame.height < tolerance * 2
            else { return nil }
            return finding("collapsed", snapshot, "\(snapshot.frame) for \"\(words)\"")
        }
    }

    /// A text or control outside its window, its list or its row: cut off on screen.
    private static func outside(_ leaves: [Placed], window: CGRect) -> [UIReviewFinding] {
        leaves.compactMap { leaf in
            let frame = leaf.snapshot.frame
            guard !frame.isEmpty else { return nil }
            if !contains(window, frame) {
                return finding(
                    "outsideWindow", leaf.snapshot, "\(frame) beyond the window \(window)")
            }
            // A list with a scroller shows the rest of a row it cuts off when scrolled.
            if let list = leaf.list, !leaf.listScrolls, !contains(list, frame) {
                return finding("cutByList", leaf.snapshot, "\(frame) cut by its list \(list)")
            }
            if let holder = leaf.holder, !holder.frame.isEmpty, !contains(holder.frame, frame) {
                return finding(
                    "outsideParent", leaf.snapshot,
                    "\(frame) beyond its \(name(of: holder.elementType)) \(holder.frame)")
            }
            return nil
        }
    }

    /// Two texts or controls over each other.
    private static func overlapping(_ leaves: [Placed]) -> [UIReviewFinding] {
        var found: [UIReviewFinding] = []
        let shown = leaves.filter { !visible($0).isEmpty }
        for (index, one) in shown.enumerated() {
            for other in shown[(index + 1)...] {
                let (first, second) = (visible(one), visible(other))
                // One inside the other, as the glass in a search field, is not over it.
                guard !first.contains(second), !second.contains(first) else { continue }
                let both = first.intersection(second)
                // Lines of text a point into each other are how text frames sit.
                guard !both.isNull, both.width * both.height > overlapArea,
                    min(both.width, both.height) > overlapDepth
                else { continue }
                found.append(
                    finding(
                        "overlap", one.snapshot,
                        "overlaps \(describe(other.snapshot)) by \(both.size)"))
            }
        }
        return found
    }

    /// The part of an element that shows: inside its list, which clips what it scrolls.
    private static func visible(_ placed: Placed) -> CGRect {
        guard let list = placed.list else { return placed.snapshot.frame }
        let inside = placed.snapshot.frame.intersection(list)
        return inside.isNull ? .zero : inside
    }

    /// A text or control against the side of its list or window.
    private static func tooClose(_ leaves: [Placed], window: CGRect, windowToo: Bool)
        -> [UIReviewFinding]
    {
        leaves.compactMap { leaf in
            let frame = leaf.snapshot.frame
            // The window's own buttons sit in its corner by design.
            guard !frame.isEmpty, !leaf.snapshot.identifier.hasPrefix("_XCUI") else { return nil }
            // A column's header meets the list's sides by design; texts and fields do not.
            let isText = [.staticText, .textField].contains(leaf.snapshot.elementType)
            // What runs past a list that scrolls sideways is scrolled to, not cramped.
            let runsPast = leaf.list.map { !contains($0, frame) } ?? false
            if let list = leaf.list, isText, !(leaf.listScrolls && runsPast),
                frame.minX - list.minX < listMargin - tolerance
                    || list.maxX - frame.maxX < listMargin - tolerance
            {
                return finding(
                    "listMargin", leaf.snapshot,
                    "\(frame) within \(listMargin) of its list's side \(list)")
            }
            if windowToo,
                frame.minX - window.minX < windowMargin - tolerance
                    || window.maxX - frame.maxX < windowMargin - tolerance
            {
                return finding(
                    "windowMargin", leaf.snapshot,
                    "\(frame) within \(windowMargin) of the window's side")
            }
            return nil
        }
    }

    /// A list that holds more than shows, without a scroller.
    private static func withoutScroller(_ lists: [any XCUIElementSnapshot]) -> [UIReviewFinding] {
        lists.compactMap { list in
            let content = list.children.filter {
                $0.elementType == .table || $0.elementType == .outline
            }
            let scrolls = list.children.contains { $0.elementType == .scrollBar }
            guard let tallest = content.map({ $0.frame.height }).max(),
                tallest > list.frame.height + scrollSlack, !scrolls
            else { return nil }
            return finding(
                "noScroller", list, "holds \(tallest) in \(list.frame.height) without a scroller")
        }
    }

    /// A list that shows the same item twice: two cards or rows of one name.
    private static func twiceInAList(_ lists: [any XCUIElementSnapshot]) -> [UIReviewFinding] {
        lists.flatMap { list -> [UIReviewFinding] in
            let items = outerGroups(in: list)
            var seen: Set<String> = []
            return items.compactMap { item in
                let name = item.label
                guard !name.isEmpty, !seen.insert(name).inserted else { return nil }
                return finding("twiceInAList", item, "shown more than once in its list")
            }
        }
    }

    /// The groups in `snapshot` that no other group holds, as a list's cards.
    private static func outerGroups(in snapshot: any XCUIElementSnapshot)
        -> [any XCUIElementSnapshot]
    {
        snapshot.children.flatMap { child in
            child.elementType == .group ? [child] : outerGroups(in: child)
        }
    }

    /// A list in Settings that does not take the pane's width between its margins.
    private static func notSpanning(_ lists: [any XCUIElementSnapshot], window: CGRect)
        -> [UIReviewFinding]
    {
        let left = window.minX + settingsMargin
        let width = window.width - 2 * settingsMargin
        return lists.compactMap { list in
            let frame = list.frame
            guard abs(frame.minX - left) > tolerance || abs(frame.width - width) > tolerance
            else { return nil }
            return finding(
                "paneWidth", list,
                "x \(frame.minX - window.minX), \(frame.width) wide; the pane's lists start at \(settingsMargin) and are \(width) wide"
            )
        }
    }

    static func leaves(
        in snapshot: any XCUIElementSnapshot, of types: Set<XCUIElement.ElementType>
    ) -> [any XCUIElementSnapshot] {
        let own = types.contains(snapshot.elementType) && !snapshot.frame.isEmpty
        return (own ? [snapshot] : []) + snapshot.children.flatMap { leaves(in: $0, of: types) }
    }

    static func leafFrames(
        in snapshot: any XCUIElementSnapshot, of types: Set<XCUIElement.ElementType>
    ) -> [CGRect] {
        let own = types.contains(snapshot.elementType) && !snapshot.frame.isEmpty
        return (own ? [snapshot.frame] : [])
            + snapshot.children.flatMap { leafFrames(in: $0, of: types) }
    }

    static func leafFrames(in snapshot: any XCUIElementSnapshot) -> [CGRect] {
        let own = leafTypes.contains(snapshot.elementType) && !snapshot.frame.isEmpty
        return (own ? [snapshot.frame] : []) + snapshot.children.flatMap(leafFrames(in:))
    }

    private static func contains(_ outer: CGRect, _ inner: CGRect) -> Bool {
        outer.insetBy(dx: -tolerance, dy: -tolerance).contains(inner)
    }

    static func finding(
        _ check: String, _ snapshot: any XCUIElementSnapshot, _ detail: String
    ) -> UIReviewFinding {
        UIReviewFinding(check: check, element: describe(snapshot), detail: detail)
    }

    /// The element as a person finds it: its kind and what it says or is called.
    static func describe(_ snapshot: any XCUIElementSnapshot) -> String {
        let value = snapshot.value.map { "\($0)" }
        let words =
            [snapshot.identifier, snapshot.label, snapshot.title, value ?? ""]
            .first { !$0.isEmpty } ?? ""
        return "\(name(of: snapshot.elementType)) \"\(words.prefix(60))\""
    }

    /// The words a finding uses for the kinds of elements it names.
    private static let names: [XCUIElement.ElementType: String] = [
        .staticText: "text", .button: "button", .checkBox: "checkbox", .textField: "field",
        .popUpButton: "pop-up", .image: "image", .scrollView: "list", .tableRow: "row",
        .outlineRow: "row", .cell: "cell", .group: "group", .switch: "switch", .toggle: "switch",
    ]

    private static func name(of type: XCUIElement.ElementType) -> String {
        names[type] ?? "element \(type.rawValue)"
    }
}
