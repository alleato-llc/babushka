import Foundation
import Testing
@testable import Babushka

@Suite("MKV Changeset Integration Tests")
struct MKVChangesetIntegrationTests {

    private func copyTestFile() async throws -> (source: String, output: String) {
        let sourcePath = try await TestFileManager.shared.path(for: .test5)
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let copyPath = tempDir.appendingPathComponent("test5.mkv").path
        try FileManager.default.copyItem(atPath: sourcePath, toPath: copyPath)
        let outputPath = tempDir.appendingPathComponent("test5_output.mkv").path
        return (copyPath, outputPath)
    }

    @Test("Property edit E2E — change default track flag via mkvpropedit")
    func propertyEditE2E() async throws {
        let (source, _) = try await copyTestFile()
        let service = MKVToolnixService()

        let original = try await service.identify(filePath: source)
        let track = original.tracks.first { $0.type == .audio }!
        let originalDefault = track.properties.flags.defaultTrack ?? false

        var edits = TrackPropertyEdits()
        edits.flags.defaultTrack = !originalDefault
        let changeset = ResolvedChangeset(
            propertyEdits: [track.id: edits],
            removedTrackIds: [],
            addedTracks: [],
            trackOrder: nil,
            hasStructuralChanges: false
        )

        try await service.applyChangeset(
            filePath: source, changeset: changeset,
            allTracks: original.tracks, outputPath: source
        )

        let updated = try await service.identify(filePath: source)
        let updatedTrack = updated.tracks.first { $0.id == track.id }!
        #expect(updatedTrack.properties.flags.defaultTrack == !originalDefault)
    }

    @Test("Track removal E2E — remove subtitle track via mkvmerge")
    func trackRemovalE2E() async throws {
        let (source, output) = try await copyTestFile()
        let service = MKVToolnixService()

        let original = try await service.identify(filePath: source)
        let subtitleTracks = original.tracks.filter { $0.type == .subtitles }
        let trackToRemove = subtitleTracks.last!

        let changeset = ResolvedChangeset(
            propertyEdits: [:],
            removedTrackIds: [trackToRemove.id],
            addedTracks: [],
            trackOrder: nil,
            hasStructuralChanges: true
        )

        try await service.applyChangeset(
            filePath: source, changeset: changeset,
            allTracks: original.tracks, outputPath: output
        )

        let updated = try await service.identify(filePath: output)
        #expect(updated.tracks.count == original.tracks.count - 1)
        #expect(!updated.tracks.contains { $0.id == trackToRemove.id })
    }

    @Test("Track name edit E2E — set track name via mkvpropedit")
    func trackNameEditE2E() async throws {
        let (source, _) = try await copyTestFile()
        let service = MKVToolnixService()

        let original = try await service.identify(filePath: source)
        let track = original.tracks[0]

        var edits = TrackPropertyEdits()
        edits.trackName = "Babushka Test Name"
        let changeset = ResolvedChangeset(
            propertyEdits: [track.id: edits],
            removedTrackIds: [],
            addedTracks: [],
            trackOrder: nil,
            hasStructuralChanges: false
        )

        try await service.applyChangeset(
            filePath: source, changeset: changeset,
            allTracks: original.tracks, outputPath: source
        )

        let updated = try await service.identify(filePath: source)
        let updatedTrack = updated.tracks.first { $0.id == track.id }!
        #expect(updatedTrack.properties.trackName == "Babushka Test Name")
    }

    @Test("Open and view properties E2E — load test5.mkv via FileViewModel")
    @MainActor
    func openAndViewPropertiesE2E() async throws {
        let filePath = try await TestFileManager.shared.path(for: .test5)
        let service = MKVToolnixService()
        let vm = FileViewModel(filePath: filePath, service: service)
        await vm.load()

        let tracks = vm.identification!.tracks
        #expect(tracks.count == 11)

        let videoTracks = tracks.filter { $0.type == .video }
        let audioTracks = tracks.filter { $0.type == .audio }
        let subtitleTracks = tracks.filter { $0.type == .subtitles }

        #expect(videoTracks.count == 1)
        #expect(audioTracks.count == 2)
        #expect(subtitleTracks.count == 8)

        // Video properties
        let video = videoTracks[0]
        #expect(video.properties.codecId == "V_MPEG4/ISO/AVC")

        // Audio properties
        let audio = audioTracks[0]
        #expect(audio.properties.codecId == "A_AAC")
        #expect(audio.properties.audio.audioChannels == 2)
        #expect(audio.properties.audio.audioSamplingFrequency == 48000)
    }

    @Test("Remove track and verify — full FileViewModel changeset to apply")
    @MainActor
    func removeTrackAndVerifyE2E() async throws {
        let (source, output) = try await copyTestFile()
        let service = MKVToolnixService()
        let vm = FileViewModel(filePath: source, service: service)
        await vm.load()

        let subtitleTrack = vm.identification!.tracks.filter { $0.type == .subtitles }.last!
        vm.markTrackForRemoval(trackId: subtitleTrack.id)

        let resolved = vm.resolvedChangeset
        #expect(resolved.hasStructuralChanges)

        try await service.applyChangeset(
            filePath: source, changeset: resolved,
            allTracks: vm.identification!.tracks, outputPath: output
        )

        let updated = try await service.identify(filePath: output)
        let updatedSubtitles = updated.tracks.filter { $0.type == .subtitles }
        #expect(updatedSubtitles.count == 7)
    }
}
