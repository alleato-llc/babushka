import Foundation

struct TrackPropertyEdits: Sendable {

    struct FlagEdits: Sendable {
        var defaultTrack: Bool?
        var forcedTrack: Bool?
        var enabledTrack: Bool?
        var originalTrack: Bool?
        var visualImpairedTrack: Bool?
        var commentaryTrack: Bool?

        var isEmpty: Bool {
            defaultTrack == nil && forcedTrack == nil && enabledTrack == nil
                && originalTrack == nil && visualImpairedTrack == nil && commentaryTrack == nil
        }
    }

    struct CropEdits: Sendable {
        var pixelCropTop: Int?
        var pixelCropBottom: Int?
        var pixelCropLeft: Int?
        var pixelCropRight: Int?

        var isEmpty: Bool {
            pixelCropTop == nil && pixelCropBottom == nil
                && pixelCropLeft == nil && pixelCropRight == nil
        }
    }

    var flags = FlagEdits()
    var crop = CropEdits()
    var trackName: String?
    var language: String?

    var isEmpty: Bool {
        trackName == nil && language == nil && flags.isEmpty && crop.isEmpty
    }

    init() {}

    init(from track: MKVTrack) {
        flags.defaultTrack = track.properties.flags.defaultTrack
        flags.forcedTrack = track.properties.flags.forcedTrack
        flags.enabledTrack = track.properties.flags.enabledTrack
        flags.originalTrack = track.properties.flags.flagOriginal
        flags.visualImpairedTrack = track.properties.flags.flagVisualImpaired
        flags.commentaryTrack = track.properties.flags.flagCommentary
        trackName = track.properties.trackName ?? ""
        language = track.properties.language ?? ""
        crop.pixelCropTop = track.properties.video.pixelCropTop
        crop.pixelCropBottom = track.properties.video.pixelCropBottom
        crop.pixelCropLeft = track.properties.video.pixelCropLeft
        crop.pixelCropRight = track.properties.video.pixelCropRight
    }

    func changes(from track: MKVTrack) -> TrackPropertyEdits {
        var diff = TrackPropertyEdits()

        if let val = flags.defaultTrack, val != track.properties.flags.defaultTrack {
            diff.flags.defaultTrack = val
        }
        if let val = flags.forcedTrack, val != track.properties.flags.forcedTrack {
            diff.flags.forcedTrack = val
        }
        if let val = flags.enabledTrack, val != track.properties.flags.enabledTrack {
            diff.flags.enabledTrack = val
        }
        if let val = flags.originalTrack, val != track.properties.flags.flagOriginal {
            diff.flags.originalTrack = val
        }
        if let val = flags.visualImpairedTrack, val != track.properties.flags.flagVisualImpaired {
            diff.flags.visualImpairedTrack = val
        }
        if let val = flags.commentaryTrack, val != track.properties.flags.flagCommentary {
            diff.flags.commentaryTrack = val
        }
        if let name = trackName, name != (track.properties.trackName ?? "") {
            diff.trackName = name
        }
        if let lang = language, lang != (track.properties.language ?? "") {
            diff.language = lang
        }
        if let val = crop.pixelCropTop, val != track.properties.video.pixelCropTop {
            diff.crop.pixelCropTop = val
        }
        if let val = crop.pixelCropBottom, val != track.properties.video.pixelCropBottom {
            diff.crop.pixelCropBottom = val
        }
        if let val = crop.pixelCropLeft, val != track.properties.video.pixelCropLeft {
            diff.crop.pixelCropLeft = val
        }
        if let val = crop.pixelCropRight, val != track.properties.video.pixelCropRight {
            diff.crop.pixelCropRight = val
        }

        return diff
    }
}
