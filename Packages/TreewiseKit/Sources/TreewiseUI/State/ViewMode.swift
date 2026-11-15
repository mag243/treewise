import Foundation
import TreewiseCore

/// How a window shows folders: as a list or as icons (ADR 0025).
public enum ViewMode: String, Codable, Sendable {
    case list, icons
}
