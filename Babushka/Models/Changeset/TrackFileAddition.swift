import Foundation

struct TrackFileAddition: Sendable {
    let filePath: String
    let language: String?
    let trackName: String?
    let defaultTrack: Bool?
}
