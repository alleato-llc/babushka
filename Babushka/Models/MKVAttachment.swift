import Foundation

struct MKVAttachment: Codable, Sendable, Identifiable {
    let contentType: String?
    let description: String?
    let fileName: String?
    let id: Int
    let properties: AttachmentProperties?
    let size: Int?

    enum CodingKeys: String, CodingKey {
        case contentType = "content_type"
        case description
        case fileName = "file_name"
        case id
        case properties
        case size
    }

    var displayName: String {
        fileName ?? "Attachment \(id)"
    }
}

struct AttachmentProperties: Codable, Sendable {
    let uid: UInt64?
}
