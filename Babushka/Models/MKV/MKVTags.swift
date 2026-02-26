import Foundation

struct GlobalTag: Codable, Sendable {
    let numEntries: Int?

    enum CodingKeys: String, CodingKey {
        case numEntries = "num_entries"
    }
}

struct TrackTag: Codable, Sendable {
    let numEntries: Int?
    let trackId: Int?

    enum CodingKeys: String, CodingKey {
        case numEntries = "num_entries"
        case trackId = "track_id"
    }
}
