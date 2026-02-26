import Foundation

struct MKVIdentification: Codable, Sendable {
    let attachments: [MKVAttachment]
    let chapters: [MKVChapter]
    let container: MKVContainer
    let errors: [String]
    let fileName: String
    let globalTags: [GlobalTag]
    let identificationFormatVersion: Int
    let trackTags: [TrackTag]
    let tracks: [MKVTrack]
    let warnings: [String]

    enum CodingKeys: String, CodingKey {
        case attachments, chapters, container, errors
        case fileName = "file_name"
        case globalTags = "global_tags"
        case identificationFormatVersion = "identification_format_version"
        case trackTags = "track_tags"
        case tracks, warnings
    }
}

struct MKVChapter: Codable, Sendable {
    let numEntries: Int?

    enum CodingKeys: String, CodingKey {
        case numEntries = "num_entries"
    }
}
