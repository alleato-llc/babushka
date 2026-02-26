import Foundation
import Testing
@testable import Babushka

@Suite("PendingChangeset Tests")
struct PendingChangesetTests {

    // MARK: - Mutation Tests

    @Test("editProperties appends operation and clears undo stack")
    func editPropertiesAppendsAndClearsUndo() {
        var cs = PendingChangeset()
        cs.removeTrack(trackId: 0)
        cs.undo()
        #expect(cs.canRedo)

        var edits = TrackPropertyEdits()
        edits.flags.defaultTrack = true
        cs.editProperties(trackId: 1, trackUid: nil, edits: edits)

        #expect(cs.operationCount == 1)
        #expect(!cs.canRedo)
    }

    @Test("removeTrack appends operation")
    func removeTrackAppends() {
        var cs = PendingChangeset()
        cs.removeTrack(trackId: 5)
        #expect(cs.operationCount == 1)
        #expect(!cs.isEmpty)
    }

    @Test("addTrack appends operation with unique UUID")
    func addTrackAppendsWithUniqueUUID() {
        var cs = PendingChangeset()
        let addition = TrackFileAddition(filePath: "/a.srt", language: nil, trackName: nil, defaultTrack: nil)
        cs.addTrack(addition)
        cs.addTrack(addition)
        #expect(cs.operationCount == 2)

        // Each addTrack should have a unique UUID
        if case .addTrack(let id1, _) = cs.operations[0],
           case .addTrack(let id2, _) = cs.operations[1] {
            #expect(id1 != id2)
        } else {
            Issue.record("Expected addTrack operations")
        }
    }

    @Test("reorder replaces any existing reorder operation")
    func reorderReplacesExisting() {
        var cs = PendingChangeset()
        cs.reorder(trackOrder: [0, 1, 2])
        cs.reorder(trackOrder: [2, 1, 0])
        #expect(cs.operationCount == 1)
        if case .reorder(let order) = cs.operations[0] {
            #expect(order == [2, 1, 0])
        } else {
            Issue.record("Expected reorder operation")
        }
    }

    @Test("cancelAll clears both operations and undo stack")
    func cancelAllClearsBoth() {
        var cs = PendingChangeset()
        var edits = TrackPropertyEdits()
        edits.flags.defaultTrack = true
        cs.editProperties(trackId: 0, trackUid: nil, edits: edits)
        cs.removeTrack(trackId: 1)
        cs.undo()
        #expect(cs.canRedo)
        #expect(!cs.isEmpty)

        cs.cancelAll()
        #expect(cs.isEmpty)
        #expect(!cs.canUndo)
        #expect(!cs.canRedo)
    }

    @Test("Empty edits are rejected")
    func emptyEditsRejected() {
        var cs = PendingChangeset()
        let edits = TrackPropertyEdits()
        cs.editProperties(trackId: 0, trackUid: nil, edits: edits)
        #expect(cs.isEmpty)
    }

    // MARK: - Undo/Redo Tests

    @Test("undo moves last operation to undo stack")
    func undoMovesLastToUndoStack() {
        var cs = PendingChangeset()
        cs.removeTrack(trackId: 0)
        cs.removeTrack(trackId: 1)
        #expect(cs.operationCount == 2)

        cs.undo()
        #expect(cs.operationCount == 1)
        #expect(cs.canRedo)
    }

    @Test("redo moves last undo item back to operations")
    func redoMovesBackToOperations() {
        var cs = PendingChangeset()
        cs.removeTrack(trackId: 0)
        cs.undo()
        #expect(cs.isEmpty)

        cs.redo()
        #expect(cs.operationCount == 1)
        #expect(!cs.canRedo)
    }

    @Test("undo on empty changeset is a no-op")
    func undoOnEmptyIsNoop() {
        var cs = PendingChangeset()
        cs.undo()
        #expect(cs.isEmpty)
        #expect(!cs.canRedo)
    }

    @Test("redo on empty undo stack is a no-op")
    func redoOnEmptyUndoIsNoop() {
        var cs = PendingChangeset()
        cs.redo()
        #expect(cs.isEmpty)
    }

    @Test("New edit after undo clears undo stack")
    func newEditAfterUndoClearsUndoStack() {
        var cs = PendingChangeset()
        cs.removeTrack(trackId: 0)
        cs.removeTrack(trackId: 1)
        cs.undo()
        #expect(cs.canRedo)

        cs.removeTrack(trackId: 2)
        #expect(!cs.canRedo)
        #expect(cs.operationCount == 2)
    }

    // MARK: - Resolve Tests

    @Test("Empty changeset resolves to empty result")
    func emptyResolves() {
        let cs = PendingChangeset()
        let resolved = cs.resolve(originalTracks: [])
        #expect(resolved.propertyEdits.isEmpty)
        #expect(resolved.removedTrackIds.isEmpty)
        #expect(resolved.addedTracks.isEmpty)
        #expect(resolved.trackOrder == nil)
        #expect(!resolved.hasStructuralChanges)
    }

    @Test("Single property edit resolves correctly")
    func singlePropertyEditResolves() {
        var cs = PendingChangeset()
        var edits = TrackPropertyEdits()
        edits.trackName = "English"
        cs.editProperties(trackId: 0, trackUid: nil, edits: edits)

        let track = makeTrack(id: 0, type: .audio, trackName: "Original")
        let resolved = cs.resolve(originalTracks: [track])

        #expect(resolved.propertyEdits[0]?.trackName == "English")
        #expect(!resolved.hasStructuralChanges)
    }

    @Test("Multiple edits to same track merge with last write wins")
    func multipleEditsMerge() {
        var cs = PendingChangeset()

        var edits1 = TrackPropertyEdits()
        edits1.trackName = "First"
        edits1.flags.defaultTrack = true
        cs.editProperties(trackId: 0, trackUid: nil, edits: edits1)

        var edits2 = TrackPropertyEdits()
        edits2.trackName = "Second"
        cs.editProperties(trackId: 0, trackUid: nil, edits: edits2)

        let track = makeTrack(id: 0, type: .audio, trackName: "Original")
        let resolved = cs.resolve(originalTracks: [track])

        #expect(resolved.propertyEdits[0]?.trackName == "Second")
        #expect(resolved.propertyEdits[0]?.flags.defaultTrack == true)
    }

    @Test("Remove track discards property edits for that track")
    func removeTrackDiscardsEdits() {
        var cs = PendingChangeset()

        var edits = TrackPropertyEdits()
        edits.trackName = "English"
        cs.editProperties(trackId: 0, trackUid: nil, edits: edits)
        cs.removeTrack(trackId: 0)

        let track = makeTrack(id: 0, type: .audio)
        let resolved = cs.resolve(originalTracks: [track])

        #expect(resolved.propertyEdits[0] == nil)
        #expect(resolved.removedTrackIds.contains(0))
    }

    @Test("Remove track filters from reorder list")
    func removeTrackFiltersFromReorder() {
        var cs = PendingChangeset()
        cs.reorder(trackOrder: [0, 1, 2])
        cs.removeTrack(trackId: 1)

        let tracks = [
            makeTrack(id: 0, type: .video),
            makeTrack(id: 1, type: .audio),
            makeTrack(id: 2, type: .subtitles),
        ]
        let resolved = cs.resolve(originalTracks: tracks)

        #expect(resolved.trackOrder == [0, 2])
    }

    @Test("Resolve diffs against originals — no-op edits discarded")
    func resolveDiscardsNoopEdits() {
        var cs = PendingChangeset()
        var edits = TrackPropertyEdits()
        edits.flags.defaultTrack = true
        cs.editProperties(trackId: 0, trackUid: nil, edits: edits)

        // Track already has defaultTrack = true
        let track = makeTrack(id: 0, type: .audio, defaultTrack: true)
        let resolved = cs.resolve(originalTracks: [track])

        #expect(resolved.propertyEdits.isEmpty)
    }

    @Test("hasStructuralChanges is true when removals present")
    func hasStructuralChangesWithRemovals() {
        var cs = PendingChangeset()
        cs.removeTrack(trackId: 0)
        let resolved = cs.resolve(originalTracks: [makeTrack(id: 0, type: .video)])
        #expect(resolved.hasStructuralChanges)
    }

    @Test("hasStructuralChanges is true when additions present")
    func hasStructuralChangesWithAdditions() {
        var cs = PendingChangeset()
        cs.addTrack(TrackFileAddition(filePath: "/a.srt", language: nil, trackName: nil, defaultTrack: nil))
        let resolved = cs.resolve(originalTracks: [])
        #expect(resolved.hasStructuralChanges)
    }

    @Test("hasStructuralChanges is true when reorder present")
    func hasStructuralChangesWithReorder() {
        var cs = PendingChangeset()
        cs.reorder(trackOrder: [1, 0])
        let resolved = cs.resolve(originalTracks: [])
        #expect(resolved.hasStructuralChanges)
    }

    @Test("hasStructuralChanges is false for property-only edits")
    func hasStructuralChangesFalseForPropertyOnly() {
        var cs = PendingChangeset()
        var edits = TrackPropertyEdits()
        edits.trackName = "English"
        cs.editProperties(trackId: 0, trackUid: nil, edits: edits)

        let track = makeTrack(id: 0, type: .audio, trackName: "Original")
        let resolved = cs.resolve(originalTracks: [track])
        #expect(!resolved.hasStructuralChanges)
    }

    @Test("Added tracks appear in resolved result")
    func addedTracksAppear() {
        var cs = PendingChangeset()
        let addition = TrackFileAddition(filePath: "/sub.srt", language: "eng", trackName: "English", defaultTrack: true)
        cs.addTrack(addition)

        let resolved = cs.resolve(originalTracks: [])
        #expect(resolved.addedTracks.count == 1)
        #expect(resolved.addedTracks[0].addition.filePath == "/sub.srt")
        #expect(resolved.addedTracks[0].addition.language == "eng")
    }

    // MARK: - Chapter Tests

    @Test("Chapter edit replaces previous chapter edit")
    func chapterEditReplacesPrevious() {
        var cs = PendingChangeset()
        let edition1 = [MKVChapterEdition(chapters: [MKVChapterAtom(timeStart: 0)])]
        let edition2 = [MKVChapterEdition(chapters: [MKVChapterAtom(timeStart: 1000)])]
        cs.editChapters(editions: edition1)
        cs.editChapters(editions: edition2)
        #expect(cs.operationCount == 1)

        let resolved = cs.resolve(originalTracks: [])
        #expect(resolved.chapterEdits?.count == 1)
        #expect(resolved.chapterEdits?[0].chapters[0].timeStart == 1000)
    }

    @Test("Remove chapters replaces previous chapter edit")
    func removeChaptersReplacesPreviousEdit() {
        var cs = PendingChangeset()
        let editions = [MKVChapterEdition(chapters: [MKVChapterAtom(timeStart: 0)])]
        cs.editChapters(editions: editions)
        cs.removeChapters()
        #expect(cs.operationCount == 1)

        let resolved = cs.resolve(originalTracks: [])
        #expect(resolved.chapterEdits == nil)
        #expect(resolved.removeChapters == true)
    }

    @Test("Chapter edit replaces previous remove chapters")
    func chapterEditReplacesRemove() {
        var cs = PendingChangeset()
        cs.removeChapters()
        let editions = [MKVChapterEdition(chapters: [MKVChapterAtom(timeStart: 0)])]
        cs.editChapters(editions: editions)
        #expect(cs.operationCount == 1)

        let resolved = cs.resolve(originalTracks: [])
        #expect(resolved.chapterEdits != nil)
        #expect(resolved.removeChapters == false)
    }

    @Test("Resolve includes chapter edits")
    func resolveIncludesChapterEdits() {
        var cs = PendingChangeset()
        let editions = [MKVChapterEdition(chapters: [
            MKVChapterAtom(timeStart: 0, displays: [ChapterDisplay(string: "Intro")]),
            MKVChapterAtom(timeStart: 60_000_000_000, displays: [ChapterDisplay(string: "Main")]),
        ])]
        cs.editChapters(editions: editions)

        let resolved = cs.resolve(originalTracks: [])
        #expect(resolved.chapterEdits?.count == 1)
        #expect(resolved.chapterEdits?[0].chapters.count == 2)
    }

    @Test("Chapters don't affect hasStructuralChanges")
    func chaptersDontAffectHasStructuralChanges() {
        var cs = PendingChangeset()
        let editions = [MKVChapterEdition(chapters: [MKVChapterAtom(timeStart: 0)])]
        cs.editChapters(editions: editions)

        let resolved = cs.resolve(originalTracks: [])
        #expect(!resolved.hasStructuralChanges)
    }

    @Test("Remove chapters doesn't affect hasStructuralChanges")
    func removeChaptersDontAffectHasStructuralChanges() {
        var cs = PendingChangeset()
        cs.removeChapters()

        let resolved = cs.resolve(originalTracks: [])
        #expect(!resolved.hasStructuralChanges)
    }
}
