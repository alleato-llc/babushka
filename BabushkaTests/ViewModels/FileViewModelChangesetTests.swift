import Foundation
import Testing
@testable import Babushka

@Suite("FileViewModel Changeset Tests")
struct FileViewModelChangesetTests {

    // MARK: - Effective Value Tests (use real test file)

    @Test("effectiveTrackName returns original when no edit")
    @MainActor
    func effectiveTrackNameOriginal() async throws {
        let vm = try await loadTestViewModel()
        let track = vm.identification!.tracks[0]
        let name = vm.effectiveTrackName(for: track)
        #expect(name == (track.properties.trackName ?? ""))
    }

    @Test("effectiveTrackName returns edited value when edit exists")
    @MainActor
    func effectiveTrackNameEdited() async throws {
        let vm = try await loadTestViewModel()
        let track = vm.identification!.tracks[0]

        var edits = TrackPropertyEdits()
        edits.trackName = "Custom Name"
        vm.editTrackProperties(trackId: track.id, trackUid: track.properties.uid, edits: edits)

        #expect(vm.effectiveTrackName(for: track) == "Custom Name")
    }

    @Test("effectiveLanguage returns edited value when edit exists")
    @MainActor
    func effectiveLanguageEdited() async throws {
        let vm = try await loadTestViewModel()
        let track = vm.identification!.tracks[0]

        var edits = TrackPropertyEdits()
        edits.language = "jpn"
        vm.editTrackProperties(trackId: track.id, trackUid: track.properties.uid, edits: edits)

        #expect(vm.effectiveLanguage(for: track) == "jpn")
    }

    @Test("effectiveDefaultTrack returns edited flag")
    @MainActor
    func effectiveDefaultTrackEdited() async throws {
        let vm = try await loadTestViewModel()
        let track = vm.identification!.tracks[0]
        let original = track.properties.flags.defaultTrack ?? false

        var edits = TrackPropertyEdits()
        edits.flags.defaultTrack = !original
        vm.editTrackProperties(trackId: track.id, trackUid: track.properties.uid, edits: edits)

        #expect(vm.effectiveDefaultTrack(for: track) == !original)
    }

    @Test("effectivePixelCropTop returns edited crop value")
    @MainActor
    func effectivePixelCropTopEdited() async throws {
        let vm = try await loadTestViewModel()
        let videoTrack = vm.identification!.tracks.first { $0.type == .video }!

        var edits = TrackPropertyEdits()
        edits.crop.pixelCropTop = 42
        vm.editTrackProperties(trackId: videoTrack.id, trackUid: videoTrack.properties.uid, edits: edits)

        #expect(vm.effectivePixelCropTop(for: videoTrack) == 42)
    }

    @Test("Multiple effective methods return correct mix of edited and original")
    @MainActor
    func multipleEffectiveValues() async throws {
        let vm = try await loadTestViewModel()
        let track = vm.identification!.tracks[0]

        var edits = TrackPropertyEdits()
        edits.trackName = "Edited"
        vm.editTrackProperties(trackId: track.id, trackUid: track.properties.uid, edits: edits)

        // Name should be edited
        #expect(vm.effectiveTrackName(for: track) == "Edited")
        // Language should be original
        #expect(vm.effectiveLanguage(for: track) == (track.properties.language ?? ""))
    }

    // MARK: - Changeset Wiring Tests

    @Test("editTrackProperties makes hasPendingChanges true")
    @MainActor
    func editMakesHasPendingChangesTrue() async throws {
        let vm = try await loadTestViewModel()
        #expect(!vm.hasPendingChanges)

        let track = vm.identification!.tracks[0]
        var edits = TrackPropertyEdits()
        edits.trackName = "Changed"
        vm.editTrackProperties(trackId: track.id, trackUid: track.properties.uid, edits: edits)

        #expect(vm.hasPendingChanges)
    }

    @Test("cancelAllChanges makes hasPendingChanges false")
    @MainActor
    func cancelAllMakesNoPendingChanges() async throws {
        let vm = try await loadTestViewModel()
        let track = vm.identification!.tracks[0]
        var edits = TrackPropertyEdits()
        edits.trackName = "Changed"
        vm.editTrackProperties(trackId: track.id, trackUid: track.properties.uid, edits: edits)
        #expect(vm.hasPendingChanges)

        vm.cancelAllChanges()
        #expect(!vm.hasPendingChanges)
    }

    @Test("undoLastChange and redoLastChange toggle correctly")
    @MainActor
    func undoRedoToggle() async throws {
        let vm = try await loadTestViewModel()
        let track = vm.identification!.tracks[0]
        var edits = TrackPropertyEdits()
        edits.trackName = "Changed"
        vm.editTrackProperties(trackId: track.id, trackUid: track.properties.uid, edits: edits)

        #expect(vm.canUndo)
        #expect(!vm.canRedo)

        vm.undoLastChange()
        #expect(!vm.canUndo)
        #expect(vm.canRedo)
        #expect(!vm.hasPendingChanges)

        vm.redoLastChange()
        #expect(vm.canUndo)
        #expect(!vm.canRedo)
        #expect(vm.hasPendingChanges)
    }

    @Test("isPropertyModified returns true for edited properties, false for others")
    @MainActor
    func isPropertyModified() async throws {
        let vm = try await loadTestViewModel()
        let track = vm.identification!.tracks[0]

        var edits = TrackPropertyEdits()
        edits.trackName = "New Name"
        vm.editTrackProperties(trackId: track.id, trackUid: track.properties.uid, edits: edits)

        #expect(vm.isPropertyModified(for: track.id, property: .trackName))
        #expect(!vm.isPropertyModified(for: track.id, property: .language))
        #expect(!vm.isPropertyModified(for: track.id, property: .defaultTrack))
    }

    @Test("isTrackRemoved returns true after markTrackForRemoval")
    @MainActor
    func isTrackRemovedAfterMark() async throws {
        let vm = try await loadTestViewModel()
        let track = vm.identification!.tracks.last!
        #expect(!vm.isTrackRemoved(track.id))

        vm.markTrackForRemoval(trackId: track.id)
        #expect(vm.isTrackRemoved(track.id))
    }

    @Test("effectiveTracks filters out removed tracks")
    @MainActor
    func effectiveTracksFiltersRemoved() async throws {
        let vm = try await loadTestViewModel()
        let originalCount = vm.identification!.tracks.count
        let lastTrack = vm.identification!.tracks.last!

        vm.markTrackForRemoval(trackId: lastTrack.id)

        #expect(vm.effectiveTracks.count == originalCount - 1)
        #expect(!vm.effectiveTracks.contains { $0.id == lastTrack.id })
    }

    @Test("effectiveTracks respects reorder")
    @MainActor
    func effectiveTracksRespectsReorder() async throws {
        let vm = try await loadTestViewModel()
        let tracks = vm.identification!.tracks
        guard tracks.count >= 3 else {
            Issue.record("Need at least 3 tracks for reorder test")
            return
        }

        let reversed = tracks.map(\.id).reversed().map { $0 }
        vm.reorderTracks(order: reversed)

        let effective = vm.effectiveTracks
        #expect(effective.first?.id == tracks.last?.id)
        #expect(effective.last?.id == tracks.first?.id)
    }

    // MARK: - Helpers

    @MainActor
    private func loadTestViewModel() async throws -> FileViewModel {
        let filePath = try await TestFileManager.shared.path(for: .test5)
        let service = MKVToolnixService()
        let vm = FileViewModel(filePath: filePath, service: service)
        await vm.load()
        #expect(vm.identification != nil)
        return vm
    }
}
