import Foundation

enum ChangesetOperation: Sendable, Identifiable {
    case editProperties(trackId: Int, trackUid: UInt64?, edits: TrackPropertyEdits)
    case removeTrack(trackId: Int)
    case addTrack(id: UUID, addition: TrackFileAddition)
    case reorder(trackOrder: [Int])
    case editChapters(editions: [MKVChapterEdition])
    case removeChapters

    var id: String {
        switch self {
        case .editProperties(let trackId, _, _): "edit-\(trackId)-\(UUID())"
        case .removeTrack(let trackId): "remove-\(trackId)-\(UUID())"
        case .addTrack(let id, _): "add-\(id)"
        case .reorder: "reorder-\(UUID())"
        case .editChapters: "editChapters-\(UUID())"
        case .removeChapters: "removeChapters-\(UUID())"
        }
    }
}

struct ResolvedChangeset: Sendable {
    let propertyEdits: [Int: TrackPropertyEdits]
    let removedTrackIds: Set<Int>
    let addedTracks: [(id: UUID, addition: TrackFileAddition)]
    let trackOrder: [Int]?
    let hasStructuralChanges: Bool
    let chapterEdits: [MKVChapterEdition]?
    let removeChapters: Bool

    init(
        propertyEdits: [Int: TrackPropertyEdits],
        removedTrackIds: Set<Int>,
        addedTracks: [(id: UUID, addition: TrackFileAddition)],
        trackOrder: [Int]?,
        hasStructuralChanges: Bool,
        chapterEdits: [MKVChapterEdition]? = nil,
        removeChapters: Bool = false
    ) {
        self.propertyEdits = propertyEdits
        self.removedTrackIds = removedTrackIds
        self.addedTracks = addedTracks
        self.trackOrder = trackOrder
        self.hasStructuralChanges = hasStructuralChanges
        self.chapterEdits = chapterEdits
        self.removeChapters = removeChapters
    }
}

struct PendingChangeset: Sendable {
    private(set) var operations: [ChangesetOperation] = []
    private(set) var undoStack: [ChangesetOperation] = []

    var isEmpty: Bool { operations.isEmpty }

    var operationCount: Int { operations.count }

    var canUndo: Bool { !operations.isEmpty }

    var canRedo: Bool { !undoStack.isEmpty }

    mutating func editProperties(trackId: Int, trackUid: UInt64?, edits: TrackPropertyEdits) {
        guard !edits.isEmpty else { return }
        operations.append(.editProperties(trackId: trackId, trackUid: trackUid, edits: edits))
        undoStack.removeAll()
    }

    mutating func removeTrack(trackId: Int) {
        operations.append(.removeTrack(trackId: trackId))
        undoStack.removeAll()
    }

    mutating func addTrack(_ addition: TrackFileAddition) {
        operations.append(.addTrack(id: UUID(), addition: addition))
        undoStack.removeAll()
    }

    mutating func reorder(trackOrder: [Int]) {
        // Replace any existing reorder operation
        operations.removeAll { op in
            if case .reorder = op { return true }
            return false
        }
        operations.append(.reorder(trackOrder: trackOrder))
        undoStack.removeAll()
    }

    mutating func editChapters(editions: [MKVChapterEdition]) {
        operations.removeAll { op in
            if case .editChapters = op { return true }
            if case .removeChapters = op { return true }
            return false
        }
        operations.append(.editChapters(editions: editions))
        undoStack.removeAll()
    }

    mutating func removeChapters() {
        operations.removeAll { op in
            if case .editChapters = op { return true }
            if case .removeChapters = op { return true }
            return false
        }
        operations.append(.removeChapters)
        undoStack.removeAll()
    }

    mutating func undo() {
        guard let last = operations.popLast() else { return }
        undoStack.append(last)
    }

    mutating func redo() {
        guard let last = undoStack.popLast() else { return }
        operations.append(last)
    }

    mutating func cancelAll() {
        operations.removeAll()
        undoStack.removeAll()
    }

    func resolve(originalTracks: [MKVTrack]) -> ResolvedChangeset {
        var mergedEdits: [Int: TrackPropertyEdits] = [:]
        var removedIds: Set<Int> = []
        var addedTracks: [(id: UUID, addition: TrackFileAddition)] = []
        var latestOrder: [Int]?
        var chapterEdits: [MKVChapterEdition]?
        var shouldRemoveChapters = false

        for op in operations {
            switch op {
            case .editProperties(let trackId, _, let edits):
                var existing = mergedEdits[trackId] ?? TrackPropertyEdits()
                if let val = edits.trackName { existing.trackName = val }
                if let val = edits.language { existing.language = val }
                if let val = edits.flags.defaultTrack { existing.flags.defaultTrack = val }
                if let val = edits.flags.forcedTrack { existing.flags.forcedTrack = val }
                if let val = edits.flags.enabledTrack { existing.flags.enabledTrack = val }
                if let val = edits.flags.originalTrack { existing.flags.originalTrack = val }
                if let val = edits.flags.visualImpairedTrack { existing.flags.visualImpairedTrack = val }
                if let val = edits.flags.commentaryTrack { existing.flags.commentaryTrack = val }
                if let val = edits.crop.pixelCropTop { existing.crop.pixelCropTop = val }
                if let val = edits.crop.pixelCropBottom { existing.crop.pixelCropBottom = val }
                if let val = edits.crop.pixelCropLeft { existing.crop.pixelCropLeft = val }
                if let val = edits.crop.pixelCropRight { existing.crop.pixelCropRight = val }
                mergedEdits[trackId] = existing

            case .removeTrack(let trackId):
                removedIds.insert(trackId)

            case .addTrack(let id, let addition):
                addedTracks.append((id: id, addition: addition))

            case .reorder(let order):
                latestOrder = order

            case .editChapters(let editions):
                chapterEdits = editions
                shouldRemoveChapters = false

            case .removeChapters:
                chapterEdits = nil
                shouldRemoveChapters = true
            }
        }

        // Discard property edits for removed tracks
        for id in removedIds {
            mergedEdits.removeValue(forKey: id)
        }

        // Filter removed tracks from reorder
        if let order = latestOrder {
            latestOrder = order.filter { !removedIds.contains($0) }
        }

        // Determine actual changes by diffing against original tracks
        var effectiveEdits: [Int: TrackPropertyEdits] = [:]
        for (trackId, edits) in mergedEdits {
            if let track = originalTracks.first(where: { $0.id == trackId }) {
                let diff = edits.changes(from: track)
                if !diff.isEmpty {
                    effectiveEdits[trackId] = diff
                }
            } else {
                // Track not found in originals; keep edits as-is
                if !edits.isEmpty {
                    effectiveEdits[trackId] = edits
                }
            }
        }

        let hasStructural = !removedIds.isEmpty || !addedTracks.isEmpty || latestOrder != nil

        return ResolvedChangeset(
            propertyEdits: effectiveEdits,
            removedTrackIds: removedIds,
            addedTracks: addedTracks,
            trackOrder: latestOrder,
            hasStructuralChanges: hasStructural,
            chapterEdits: chapterEdits,
            removeChapters: shouldRemoveChapters
        )
    }
}
