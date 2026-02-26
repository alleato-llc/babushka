import Foundation

struct MkvmergeCommandBuilder: Sendable {
    func buildArguments(
        filePath: String, outputPath: String,
        changeset: ResolvedChangeset, allTracks: [MKVTrack],
        chapterFilePath: String? = nil
    ) -> [String] {
        var arguments: [String] = ["-o", outputPath]

        // Handle track removals: build selection args per type
        let tracksByType = Dictionary(grouping: allTracks) { $0.type }

        for trackType in [TrackType.video, .audio, .subtitles] {
            let tracksOfType = tracksByType[trackType] ?? []
            let keepIds = tracksOfType.filter { !changeset.removedTrackIds.contains($0.id) }.map { $0.id }

            if tracksOfType.isEmpty { continue }

            if keepIds.isEmpty {
                switch trackType {
                case .video: arguments.append("-D")
                case .audio: arguments.append("-A")
                case .subtitles: arguments.append("-S")
                case .unknown: break
                }
            } else if keepIds.count < tracksOfType.count {
                let idList = keepIds.map(String.init).joined(separator: ",")
                switch trackType {
                case .video: arguments.append(contentsOf: ["-d", idList])
                case .audio: arguments.append(contentsOf: ["-a", idList])
                case .subtitles: arguments.append(contentsOf: ["-s", idList])
                case .unknown: break
                }
            }
        }

        // Fold property edits into mkvmerge flags for existing tracks
        for (trackId, edits) in changeset.propertyEdits {
            if let name = edits.trackName {
                arguments.append(contentsOf: ["--track-name", "\(trackId):\(name)"])
            }
            if let lang = edits.language {
                let langValue = lang.isEmpty ? "und" : lang
                arguments.append(contentsOf: ["--language", "\(trackId):\(langValue)"])
            }
            if let val = edits.flags.defaultTrack {
                arguments.append(contentsOf: ["--default-track-flag", "\(trackId):\(val ? 1 : 0)"])
            }
            if let val = edits.flags.forcedTrack {
                arguments.append(contentsOf: ["--forced-track-flag", "\(trackId):\(val ? 1 : 0)"])
            }
            if let val = edits.flags.enabledTrack {
                arguments.append(contentsOf: ["--track-enabled-flag", "\(trackId):\(val ? 1 : 0)"])
            }
            if let val = edits.flags.originalTrack {
                arguments.append(contentsOf: ["--original-flag", "\(trackId):\(val ? 1 : 0)"])
            }
            if let val = edits.flags.visualImpairedTrack {
                arguments.append(contentsOf: ["--visual-impaired-flag", "\(trackId):\(val ? 1 : 0)"])
            }
            if let val = edits.flags.commentaryTrack {
                arguments.append(contentsOf: ["--commentary-flag", "\(trackId):\(val ? 1 : 0)"])
            }
            if edits.crop.pixelCropTop != nil || edits.crop.pixelCropBottom != nil
                || edits.crop.pixelCropLeft != nil || edits.crop.pixelCropRight != nil {
                let top = edits.crop.pixelCropTop ?? 0
                let bottom = edits.crop.pixelCropBottom ?? 0
                let left = edits.crop.pixelCropLeft ?? 0
                let right = edits.crop.pixelCropRight ?? 0
                arguments.append(contentsOf: ["--cropping", "\(trackId):\(top),\(bottom),\(left),\(right)"])
            }
        }

        // Track order
        if let order = changeset.trackOrder {
            let orderString = order.map { "0:\($0)" }.joined(separator: ",")
            arguments.append(contentsOf: ["--track-order", orderString])
        }

        // Chapter options
        if changeset.removeChapters {
            arguments.append("--no-chapters")
        } else if let chapterPath = chapterFilePath {
            arguments.append(contentsOf: ["--chapters", chapterPath])
        }

        // Input file
        arguments.append(filePath)

        // Additional track files
        for (_, addition) in changeset.addedTracks {
            if let lang = addition.language, !lang.isEmpty {
                arguments.append(contentsOf: ["--language", "0:\(lang)"])
            }
            if let name = addition.trackName, !name.isEmpty {
                arguments.append(contentsOf: ["--track-name", "0:\(name)"])
            }
            if let isDefault = addition.defaultTrack {
                arguments.append(contentsOf: ["--default-track-flag", "0:\(isDefault ? 1 : 0)"])
            }
            arguments.append(addition.filePath)
        }

        return arguments
    }
}
