import Foundation

enum SidebarItem: Identifiable, Hashable, Sendable {
    case file(id: UUID, fileName: String)
    case trackGroup(id: UUID, trackType: TrackType, count: Int)
    case track(id: UUID, track: MKVTrack)
    case attachmentGroup(id: UUID, count: Int)
    case attachment(id: UUID, attachment: MKVAttachment)
    case chapterGroup(id: UUID, count: Int)

    var id: UUID {
        switch self {
        case .file(let id, _): id
        case .trackGroup(let id, _, _): id
        case .track(let id, _): id
        case .attachmentGroup(let id, _): id
        case .attachment(let id, _): id
        case .chapterGroup(let id, _): id
        }
    }

    var displayName: String {
        switch self {
        case .file(_, let fileName):
            return fileName
        case .trackGroup(_, let trackType, let count):
            return "\(trackType.displayName) (\(count))"
        case .track(_, let track):
            return track.displayName
        case .attachmentGroup(_, let count):
            return "Attachments (\(count))"
        case .attachment(_, let attachment):
            return attachment.displayName
        case .chapterGroup(_, let count):
            return "Chapters (\(count))"
        }
    }

    var systemImage: String {
        switch self {
        case .file: "doc"
        case .trackGroup(_, let trackType, _): trackType.systemImage
        case .track(_, let track): track.type.systemImage
        case .attachmentGroup: "paperclip"
        case .attachment: "paperclip"
        case .chapterGroup: "list.number"
        }
    }

    static func == (lhs: SidebarItem, rhs: SidebarItem) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
