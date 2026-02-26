import Foundation
import Testing
@testable import Babushka

@Suite("MKVToolnixService E2E")
struct MKVToolnixServiceTests {

    @Test("Identify test5.mkv returns correct track counts")
    func identifyTest5() async throws {
        let filePath = try await TestFileManager.shared.path(for: .test5)
        let service = MKVToolnixService()
        let identification = try await service.identify(filePath: filePath)

        #expect(identification.fileName == filePath)

        let videoTracks = identification.tracks.filter { $0.type == .video }
        let audioTracks = identification.tracks.filter { $0.type == .audio }
        let subtitleTracks = identification.tracks.filter { $0.type == .subtitles }

        #expect(videoTracks.count == 1)
        #expect(audioTracks.count == 2)
        #expect(subtitleTracks.count == 8)
        #expect(identification.tracks.count == 11)
    }

    @Test("Identify test5.mkv video track details")
    func identifyVideoTrack() async throws {
        let filePath = try await TestFileManager.shared.path(for: .test5)
        let service = MKVToolnixService()
        let identification = try await service.identify(filePath: filePath)

        let video = identification.tracks.first { $0.type == .video }!
        #expect(video.codec == "AVC/H.264/MPEG-4p10")
        #expect(video.properties.video.pixelDimensions == "1024x576")
        #expect(video.properties.flags.defaultTrack == true)
    }

    @Test("Identify test5.mkv container info")
    func identifyContainer() async throws {
        let filePath = try await TestFileManager.shared.path(for: .test5)
        let service = MKVToolnixService()
        let identification = try await service.identify(filePath: filePath)

        #expect(identification.container.type == "Matroska")
        #expect(identification.container.recognized == true)
        #expect(identification.container.supported == true)
        #expect(identification.container.properties.duration != nil)
    }

    @Test("File not found throws appropriate error")
    func fileNotFound() async throws {
        let service = MKVToolnixService()
        await #expect(throws: MKVToolnixError.self) {
            try await service.identify(filePath: "/nonexistent/file.mkv")
        }
    }

    @Test("Tool availability check succeeds")
    func checkAvailability() async throws {
        let service = MKVToolnixService()
        let info = await service.checkAvailability()
        #expect(info != nil)
        #expect(info?.version.hasPrefix("v") == true)
    }
}
