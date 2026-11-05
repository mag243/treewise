import CoreGraphics
import TreewiseUI

extension RowDensity {
    /// The list's row height for the density (ADR 0023).
    var rowHeight: CGFloat {
        switch self {
        case .small: 20
        case .medium: 24
        case .large: 30
        }
    }
}
