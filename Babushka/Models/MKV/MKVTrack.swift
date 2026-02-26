import Foundation

enum TrackType: String, Codable, Sendable, CaseIterable {
    case video
    case audio
    case subtitles
    case unknown

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = TrackType(rawValue: rawValue) ?? .unknown
    }

    var displayName: String {
        switch self {
        case .video: "Video"
        case .audio: "Audio"
        case .subtitles: "Subtitles"
        case .unknown: "Unknown"
        }
    }

    var systemImage: String {
        switch self {
        case .video: "film"
        case .audio: "speaker.wave.2"
        case .subtitles: "captions.bubble"
        case .unknown: "questionmark.circle"
        }
    }

    var sortOrder: Int {
        switch self {
        case .video: 0
        case .audio: 1
        case .subtitles: 2
        case .unknown: 3
        }
    }
}

struct MKVTrack: Codable, Sendable, Identifiable {
    let codec: String
    let id: Int
    let properties: TrackProperties
    let type: TrackType

    var displayName: String {
        let name = properties.trackName ?? codec
        if let lang = properties.language, lang != "und" {
            return "\(name) (\(lang))"
        }
        return name
    }
}

struct TrackProperties: Codable, Sendable {

    struct Flags: Sendable {
        let defaultTrack: Bool?
        let enabledTrack: Bool?
        let forcedTrack: Bool?
        let flagOriginal: Bool?
        let flagVisualImpaired: Bool?
        let flagCommentary: Bool?
    }

    struct VideoInfo: Sendable {
        let displayDimensions: String?
        let displayUnit: Int?
        let pixelDimensions: String?
        let pixelCropTop: Int?
        let pixelCropBottom: Int?
        let pixelCropLeft: Int?
        let pixelCropRight: Int?
        let stereoMode: Int?
        let packetizer: String?

        var pixelWidth: Int? {
            guard let dims = pixelDimensions else { return nil }
            let parts = dims.split(separator: "x")
            guard parts.count == 2, let w = Int(parts[0]) else { return nil }
            return w
        }

        var pixelHeight: Int? {
            guard let dims = pixelDimensions else { return nil }
            let parts = dims.split(separator: "x")
            guard parts.count == 2, let h = Int(parts[1]) else { return nil }
            return h
        }
    }

    struct AudioInfo: Sendable {
        let audioChannels: Int?
        let audioSamplingFrequency: Int?
        let audioBitsPerSample: Int?

        var channelDescription: String? {
            guard let channels = audioChannels else { return nil }
            switch channels {
            case 1: return "Mono"
            case 2: return "Stereo"
            case 6: return "5.1"
            case 8: return "7.1"
            default: return "\(channels) channels"
            }
        }

        var formattedSamplingFrequency: String? {
            guard let freq = audioSamplingFrequency else { return nil }
            if freq >= 1000 {
                return String(format: "%.1f kHz", Double(freq) / 1000.0)
            }
            return "\(freq) Hz"
        }
    }

    // Common properties
    let codecId: String?
    let codecPrivateData: String?
    let codecPrivateLength: Int?
    let defaultDuration: Int?
    let language: String?
    let minimumTimestamp: Int?
    let numIndexEntries: Int?
    let number: Int?
    let uid: UInt64?
    let trackName: String?
    let encoding: String?

    // Nested groups
    let flags: Flags
    let video: VideoInfo
    let audio: AudioInfo

    // Subtitle-specific
    let textSubtitles: Bool?

    // Dynamic tag_* properties
    let tags: [String: String]

    enum StaticCodingKeys: String, CodingKey {
        case codecId = "codec_id"
        case codecPrivateData = "codec_private_data"
        case codecPrivateLength = "codec_private_length"
        case defaultDuration = "default_duration"
        case defaultTrack = "default_track"
        case enabledTrack = "enabled_track"
        case forcedTrack = "forced_track"
        case flagOriginal = "flag_original"
        case flagVisualImpaired = "flag_visual_impaired"
        case flagCommentary = "flag_commentary"
        case language
        case minimumTimestamp = "minimum_timestamp"
        case numIndexEntries = "num_index_entries"
        case number
        case uid
        case trackName = "track_name"
        case packetizer
        case encoding
        case displayDimensions = "display_dimensions"
        case displayUnit = "display_unit"
        case pixelDimensions = "pixel_dimensions"
        case pixelCropTop = "pixel_crop_top"
        case pixelCropBottom = "pixel_crop_bottom"
        case pixelCropLeft = "pixel_crop_left"
        case pixelCropRight = "pixel_crop_right"
        case stereoMode = "stereo_mode"
        case audioChannels = "audio_channels"
        case audioSamplingFrequency = "audio_sampling_frequency"
        case audioBitsPerSample = "audio_bits_per_sample"
        case textSubtitles = "text_subtitles"
    }

    struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        var intValue: Int?

        init?(stringValue: String) {
            self.stringValue = stringValue
            self.intValue = nil
        }

        init?(intValue: Int) {
            self.stringValue = String(intValue)
            self.intValue = intValue
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: StaticCodingKeys.self)

        codecId = try c.decodeIfPresent(String.self, forKey: .codecId)
        codecPrivateData = try c.decodeIfPresent(String.self, forKey: .codecPrivateData)
        codecPrivateLength = try c.decodeIfPresent(Int.self, forKey: .codecPrivateLength)
        defaultDuration = try c.decodeIfPresent(Int.self, forKey: .defaultDuration)
        language = try c.decodeIfPresent(String.self, forKey: .language)
        minimumTimestamp = try c.decodeIfPresent(Int.self, forKey: .minimumTimestamp)
        numIndexEntries = try c.decodeIfPresent(Int.self, forKey: .numIndexEntries)
        number = try c.decodeIfPresent(Int.self, forKey: .number)
        uid = try c.decodeIfPresent(UInt64.self, forKey: .uid)
        trackName = try c.decodeIfPresent(String.self, forKey: .trackName)
        encoding = try c.decodeIfPresent(String.self, forKey: .encoding)
        textSubtitles = try c.decodeIfPresent(Bool.self, forKey: .textSubtitles)

        flags = Flags(
            defaultTrack: try c.decodeIfPresent(Bool.self, forKey: .defaultTrack),
            enabledTrack: try c.decodeIfPresent(Bool.self, forKey: .enabledTrack),
            forcedTrack: try c.decodeIfPresent(Bool.self, forKey: .forcedTrack),
            flagOriginal: try c.decodeIfPresent(Bool.self, forKey: .flagOriginal),
            flagVisualImpaired: try c.decodeIfPresent(Bool.self, forKey: .flagVisualImpaired),
            flagCommentary: try c.decodeIfPresent(Bool.self, forKey: .flagCommentary)
        )

        video = VideoInfo(
            displayDimensions: try c.decodeIfPresent(String.self, forKey: .displayDimensions),
            displayUnit: try c.decodeIfPresent(Int.self, forKey: .displayUnit),
            pixelDimensions: try c.decodeIfPresent(String.self, forKey: .pixelDimensions),
            pixelCropTop: try c.decodeIfPresent(Int.self, forKey: .pixelCropTop),
            pixelCropBottom: try c.decodeIfPresent(Int.self, forKey: .pixelCropBottom),
            pixelCropLeft: try c.decodeIfPresent(Int.self, forKey: .pixelCropLeft),
            pixelCropRight: try c.decodeIfPresent(Int.self, forKey: .pixelCropRight),
            stereoMode: try c.decodeIfPresent(Int.self, forKey: .stereoMode),
            packetizer: try c.decodeIfPresent(String.self, forKey: .packetizer)
        )

        audio = AudioInfo(
            audioChannels: try c.decodeIfPresent(Int.self, forKey: .audioChannels),
            audioSamplingFrequency: try c.decodeIfPresent(Int.self, forKey: .audioSamplingFrequency),
            audioBitsPerSample: try c.decodeIfPresent(Int.self, forKey: .audioBitsPerSample)
        )

        // Capture all tag_* keys
        let dynamicContainer = try decoder.container(keyedBy: DynamicCodingKeys.self)
        let staticKeys = Set(StaticCodingKeys.allCases.map(\.stringValue))
        var capturedTags: [String: String] = [:]
        for key in dynamicContainer.allKeys {
            if key.stringValue.hasPrefix("tag_"), !staticKeys.contains(key.stringValue) {
                if let value = try? dynamicContainer.decode(String.self, forKey: key) {
                    capturedTags[key.stringValue] = value
                }
            }
        }
        tags = capturedTags
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: StaticCodingKeys.self)

        try c.encodeIfPresent(codecId, forKey: .codecId)
        try c.encodeIfPresent(codecPrivateData, forKey: .codecPrivateData)
        try c.encodeIfPresent(codecPrivateLength, forKey: .codecPrivateLength)
        try c.encodeIfPresent(defaultDuration, forKey: .defaultDuration)
        try c.encodeIfPresent(language, forKey: .language)
        try c.encodeIfPresent(minimumTimestamp, forKey: .minimumTimestamp)
        try c.encodeIfPresent(numIndexEntries, forKey: .numIndexEntries)
        try c.encodeIfPresent(number, forKey: .number)
        try c.encodeIfPresent(uid, forKey: .uid)
        try c.encodeIfPresent(trackName, forKey: .trackName)
        try c.encodeIfPresent(encoding, forKey: .encoding)
        try c.encodeIfPresent(textSubtitles, forKey: .textSubtitles)

        // Flags
        try c.encodeIfPresent(flags.defaultTrack, forKey: .defaultTrack)
        try c.encodeIfPresent(flags.enabledTrack, forKey: .enabledTrack)
        try c.encodeIfPresent(flags.forcedTrack, forKey: .forcedTrack)
        try c.encodeIfPresent(flags.flagOriginal, forKey: .flagOriginal)
        try c.encodeIfPresent(flags.flagVisualImpaired, forKey: .flagVisualImpaired)
        try c.encodeIfPresent(flags.flagCommentary, forKey: .flagCommentary)

        // Video
        try c.encodeIfPresent(video.displayDimensions, forKey: .displayDimensions)
        try c.encodeIfPresent(video.displayUnit, forKey: .displayUnit)
        try c.encodeIfPresent(video.pixelDimensions, forKey: .pixelDimensions)
        try c.encodeIfPresent(video.pixelCropTop, forKey: .pixelCropTop)
        try c.encodeIfPresent(video.pixelCropBottom, forKey: .pixelCropBottom)
        try c.encodeIfPresent(video.pixelCropLeft, forKey: .pixelCropLeft)
        try c.encodeIfPresent(video.pixelCropRight, forKey: .pixelCropRight)
        try c.encodeIfPresent(video.stereoMode, forKey: .stereoMode)
        try c.encodeIfPresent(video.packetizer, forKey: .packetizer)

        // Audio
        try c.encodeIfPresent(audio.audioChannels, forKey: .audioChannels)
        try c.encodeIfPresent(audio.audioSamplingFrequency, forKey: .audioSamplingFrequency)
        try c.encodeIfPresent(audio.audioBitsPerSample, forKey: .audioBitsPerSample)

        // Encode tag_* as dynamic keys
        var dynamicContainer = encoder.container(keyedBy: DynamicCodingKeys.self)
        for (key, value) in tags {
            if let codingKey = DynamicCodingKeys(stringValue: key) {
                try dynamicContainer.encode(value, forKey: codingKey)
            }
        }
    }

    var formattedDefaultDuration: String? {
        guard let ns = defaultDuration, ns > 0 else { return nil }
        let fps = 1_000_000_000.0 / Double(ns)
        return String(format: "%.3f fps", fps)
    }
}

extension TrackProperties.StaticCodingKeys: CaseIterable {
    static var allCases: [TrackProperties.StaticCodingKeys] {
        [
            .codecId, .codecPrivateData, .codecPrivateLength, .defaultDuration,
            .defaultTrack, .enabledTrack, .forcedTrack,
            .flagOriginal, .flagVisualImpaired, .flagCommentary,
            .language,
            .minimumTimestamp, .numIndexEntries, .number, .uid,
            .trackName, .packetizer, .encoding,
            .displayDimensions, .displayUnit, .pixelDimensions,
            .pixelCropTop, .pixelCropBottom, .pixelCropLeft, .pixelCropRight,
            .stereoMode,
            .audioChannels, .audioSamplingFrequency, .audioBitsPerSample,
            .textSubtitles,
        ]
    }

    var stringValue: String {
        switch self {
        case .codecId: return "codec_id"
        case .codecPrivateData: return "codec_private_data"
        case .codecPrivateLength: return "codec_private_length"
        case .defaultDuration: return "default_duration"
        case .defaultTrack: return "default_track"
        case .enabledTrack: return "enabled_track"
        case .forcedTrack: return "forced_track"
        case .flagOriginal: return "flag_original"
        case .flagVisualImpaired: return "flag_visual_impaired"
        case .flagCommentary: return "flag_commentary"
        case .language: return "language"
        case .minimumTimestamp: return "minimum_timestamp"
        case .numIndexEntries: return "num_index_entries"
        case .number: return "number"
        case .uid: return "uid"
        case .trackName: return "track_name"
        case .packetizer: return "packetizer"
        case .encoding: return "encoding"
        case .displayDimensions: return "display_dimensions"
        case .displayUnit: return "display_unit"
        case .pixelDimensions: return "pixel_dimensions"
        case .pixelCropTop: return "pixel_crop_top"
        case .pixelCropBottom: return "pixel_crop_bottom"
        case .pixelCropLeft: return "pixel_crop_left"
        case .pixelCropRight: return "pixel_crop_right"
        case .stereoMode: return "stereo_mode"
        case .audioChannels: return "audio_channels"
        case .audioSamplingFrequency: return "audio_sampling_frequency"
        case .audioBitsPerSample: return "audio_bits_per_sample"
        case .textSubtitles: return "text_subtitles"
        }
    }
}
