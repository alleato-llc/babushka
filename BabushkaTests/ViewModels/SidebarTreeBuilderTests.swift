import Foundation
import Testing
@testable import Babushka

@Suite("SidebarTreeBuilder Tests")
struct SidebarTreeBuilderTests {

    @Test("Fresh build generates correct structure")
    func freshBuild() {
        let identification = makeIdentification(
            videoCount: 1, audioCount: 2, subtitleCount: 3, attachmentCount: 1
        )
        let fileId = UUID()

        let result = SidebarTreeBuilder.build(
            fileId: fileId, fileName: "test.mkv",
            identification: identification, existingChildren: nil
        )

        // Should have one file item
        #expect(result.items.count == 1)
        if case .file(let id, let name) = result.items[0] {
            #expect(id == fileId)
            #expect(name == "test.mkv")
        }

        // File should have 4 children: 3 track groups + 1 attachment group
        let fileChildren = result.children[fileId]!
        #expect(fileChildren.count == 4)

        // Check track group counts
        var trackGroupCounts: [TrackType: Int] = [:]
        for child in fileChildren {
            if case .trackGroup(_, let trackType, let count) = child {
                trackGroupCounts[trackType] = count
            }
        }
        #expect(trackGroupCounts[.video] == 1)
        #expect(trackGroupCounts[.audio] == 2)
        #expect(trackGroupCounts[.subtitles] == 3)
    }

    @Test("Rebuild preserves existing UUIDs for same track IDs")
    func rebuildPreservesUUIDs() {
        let identification = makeIdentification(videoCount: 1, audioCount: 1, subtitleCount: 0, attachmentCount: 0)
        let fileId = UUID()

        // Initial build
        let initial = SidebarTreeBuilder.build(
            fileId: fileId, fileName: "test.mkv",
            identification: identification, existingChildren: nil
        )

        // Rebuild with same identification
        let rebuilt = SidebarTreeBuilder.build(
            fileId: fileId, fileName: "test.mkv",
            identification: identification, existingChildren: initial.children
        )

        // Track UUIDs should be preserved
        let initialTracks = collectTracks(from: initial)
        let rebuiltTracks = collectTracks(from: rebuilt)

        for (trackId, uuid) in initialTracks {
            #expect(rebuiltTracks[trackId] == uuid, "UUID for track \(trackId) should be preserved")
        }
    }

    @Test("Rebuild generates new UUIDs for newly added tracks")
    func rebuildNewTracksGetNewUUIDs() {
        let smallIdent = makeIdentification(videoCount: 1, audioCount: 0, subtitleCount: 0, attachmentCount: 0)
        let largerIdent = makeIdentification(videoCount: 1, audioCount: 1, subtitleCount: 0, attachmentCount: 0)
        let fileId = UUID()

        // Initial build with 1 video
        let initial = SidebarTreeBuilder.build(
            fileId: fileId, fileName: "test.mkv",
            identification: smallIdent, existingChildren: nil
        )

        // Rebuild with 1 video + 1 audio
        let rebuilt = SidebarTreeBuilder.build(
            fileId: fileId, fileName: "test.mkv",
            identification: largerIdent, existingChildren: initial.children
        )

        let rebuiltTracks = collectTracks(from: rebuilt)
        // Should have 2 tracks now
        #expect(rebuiltTracks.count == 2)
    }

    @Test("Empty tracks and attachments handled correctly")
    func emptyIdentification() {
        let identification = makeIdentification(videoCount: 0, audioCount: 0, subtitleCount: 0, attachmentCount: 0)
        let fileId = UUID()

        let result = SidebarTreeBuilder.build(
            fileId: fileId, fileName: "empty.mkv",
            identification: identification, existingChildren: nil
        )

        #expect(result.items.count == 1)
        let fileChildren = result.children[fileId]!
        #expect(fileChildren.isEmpty)
    }

    @Test("Attachments grouped correctly")
    func attachmentsGrouped() {
        let identification = makeIdentification(videoCount: 0, audioCount: 0, subtitleCount: 0, attachmentCount: 3)
        let fileId = UUID()

        let result = SidebarTreeBuilder.build(
            fileId: fileId, fileName: "test.mkv",
            identification: identification, existingChildren: nil
        )

        let fileChildren = result.children[fileId]!
        #expect(fileChildren.count == 1) // Just the attachment group

        if case .attachmentGroup(let groupId, let count) = fileChildren[0] {
            #expect(count == 3)
            let attachmentItems = result.children[groupId]!
            #expect(attachmentItems.count == 3)
        } else {
            Issue.record("Expected attachment group")
        }
    }

    // MARK: - Chapter Group Tests

    @Test("Chapter group appears when chapters exist")
    func chapterGroupAppears() {
        let identification = makeIdentification(
            videoCount: 1, audioCount: 0, subtitleCount: 0, attachmentCount: 0,
            chapterEditionCounts: [5]
        )
        let fileId = UUID()

        let result = SidebarTreeBuilder.build(
            fileId: fileId, fileName: "test.mkv",
            identification: identification, existingChildren: nil
        )

        let fileChildren = result.children[fileId]!
        let chapterGroups = fileChildren.filter {
            if case .chapterGroup = $0 { return true }
            return false
        }
        #expect(chapterGroups.count == 1)
        if case .chapterGroup(_, let count) = chapterGroups[0] {
            #expect(count == 5)
        }
    }

    @Test("Chapter group absent when no chapters")
    func chapterGroupAbsent() {
        let identification = makeIdentification(
            videoCount: 1, audioCount: 0, subtitleCount: 0, attachmentCount: 0
        )
        let fileId = UUID()

        let result = SidebarTreeBuilder.build(
            fileId: fileId, fileName: "test.mkv",
            identification: identification, existingChildren: nil
        )

        let fileChildren = result.children[fileId]!
        let chapterGroups = fileChildren.filter {
            if case .chapterGroup = $0 { return true }
            return false
        }
        #expect(chapterGroups.isEmpty)
    }

    @Test("Chapter group UUID preserved on rebuild")
    func chapterGroupUUIDPreserved() {
        let identification = makeIdentification(
            videoCount: 0, audioCount: 0, subtitleCount: 0, attachmentCount: 0,
            chapterEditionCounts: [3]
        )
        let fileId = UUID()

        let initial = SidebarTreeBuilder.build(
            fileId: fileId, fileName: "test.mkv",
            identification: identification, existingChildren: nil
        )

        let rebuilt = SidebarTreeBuilder.build(
            fileId: fileId, fileName: "test.mkv",
            identification: identification, existingChildren: initial.children
        )

        let initialChapterUUID = initial.children[fileId]!.compactMap { item -> UUID? in
            if case .chapterGroup(let id, _) = item { return id }
            return nil
        }.first

        let rebuiltChapterUUID = rebuilt.children[fileId]!.compactMap { item -> UUID? in
            if case .chapterGroup(let id, _) = item { return id }
            return nil
        }.first

        #expect(initialChapterUUID != nil)
        #expect(initialChapterUUID == rebuiltChapterUUID)
    }

    // MARK: - Helpers

    private func collectTracks(from result: SidebarTreeBuilder.Result) -> [Int: UUID] {
        var trackMap: [Int: UUID] = [:]
        for (_, children) in result.children {
            for child in children {
                if case .track(let uuid, let track) = child {
                    trackMap[track.id] = uuid
                }
            }
        }
        return trackMap
    }
}
