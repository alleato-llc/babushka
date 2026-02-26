import Foundation

struct MkvpropeditCommandBuilder: Sendable {
    func buildArguments(
        filePath: String,
        changeset: ResolvedChangeset, allTracks: [MKVTrack]
    ) -> [String] {
        var arguments: [String] = [filePath]

        for (trackId, edits) in changeset.propertyEdits {
            let track = allTracks.first { $0.id == trackId }

            // Use UID selector when available, fall back to track number
            if let uid = track?.properties.uid {
                arguments.append(contentsOf: ["--edit", "track:=\(uid)"])
            } else {
                arguments.append(contentsOf: ["--edit", "track:\(trackId + 1)"])
            }

            if let val = edits.flags.defaultTrack {
                arguments.append(contentsOf: ["--set", "flag-default=\(val ? 1 : 0)"])
            }
            if let val = edits.flags.forcedTrack {
                arguments.append(contentsOf: ["--set", "flag-forced=\(val ? 1 : 0)"])
            }
            if let val = edits.flags.enabledTrack {
                arguments.append(contentsOf: ["--set", "flag-enabled=\(val ? 1 : 0)"])
            }
            if let name = edits.trackName {
                if name.isEmpty {
                    arguments.append(contentsOf: ["--delete", "name"])
                } else {
                    arguments.append(contentsOf: ["--set", "name=\(name)"])
                }
            }
            if let lang = edits.language {
                if lang.isEmpty {
                    arguments.append(contentsOf: ["--set", "language=und"])
                } else {
                    arguments.append(contentsOf: ["--set", "language=\(lang)"])
                }
            }
            if let val = edits.flags.originalTrack {
                arguments.append(contentsOf: ["--set", "flag-original=\(val ? 1 : 0)"])
            }
            if let val = edits.flags.visualImpairedTrack {
                arguments.append(contentsOf: ["--set", "flag-visual-impaired=\(val ? 1 : 0)"])
            }
            if let val = edits.flags.commentaryTrack {
                arguments.append(contentsOf: ["--set", "flag-commentary=\(val ? 1 : 0)"])
            }
            if let val = edits.crop.pixelCropTop {
                arguments.append(contentsOf: ["--set", "pixel-crop-top=\(val)"])
            }
            if let val = edits.crop.pixelCropBottom {
                arguments.append(contentsOf: ["--set", "pixel-crop-bottom=\(val)"])
            }
            if let val = edits.crop.pixelCropLeft {
                arguments.append(contentsOf: ["--set", "pixel-crop-left=\(val)"])
            }
            if let val = edits.crop.pixelCropRight {
                arguments.append(contentsOf: ["--set", "pixel-crop-right=\(val)"])
            }
        }

        return arguments
    }
}
