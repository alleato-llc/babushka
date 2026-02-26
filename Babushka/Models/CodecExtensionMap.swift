import Foundation

enum CodecExtensionMap {
    private static let map: [String: String] = [
        // Video
        "V_MPEG4/ISO/AVC": ".h264",
        "V_MPEGH/ISO/HEVC": ".h265",
        "V_VP8": ".ivf",
        "V_VP9": ".ivf",
        "V_AV1": ".ivf",
        // Audio
        "A_AAC": ".aac",
        "A_MP3": ".mp3",
        "A_FLAC": ".flac",
        "A_OPUS": ".opus",
        "A_AC3": ".ac3",
        "A_DTS": ".dts",
        "A_EAC3": ".eac3",
        "A_VORBIS": ".ogg",
        // Subtitles
        "S_TEXT/UTF8": ".srt",
        "S_TEXT/ASS": ".ass",
        "S_TEXT/SSA": ".ssa",
        "S_VOBSUB": ".sub",
        "S_HDMV/PGS": ".sup",
        "S_TEXT/WEBVTT": ".vtt",
    ]

    static func fileExtension(for codecId: String) -> String {
        map[codecId] ?? ".bin"
    }

    static func suggestedFileName(for track: MKVTrack, sourceFileName: String) -> String {
        let baseName = (sourceFileName as NSString).deletingPathExtension
        let codecId = track.properties.codecId ?? track.codec
        let ext = fileExtension(for: codecId)
        return "\(baseName)_track\(track.id)\(ext)"
    }
}
