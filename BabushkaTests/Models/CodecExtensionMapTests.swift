import Foundation
import Testing
@testable import Babushka

@Suite("CodecExtensionMap Tests")
struct CodecExtensionMapTests {

    @Test("Known video codec returns correct extension")
    func videoCodecExtension() {
        #expect(CodecExtensionMap.fileExtension(for: "V_MPEG4/ISO/AVC") == ".h264")
        #expect(CodecExtensionMap.fileExtension(for: "V_MPEGH/ISO/HEVC") == ".h265")
        #expect(CodecExtensionMap.fileExtension(for: "V_VP9") == ".ivf")
    }

    @Test("Known audio codec returns correct extension")
    func audioCodecExtension() {
        #expect(CodecExtensionMap.fileExtension(for: "A_AAC") == ".aac")
        #expect(CodecExtensionMap.fileExtension(for: "A_FLAC") == ".flac")
        #expect(CodecExtensionMap.fileExtension(for: "A_OPUS") == ".opus")
    }

    @Test("Known subtitle codec returns correct extension")
    func subtitleCodecExtension() {
        #expect(CodecExtensionMap.fileExtension(for: "S_TEXT/UTF8") == ".srt")
        #expect(CodecExtensionMap.fileExtension(for: "S_TEXT/ASS") == ".ass")
        #expect(CodecExtensionMap.fileExtension(for: "S_HDMV/PGS") == ".sup")
    }

    @Test("Unknown codec falls back to .bin")
    func unknownCodecFallback() {
        #expect(CodecExtensionMap.fileExtension(for: "X_UNKNOWN") == ".bin")
        #expect(CodecExtensionMap.fileExtension(for: "") == ".bin")
    }

    @Test("suggestedFileName generates correct format")
    func suggestedFileNameFormat() {
        let track = makeTrack(id: 2, type: .audio, codecId: "A_AAC")
        let name = CodecExtensionMap.suggestedFileName(for: track, sourceFileName: "movie.mkv")
        #expect(name == "movie_track2.aac")
    }

    @Test("suggestedFileName strips .mkv extension from source")
    func suggestedFileNameStripsExtension() {
        let track = makeTrack(id: 0, type: .video, codecId: "V_MPEG4/ISO/AVC")
        let name = CodecExtensionMap.suggestedFileName(for: track, sourceFileName: "test_video.mkv")
        #expect(name == "test_video_track0.h264")
    }
}
