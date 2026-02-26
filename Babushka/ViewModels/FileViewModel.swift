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

    private(set) var chapterEditions: [MKVChapterEdition]?
    private(set) var isLoadingChapters = false
    private(set) var chapterLoadError: String?

    private let service: MKVToolnixService
    private let chapterXMLService = ChapterXMLService()

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
            updateSidebarTree(from: identification, preserveIds: false)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func reload() async {
        do {
            let identification = try await service.identify(filePath: filePath)
            state = .loaded(identification)
            updateSidebarTree(from: identification, preserveIds: true)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func updateSidebarTree(from identification: MKVIdentification, preserveIds: Bool) {
        let result = SidebarTreeBuilder.build(
            fileId: id, fileName: fileName,
            identification: identification,
            existingChildren: preserveIds ? sidebarChildren : nil
        )
        sidebarItems = result.items
        sidebarChildren = result.children
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

    // MARK: - Chapters

    var hasChapters: Bool {
        guard let identification else { return false }
        return identification.chapters.contains { ($0.numEntries ?? 0) > 0 }
    }

    var effectiveChapters: [MKVChapterEdition]? {
        let resolved = resolvedChangeset
        if resolved.removeChapters {
            return []
        }
        if let edits = resolved.chapterEdits {
            return edits
        }
        return chapterEditions
    }

    func loadChapters() async {
        guard chapterEditions == nil, !isLoadingChapters else { return }
        isLoadingChapters = true
        chapterLoadError = nil

        do {
            if let xml = try await service.extractChapters(filePath: filePath) {
                chapterEditions = try chapterXMLService.parse(xmlString: xml)
            } else {
                chapterEditions = []
            }
        } catch {
            chapterLoadError = error.localizedDescription
        }

        isLoadingChapters = false
    }

    func editChapters(editions: [MKVChapterEdition]) {
        changeset.editChapters(editions: editions)
    }

    func removeAllChapters() {
        changeset.removeChapters()
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
