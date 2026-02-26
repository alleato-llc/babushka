import Foundation
import SwiftUI

enum FileLoadingState: Sendable {
    case idle
    case loading
    case loaded(MKVIdentification)
    case error(String)
}

@Observable
@MainActor
final class FileViewModel: Identifiable {
    let id = UUID()
    let filePath: String
    let fileName: String

    private(set) var state: FileLoadingState = .idle
    private(set) var sidebarItems: [SidebarItem] = []
    private(set) var sidebarChildren: [UUID: [SidebarItem]] = [:]

    private(set) var changeset = PendingChangeset()

    private let service: MKVToolnixService

    init(filePath: String, service: MKVToolnixService) {
        self.filePath = filePath
        self.fileName = URL(fileURLWithPath: filePath).lastPathComponent
        self.service = service
    }

    var identification: MKVIdentification? {
        if case .loaded(let id) = state { return id }
        return nil
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var errorMessage: String? {
        if case .error(let msg) = state { return msg }
        return nil
    }

    func load() async {
        state = .loading
        do {
            let identification = try await service.identify(filePath: filePath)
            state = .loaded(identification)
            buildSidebarTree(from: identification)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func reload() async {
        do {
            let identification = try await service.identify(filePath: filePath)
            state = .loaded(identification)
            rebuildSidebarTree(from: identification)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func rebuildSidebarTree(from identification: MKVIdentification) {
        // Build a mapping from track ID → existing sidebar UUID to preserve selection
        var trackIdToUUID: [Int: UUID] = [:]
        var trackTypeToGroupUUID: [TrackType: UUID] = [:]
        var attachmentGroupUUID: UUID?
        var attachmentIdToUUID: [Int: UUID] = [:]

        for (_, children) in sidebarChildren {
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

        var items: [SidebarItem] = []
        var children: [UUID: [SidebarItem]] = [:]

        let fileItem = SidebarItem.file(id: id, fileName: fileName)
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

        children[id] = fileChildren
        sidebarItems = items
        sidebarChildren = children
    }

    private func buildSidebarTree(from identification: MKVIdentification) {
        var items: [SidebarItem] = []
        var children: [UUID: [SidebarItem]] = [:]

        let fileItem = SidebarItem.file(id: id, fileName: fileName)
        items.append(fileItem)

        // Group tracks by type in order: Video, Audio, Subtitles, Unknown
        let tracksByType = Dictionary(grouping: identification.tracks) { $0.type }
        let sortedTypes = tracksByType.keys.sorted { $0.sortOrder < $1.sortOrder }

        var fileChildren: [SidebarItem] = []

        for trackType in sortedTypes {
            guard let tracks = tracksByType[trackType], !tracks.isEmpty else { continue }

            let groupId = UUID()
            let groupItem = SidebarItem.trackGroup(id: groupId, trackType: trackType, count: tracks.count)
            fileChildren.append(groupItem)

            let trackItems = tracks.map { track in
                SidebarItem.track(id: UUID(), track: track)
            }
            children[groupId] = trackItems
        }

        // Attachments
        if !identification.attachments.isEmpty {
            let groupId = UUID()
            let groupItem = SidebarItem.attachmentGroup(id: groupId, count: identification.attachments.count)
            fileChildren.append(groupItem)

            let attachmentItems = identification.attachments.map { attachment in
                SidebarItem.attachment(id: UUID(), attachment: attachment)
            }
            children[groupId] = attachmentItems
        }

        children[id] = fileChildren
        sidebarItems = items
        sidebarChildren = children
    }

    func containsItem(withId itemId: UUID) -> Bool {
        if id == itemId { return true }
        for (_, children) in sidebarChildren {
            if children.contains(where: { $0.id == itemId }) { return true }
        }
        return false
    }

    func findItem(withId itemId: UUID) -> SidebarItem? {
        for item in sidebarItems {
            if item.id == itemId { return item }
        }
        for (_, children) in sidebarChildren {
            for child in children {
                if child.id == itemId { return child }
            }
        }
        return nil
    }

    func track(for sidebarItem: SidebarItem) -> MKVTrack? {
        if case .track(_, let track) = sidebarItem {
            return track
        }
        return nil
    }

    func attachment(for sidebarItem: SidebarItem) -> MKVAttachment? {
        if case .attachment(_, let attachment) = sidebarItem {
            return attachment
        }
        return nil
    }

    // MARK: - Changeset

    var resolvedChangeset: ResolvedChangeset {
        changeset.resolve(originalTracks: identification?.tracks ?? [])
    }

    var hasPendingChanges: Bool { !changeset.isEmpty }

    var canUndo: Bool { changeset.canUndo }

    var canRedo: Bool { changeset.canRedo }

    func editTrackProperties(trackId: Int, trackUid: UInt64?, edits: TrackPropertyEdits) {
        changeset.editProperties(trackId: trackId, trackUid: trackUid, edits: edits)
    }

    func markTrackForRemoval(trackId: Int) {
        changeset.removeTrack(trackId: trackId)
    }

    func addTrackFile(_ addition: TrackFileAddition) {
        changeset.addTrack(addition)
    }

    func reorderTracks(order: [Int]) {
        changeset.reorder(trackOrder: order)
    }

    func undoLastChange() {
        changeset.undo()
    }

    func redoLastChange() {
        changeset.redo()
    }

    func cancelAllChanges() {
        changeset.cancelAll()
    }

    // MARK: - Effective Value Queries

    func effectiveTrackName(for track: MKVTrack) -> String {
        let resolved = resolvedChangeset
        if let edits = resolved.propertyEdits[track.id], let name = edits.trackName {
            return name
        }
        return track.properties.trackName ?? ""
    }

    func effectiveLanguage(for track: MKVTrack) -> String {
        let resolved = resolvedChangeset
        if let edits = resolved.propertyEdits[track.id], let lang = edits.language {
            return lang
        }
        return track.properties.language ?? ""
    }

    func effectiveDefaultTrack(for track: MKVTrack) -> Bool {
        let resolved = resolvedChangeset
        if let edits = resolved.propertyEdits[track.id], let val = edits.flags.defaultTrack {
            return val
        }
        return track.properties.flags.defaultTrack ?? false
    }

    func effectiveForcedTrack(for track: MKVTrack) -> Bool {
        let resolved = resolvedChangeset
        if let edits = resolved.propertyEdits[track.id], let val = edits.flags.forcedTrack {
            return val
        }
        return track.properties.flags.forcedTrack ?? false
    }

    func effectiveEnabledTrack(for track: MKVTrack) -> Bool {
        let resolved = resolvedChangeset
        if let edits = resolved.propertyEdits[track.id], let val = edits.flags.enabledTrack {
            return val
        }
        return track.properties.flags.enabledTrack ?? true
    }

    func effectiveOriginalTrack(for track: MKVTrack) -> Bool {
        let resolved = resolvedChangeset
        if let edits = resolved.propertyEdits[track.id], let val = edits.flags.originalTrack {
            return val
        }
        return track.properties.flags.flagOriginal ?? false
    }

    func effectiveVisualImpairedTrack(for track: MKVTrack) -> Bool {
        let resolved = resolvedChangeset
        if let edits = resolved.propertyEdits[track.id], let val = edits.flags.visualImpairedTrack {
            return val
        }
        return track.properties.flags.flagVisualImpaired ?? false
    }

    func effectiveCommentaryTrack(for track: MKVTrack) -> Bool {
        let resolved = resolvedChangeset
        if let edits = resolved.propertyEdits[track.id], let val = edits.flags.commentaryTrack {
            return val
        }
        return track.properties.flags.flagCommentary ?? false
    }

    func effectivePixelCropTop(for track: MKVTrack) -> Int {
        let resolved = resolvedChangeset
        if let edits = resolved.propertyEdits[track.id], let val = edits.crop.pixelCropTop {
            return val
        }
        return track.properties.video.pixelCropTop ?? 0
    }

    func effectivePixelCropBottom(for track: MKVTrack) -> Int {
        let resolved = resolvedChangeset
        if let edits = resolved.propertyEdits[track.id], let val = edits.crop.pixelCropBottom {
            return val
        }
        return track.properties.video.pixelCropBottom ?? 0
    }

    func effectivePixelCropLeft(for track: MKVTrack) -> Int {
        let resolved = resolvedChangeset
        if let edits = resolved.propertyEdits[track.id], let val = edits.crop.pixelCropLeft {
            return val
        }
        return track.properties.video.pixelCropLeft ?? 0
    }

    func effectivePixelCropRight(for track: MKVTrack) -> Int {
        let resolved = resolvedChangeset
        if let edits = resolved.propertyEdits[track.id], let val = edits.crop.pixelCropRight {
            return val
        }
        return track.properties.video.pixelCropRight ?? 0
    }

    func isTrackRemoved(_ trackId: Int) -> Bool {
        resolvedChangeset.removedTrackIds.contains(trackId)
    }

    func hasPropertyEdits(for trackId: Int) -> Bool {
        resolvedChangeset.propertyEdits[trackId] != nil
    }

    func isPropertyModified(for trackId: Int, property: TrackPropertyKey) -> Bool {
        guard let edits = resolvedChangeset.propertyEdits[trackId] else { return false }
        switch property {
        case .trackName: return edits.trackName != nil
        case .language: return edits.language != nil
        case .defaultTrack: return edits.flags.defaultTrack != nil
        case .forcedTrack: return edits.flags.forcedTrack != nil
        case .enabledTrack: return edits.flags.enabledTrack != nil
        case .originalTrack: return edits.flags.originalTrack != nil
        case .visualImpairedTrack: return edits.flags.visualImpairedTrack != nil
        case .commentaryTrack: return edits.flags.commentaryTrack != nil
        case .pixelCropTop: return edits.crop.pixelCropTop != nil
        case .pixelCropBottom: return edits.crop.pixelCropBottom != nil
        case .pixelCropLeft: return edits.crop.pixelCropLeft != nil
        case .pixelCropRight: return edits.crop.pixelCropRight != nil
        }
    }

    var effectiveTracks: [MKVTrack] {
        guard let tracks = identification?.tracks else { return [] }
        let resolved = resolvedChangeset
        var result = tracks.filter { !resolved.removedTrackIds.contains($0.id) }
        if let order = resolved.trackOrder {
            result.sort { a, b in
                let aIdx = order.firstIndex(of: a.id) ?? Int.max
                let bIdx = order.firstIndex(of: b.id) ?? Int.max
                return aIdx < bIdx
            }
        }
        return result
    }
}
