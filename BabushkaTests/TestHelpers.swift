import Foundation
@testable import Babushka

func makeTrack(
    id: Int, type: TrackType, uid: UInt64? = nil, number: Int? = nil,
    defaultTrack: Bool? = nil, forcedTrack: Bool? = nil, enabledTrack: Bool? = nil,
    language: String? = nil, trackName: String? = nil,
    flagOriginal: Bool? = nil, flagVisualImpaired: Bool? = nil, flagCommentary: Bool? = nil,
    pixelCropTop: Int? = nil, pixelCropBottom: Int? = nil,
    pixelCropLeft: Int? = nil, pixelCropRight: Int? = nil,
    codecId: String? = nil, pixelDimensions: String? = nil
) -> MKVTrack {
    var props: [String] = []
    if let uid { props.append("\"uid\": \(uid)") }
    if let number { props.append("\"number\": \(number)") }
    if let defaultTrack { props.append("\"default_track\": \(defaultTrack)") }
    if let forcedTrack { props.append("\"forced_track\": \(forcedTrack)") }
    if let enabledTrack { props.append("\"enabled_track\": \(enabledTrack)") }
    if let language { props.append("\"language\": \"\(language)\"") }
    if let trackName { props.append("\"track_name\": \"\(trackName)\"") }
    if let flagOriginal { props.append("\"flag_original\": \(flagOriginal)") }
    if let flagVisualImpaired { props.append("\"flag_visual_impaired\": \(flagVisualImpaired)") }
    if let flagCommentary { props.append("\"flag_commentary\": \(flagCommentary)") }
    if let pixelCropTop { props.append("\"pixel_crop_top\": \(pixelCropTop)") }
    if let pixelCropBottom { props.append("\"pixel_crop_bottom\": \(pixelCropBottom)") }
    if let pixelCropLeft { props.append("\"pixel_crop_left\": \(pixelCropLeft)") }
    if let pixelCropRight { props.append("\"pixel_crop_right\": \(pixelCropRight)") }
    if let pixelDimensions { props.append("\"pixel_dimensions\": \"\(pixelDimensions)\"") }
    props.append("\"codec_id\": \"\(codecId ?? "test")\"")

    let json = """
    {
        "codec": "test-codec",
        "id": \(id),
        "type": "\(type.rawValue)",
        "properties": {
            \(props.joined(separator: ",\n            "))
        }
    }
    """
    return try! JSONDecoder().decode(MKVTrack.self, from: Data(json.utf8))
}

func makeIdentification(
    videoCount: Int, audioCount: Int, subtitleCount: Int, attachmentCount: Int,
    chapterEditionCounts: [Int] = []
) -> MKVIdentification {
    var tracks: [[String: Any]] = []
    var trackId = 0

    for _ in 0..<videoCount {
        tracks.append(["codec": "AVC", "id": trackId, "type": "video", "properties": ["codec_id": "V_MPEG4/ISO/AVC"]])
        trackId += 1
    }
    for _ in 0..<audioCount {
        tracks.append(["codec": "AAC", "id": trackId, "type": "audio", "properties": ["codec_id": "A_AAC"]])
        trackId += 1
    }
    for _ in 0..<subtitleCount {
        tracks.append(["codec": "SRT", "id": trackId, "type": "subtitles", "properties": ["codec_id": "S_TEXT/UTF8"]])
        trackId += 1
    }

    var attachments: [[String: Any]] = []
    for i in 0..<attachmentCount {
        attachments.append(["id": i + 1, "size": 100, "content_type": "image/png", "file_name": "attach_\(i).png"])
    }

    var chapters: [[String: Any]] = []
    for count in chapterEditionCounts {
        chapters.append(["num_entries": count])
    }

    let json: [String: Any] = [
        "attachments": attachments,
        "chapters": chapters,
        "container": [
            "properties": ["container_type": 17, "duration": 1000000000],
            "recognized": true,
            "supported": true,
            "type": "Matroska",
        ] as [String: Any],
        "errors": [] as [String],
        "file_name": "test.mkv",
        "global_tags": [] as [[String: Any]],
        "identification_format_version": 19,
        "track_tags": [] as [[String: Any]],
        "tracks": tracks,
        "warnings": [] as [String],
    ]

    let data = try! JSONSerialization.data(withJSONObject: json)
    return try! JSONDecoder().decode(MKVIdentification.self, from: data)
}
