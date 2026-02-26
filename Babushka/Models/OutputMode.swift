import Foundation

enum OutputMode: String, Sendable, CaseIterable, Identifiable {
    case backup
    case inline
    case specifyLocation

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .backup: "Backup original"
        case .inline: "Overwrite in place"
        case .specifyLocation: "Choose location..."
        }
    }
}
