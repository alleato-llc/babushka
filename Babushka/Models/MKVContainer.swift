import Foundation

struct MKVContainer: Codable, Sendable {
    let properties: ContainerProperties
    let recognized: Bool
    let supported: Bool
    let type: String
}

struct ContainerProperties: Codable, Sendable {
    let containerType: Int?
    let dateLocal: String?
    let dateUtc: String?
    let duration: Int?
    let isProvidingTimestamps: Bool?
    let muxingApplication: String?
    let segmentUid: String?
    let timestampScale: Int?
    let writingApplication: String?
    let title: String?

    enum CodingKeys: String, CodingKey {
        case containerType = "container_type"
        case dateLocal = "date_local"
        case dateUtc = "date_utc"
        case duration
        case isProvidingTimestamps = "is_providing_timestamps"
        case muxingApplication = "muxing_application"
        case segmentUid = "segment_uid"
        case timestampScale = "timestamp_scale"
        case writingApplication = "writing_application"
        case title
    }

    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let totalSeconds = duration / 1_000_000_000
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}
