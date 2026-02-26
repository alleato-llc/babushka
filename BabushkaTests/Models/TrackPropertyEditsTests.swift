import Foundation
import Testing
@testable import Babushka

@Suite("TrackPropertyEdits Tests")
struct TrackPropertyEditsTests {

    // MARK: - changes(from:) Tests

    @Test("Same value as original produces empty diff")
    func sameValueEmptyDiff() {
        let track = makeTrack(id: 0, type: .audio, defaultTrack: true, language: "eng", trackName: "English")
        var edits = TrackPropertyEdits()
        edits.flags.defaultTrack = true
        edits.language = "eng"
        edits.trackName = "English"

        let diff = edits.changes(from: track)
        #expect(diff.isEmpty)
    }

    @Test("Different flag value included in diff")
    func differentFlagIncluded() {
        let track = makeTrack(id: 0, type: .audio, defaultTrack: true)
        var edits = TrackPropertyEdits()
        edits.flags.defaultTrack = false

        let diff = edits.changes(from: track)
        #expect(diff.flags.defaultTrack == false)
    }

    @Test("Changed name included in diff")
    func changedNameIncluded() {
        let track = makeTrack(id: 0, type: .audio, trackName: "Original")
        var edits = TrackPropertyEdits()
        edits.trackName = "New Name"

        let diff = edits.changes(from: track)
        #expect(diff.trackName == "New Name")
    }

    @Test("Changed language included in diff")
    func changedLanguageIncluded() {
        let track = makeTrack(id: 0, type: .audio, language: "eng")
        var edits = TrackPropertyEdits()
        edits.language = "jpn"

        let diff = edits.changes(from: track)
        #expect(diff.language == "jpn")
    }

    @Test("Changed crop values included in diff")
    func changedCropIncluded() {
        let track = makeTrack(id: 0, type: .video)
        var edits = TrackPropertyEdits()
        edits.crop.pixelCropTop = 100
        edits.crop.pixelCropBottom = 100

        let diff = edits.changes(from: track)
        #expect(diff.crop.pixelCropTop == 100)
        #expect(diff.crop.pixelCropBottom == 100)
    }

    @Test("Multiple changed fields all included")
    func multipleChangesIncluded() {
        let track = makeTrack(id: 0, type: .audio, defaultTrack: false, language: "eng", trackName: "Old")
        var edits = TrackPropertyEdits()
        edits.flags.defaultTrack = true
        edits.language = "jpn"
        edits.trackName = "New"

        let diff = edits.changes(from: track)
        #expect(diff.flags.defaultTrack == true)
        #expect(diff.language == "jpn")
        #expect(diff.trackName == "New")
    }

    @Test("All nil fields produce empty diff")
    func allNilFieldsEmptyDiff() {
        let track = makeTrack(id: 0, type: .audio)
        let edits = TrackPropertyEdits()

        let diff = edits.changes(from: track)
        #expect(diff.isEmpty)
    }

    // MARK: - init(from:) Tests

    @Test("Snapshot captures all flags from track")
    func snapshotCapturesFlags() {
        let track = makeTrack(
            id: 0, type: .video,
            defaultTrack: true, forcedTrack: false, enabledTrack: true,
            flagOriginal: true, flagVisualImpaired: false, flagCommentary: true
        )
        let snapshot = TrackPropertyEdits(from: track)

        #expect(snapshot.flags.defaultTrack == true)
        #expect(snapshot.flags.forcedTrack == false)
        #expect(snapshot.flags.enabledTrack == true)
        #expect(snapshot.flags.originalTrack == true)
        #expect(snapshot.flags.visualImpairedTrack == false)
        #expect(snapshot.flags.commentaryTrack == true)
    }

    @Test("Snapshot captures track name and language")
    func snapshotCapturesNameAndLanguage() {
        let track = makeTrack(id: 0, type: .audio, language: "jpn", trackName: "Japanese")
        let snapshot = TrackPropertyEdits(from: track)

        #expect(snapshot.trackName == "Japanese")
        #expect(snapshot.language == "jpn")
    }

    @Test("Snapshot captures crop values")
    func snapshotCapturesCrop() {
        let track = makeTrack(
            id: 0, type: .video,
            pixelCropTop: 10, pixelCropBottom: 20, pixelCropLeft: 5, pixelCropRight: 5
        )
        let snapshot = TrackPropertyEdits(from: track)

        #expect(snapshot.crop.pixelCropTop == 10)
        #expect(snapshot.crop.pixelCropBottom == 20)
        #expect(snapshot.crop.pixelCropLeft == 5)
        #expect(snapshot.crop.pixelCropRight == 5)
    }

    @Test("Missing optional values default correctly")
    func missingOptionalDefaults() {
        let track = makeTrack(id: 0, type: .audio)
        let snapshot = TrackPropertyEdits(from: track)

        #expect(snapshot.trackName == "")
        #expect(snapshot.language == "")
        #expect(snapshot.flags.defaultTrack == nil)
        #expect(snapshot.crop.pixelCropTop == nil)
    }
}
