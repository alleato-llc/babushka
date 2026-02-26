import Foundation

struct SidebarTreeBuilder: Sendable {
    struct Result: Sendable {
        let items: [SidebarItem]
        let children: [UUID: [SidebarItem]]
    }

    static func build(
        fileId: UUID,
        fileName: String,
        identification: MKVIdentification,
        existingChildren: [UUID: [SidebarItem]]?
    ) -> Result {
        // Build mappings from existing children for UUID preservation
        var trackIdToUUID: [Int: UUID] = [:]
        var trackTypeToGroupUUID: [TrackType: UUID] = [:]
        var attachmentGroupUUID: UUID?
        var attachmentIdToUUID: [Int: UUID] = [:]

        if let existingChildren {
            for (_, children) in existingChildren {
                for child in children {
                    switch child {
                    case .track(let uuid, let track):
                        trackIdToUUID[track.id] = uuid
                    case .trackGroup(let uuid, let trackType, _):
                        trackTypeToGroupUUID[trackType] = uuid
                    case .attachmentGroup(let uuid, _):
                        attachmentGroupUUID = uuid
                    case .attachment(let uuid, let attachment):
                        attachmentIdToUUID[attachment.id] = uuid
                    default:
                        break
                    }
                }
            }
        }

        var items: [SidebarItem] = []
        var children: [UUID: [SidebarItem]] = [:]

        let fileItem = SidebarItem.file(id: fileId, fileName: fileName)
        items.append(fileItem)

        let tracksByType = Dictionary(grouping: identification.tracks) { $0.type }
        let sortedTypes = tracksByType.keys.sorted { $0.sortOrder < $1.sortOrder }

        var fileChildren: [SidebarItem] = []

        for trackType in sortedTypes {
            guard let tracks = tracksByType[trackType], !tracks.isEmpty else { continue }

            let groupId = trackTypeToGroupUUID[trackType] ?? UUID()
            let groupItem = SidebarItem.trackGroup(id: groupId, trackType: trackType, count: tracks.count)
            fileChildren.append(groupItem)

            let trackItems = tracks.map { track in
                let trackUUID = trackIdToUUID[track.id] ?? UUID()
                return SidebarItem.track(id: trackUUID, track: track)
            }
            children[groupId] = trackItems
        }

        if !identification.attachments.isEmpty {
            let groupId = attachmentGroupUUID ?? UUID()
            let groupItem = SidebarItem.attachmentGroup(id: groupId, count: identification.attachments.count)
            fileChildren.append(groupItem)

            let attachmentItems = identification.attachments.map { attachment in
                let attachmentUUID = attachmentIdToUUID[attachment.id] ?? UUID()
                return SidebarItem.attachment(id: attachmentUUID, attachment: attachment)
            }
            children[groupId] = attachmentItems
        }

        children[fileId] = fileChildren
        return Result(items: items, children: children)
    }
}
