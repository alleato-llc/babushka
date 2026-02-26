import Foundation
import Testing
@testable import Babushka

@Suite("Command Builder Tests")
struct CommandBuilderTests {

    // MARK: - MkvmergeCommandBuilder

    @Test("Empty changeset produces minimal arguments")
    func mkvmergeEmptyChangeset() {
        let builder = MkvmergeCommandBuilder()
        let changeset = ResolvedChangeset(
            propertyEdits: [:],
            removedTrackIds: [],
            addedTracks: [],
            trackOrder: nil,
            hasStructuralChanges: false
        )
        let args = builder.buildArguments(
            filePath: "/input.mkv", outputPath: "/output.mkv",
            changeset: changeset, allTracks: []
        )
        #expect(args == ["-o", "/output.mkv", "/input.mkv"])
    }

    @Test("Track removal generates correct flags for all video removed")
    func mkvmergeRemoveAllVideo() {
        let builder = MkvmergeCommandBuilder()
        let tracks = [makeTrack(id: 0, type: .video)]
        let changeset = ResolvedChangeset(
            propertyEdits: [:],
            removedTrackIds: [0],
            addedTracks: [],
            trackOrder: nil,
            hasStructuralChanges: true
        )
        let args = builder.buildArguments(
            filePath: "/input.mkv", outputPath: "/output.mkv",
            changeset: changeset, allTracks: tracks
        )
        #expect(args.contains("-D"))
        #expect(!args.contains("-A"))
        #expect(!args.contains("-S"))
    }

    @Test("Partial track removal generates keep list")
    func mkvmergePartialRemoval() {
        let builder = MkvmergeCommandBuilder()
        let tracks = [
            makeTrack(id: 1, type: .audio),
            makeTrack(id: 2, type: .audio),
        ]
        let changeset = ResolvedChangeset(
            propertyEdits: [:],
            removedTrackIds: [1],
            addedTracks: [],
            trackOrder: nil,
            hasStructuralChanges: true
        )
        let args = builder.buildArguments(
            filePath: "/input.mkv", outputPath: "/output.mkv",
            changeset: changeset, allTracks: tracks
        )
        #expect(args.contains("-a"))
        #expect(args.contains("2"))
    }

    @Test("Property edits generate mkvmerge flags")
    func mkvmergePropertyEdits() {
        let builder = MkvmergeCommandBuilder()
        var edits = TrackPropertyEdits()
        edits.flags.defaultTrack = true
        edits.trackName = "English"
        let changeset = ResolvedChangeset(
            propertyEdits: [0: edits],
            removedTrackIds: [],
            addedTracks: [],
            trackOrder: nil,
            hasStructuralChanges: true
        )
        let args = builder.buildArguments(
            filePath: "/input.mkv", outputPath: "/output.mkv",
            changeset: changeset, allTracks: []
        )
        #expect(args.contains("--track-name"))
        #expect(args.contains("0:English"))
        #expect(args.contains("--default-track-flag"))
        #expect(args.contains("0:1"))
    }

    @Test("Track order generates --track-order argument")
    func mkvmergeTrackOrder() {
        let builder = MkvmergeCommandBuilder()
        let changeset = ResolvedChangeset(
            propertyEdits: [:],
            removedTrackIds: [],
            addedTracks: [],
            trackOrder: [2, 0, 1],
            hasStructuralChanges: true
        )
        let args = builder.buildArguments(
            filePath: "/input.mkv", outputPath: "/output.mkv",
            changeset: changeset, allTracks: []
        )
        #expect(args.contains("--track-order"))
        #expect(args.contains("0:2,0:0,0:1"))
    }

    @Test("Crop edits generate --cropping argument")
    func mkvmergeCropEdits() {
        let builder = MkvmergeCommandBuilder()
        var edits = TrackPropertyEdits()
        edits.crop.pixelCropTop = 10
        edits.crop.pixelCropBottom = 20
        let changeset = ResolvedChangeset(
            propertyEdits: [0: edits],
            removedTrackIds: [],
            addedTracks: [],
            trackOrder: nil,
            hasStructuralChanges: true
        )
        let args = builder.buildArguments(
            filePath: "/input.mkv", outputPath: "/output.mkv",
            changeset: changeset, allTracks: []
        )
        #expect(args.contains("--cropping"))
        #expect(args.contains("0:10,20,0,0"))
    }

    // MARK: - MkvpropeditCommandBuilder

    @Test("Mkvpropedit uses UID selector when available")
    func mkvpropeditUIDSelector() {
        let builder = MkvpropeditCommandBuilder()
        var edits = TrackPropertyEdits()
        edits.flags.defaultTrack = false
        let track = makeTrack(id: 0, type: .video, uid: 12345, number: 1)
        let changeset = ResolvedChangeset(
            propertyEdits: [0: edits],
            removedTrackIds: [],
            addedTracks: [],
            trackOrder: nil,
            hasStructuralChanges: false
        )
        let args = builder.buildArguments(
            filePath: "/input.mkv", changeset: changeset, allTracks: [track]
        )
        #expect(args.contains("--edit"))
        #expect(args.contains("track:=12345"))
    }

    @Test("Mkvpropedit falls back to track number selector")
    func mkvpropeditNumberFallback() {
        let builder = MkvpropeditCommandBuilder()
        var edits = TrackPropertyEdits()
        edits.flags.forcedTrack = true
        let track = makeTrack(id: 0, type: .video, uid: nil, number: 1)
        let changeset = ResolvedChangeset(
            propertyEdits: [0: edits],
            removedTrackIds: [],
            addedTracks: [],
            trackOrder: nil,
            hasStructuralChanges: false
        )
        let args = builder.buildArguments(
            filePath: "/input.mkv", changeset: changeset, allTracks: [track]
        )
        #expect(args.contains("track:1"))
    }

    @Test("Mkvpropedit empty name generates --delete name")
    func mkvpropeditDeleteName() {
        let builder = MkvpropeditCommandBuilder()
        var edits = TrackPropertyEdits()
        edits.trackName = ""
        let track = makeTrack(id: 0, type: .video, uid: 100, number: 1)
        let changeset = ResolvedChangeset(
            propertyEdits: [0: edits],
            removedTrackIds: [],
            addedTracks: [],
            trackOrder: nil,
            hasStructuralChanges: false
        )
        let args = builder.buildArguments(
            filePath: "/input.mkv", changeset: changeset, allTracks: [track]
        )
        #expect(args.contains("--delete"))
        #expect(args.contains("name"))
    }

    @Test("Added track files generate correct arguments")
    func mkvmergeAddedTrackFiles() {
        let builder = MkvmergeCommandBuilder()
        let addition = TrackFileAddition(filePath: "/extra.srt", language: "eng", trackName: "English Subs", defaultTrack: true)
        let changeset = ResolvedChangeset(
            propertyEdits: [:],
            removedTrackIds: [],
            addedTracks: [(id: UUID(), addition: addition)],
            trackOrder: nil,
            hasStructuralChanges: true
        )
        let args = builder.buildArguments(
            filePath: "/input.mkv", outputPath: "/output.mkv",
            changeset: changeset, allTracks: []
        )
        #expect(args.contains("/extra.srt"))
        #expect(args.contains("--language"))
        #expect(args.contains("0:eng"))
        #expect(args.contains("--track-name"))
        #expect(args.contains("0:English Subs"))
        #expect(args.contains("--default-track-flag"))
        #expect(args.contains("0:1"))
    }

    @Test("Multiple tracks removed from same type generate correct keep list")
    func mkvmergeMultipleRemovalsSameType() {
        let builder = MkvmergeCommandBuilder()
        let tracks = [
            makeTrack(id: 3, type: .subtitles),
            makeTrack(id: 4, type: .subtitles),
            makeTrack(id: 5, type: .subtitles),
        ]
        let changeset = ResolvedChangeset(
            propertyEdits: [:],
            removedTrackIds: [3, 5],
            addedTracks: [],
            trackOrder: nil,
            hasStructuralChanges: true
        )
        let args = builder.buildArguments(
            filePath: "/input.mkv", outputPath: "/output.mkv",
            changeset: changeset, allTracks: tracks
        )
        #expect(args.contains("-s"))
        #expect(args.contains("4"))
    }

    @Test("Language edit generates --language flag")
    func mkvmergeLanguageEdit() {
        let builder = MkvmergeCommandBuilder()
        var edits = TrackPropertyEdits()
        edits.language = "jpn"
        let changeset = ResolvedChangeset(
            propertyEdits: [1: edits],
            removedTrackIds: [],
            addedTracks: [],
            trackOrder: nil,
            hasStructuralChanges: true
        )
        let args = builder.buildArguments(
            filePath: "/input.mkv", outputPath: "/output.mkv",
            changeset: changeset, allTracks: []
        )
        #expect(args.contains("--language"))
        #expect(args.contains("1:jpn"))
    }

    @Test("Mkvpropedit crop edits generate correct --set commands")
    func mkvpropeditCropEdits() {
        let builder = MkvpropeditCommandBuilder()
        var edits = TrackPropertyEdits()
        edits.crop.pixelCropTop = 138
        edits.crop.pixelCropBottom = 138
        let track = makeTrack(id: 0, type: .video, uid: 100, number: 1)
        let changeset = ResolvedChangeset(
            propertyEdits: [0: edits],
            removedTrackIds: [],
            addedTracks: [],
            trackOrder: nil,
            hasStructuralChanges: false
        )
        let args = builder.buildArguments(
            filePath: "/input.mkv", changeset: changeset, allTracks: [track]
        )
        #expect(args.contains("--set"))
        #expect(args.contains("pixel-crop-top=138"))
        #expect(args.contains("pixel-crop-bottom=138"))
    }
}
