/// Where a list scrolls to show the card selected (ADR 0092): the card whole, or its top
/// when it is taller than the list, moving as little as that takes.
public enum RevealScroll {
    /// The top to scroll the list to so `card` shows, or nil when it shows already.
    /// Positions run down from the top of the content.
    ///
    /// Precondition: `visibleHeight` is more than 0.
    public static func top(
        card: Range<Double>, visibleTop: Double, visibleHeight: Double, contentHeight: Double
    ) -> Double? {
        precondition(visibleHeight > 0, "visibleHeight is more than 0")
        let visibleBottom = visibleTop + visibleHeight
        var top = visibleTop
        if card.upperBound - card.lowerBound > visibleHeight || card.lowerBound < visibleTop {
            top = card.lowerBound
        } else if card.upperBound > visibleBottom {
            top = card.upperBound - visibleHeight
        }
        top = max(0, min(top, contentHeight - visibleHeight))
        return top == visibleTop ? nil : top
    }
}
