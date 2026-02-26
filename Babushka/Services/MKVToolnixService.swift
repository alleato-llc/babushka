import Foundation

enum MKVToolnixError: Error, LocalizedError {
    case toolNotFound
    case processError(exitCode: Int32, stderr: String)
    case invalidJSON(underlying: Error)
    case fileNotFound(String)

    var errorDescription: String? {
        switch self {
        case .toolNotFound:
            return "mkvmerge not found. Please install mkvtoolnix."
        case .processError(let exitCode, let stderr):
            return "mkvmerge failed (exit code \(exitCode)): \(stderr)"
        case .invalidJSON(let underlying):
            return "Failed to parse mkvmerge output: \(underlying.localizedDescription)"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        }
    }
}

actor MKVToolnixService {
    private let locator: MKVToolnixLocator
    private var cachedInfo: MKVToolnixInfo?

    init(locator: MKVToolnixLocator = MKVToolnixLocator()) {
        self.locator = locator
    }

    func identify(filePath: String) async throws -> MKVIdentification {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw MKVToolnixError.fileNotFound(filePath)
        }

        let info = try await getToolInfo()

        let (stdout, stderr, exitCode) = try await runProcess(
            executablePath: info.path,
            arguments: ["-J", filePath]
        )

        // Exit codes: 0 = success, 1 = warnings (still OK), 2+ = error
        guard exitCode <= 1 else {
            throw MKVToolnixError.processError(exitCode: exitCode, stderr: stderr)
        }

        do {
            let decoder = JSONDecoder()
            let identification = try decoder.decode(MKVIdentification.self, from: Data(stdout.utf8))
            return identification
        } catch {
            throw MKVToolnixError.invalidJSON(underlying: error)
        }
    }

    func getToolInfo() async throws -> MKVToolnixInfo {
        if let cached = cachedInfo {
            return cached
        }

        guard let info = await locator.locate() else {
            throw MKVToolnixError.toolNotFound
        }

        cachedInfo = info
        return info
    }

    func extractAttachment(filePath: String, attachmentId: Int) async throws -> String {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw MKVToolnixError.fileNotFound(filePath)
        }

        let info = try await getToolInfo()
        let mkvextractPath = info.mkvextractPath

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("babushka-attachments", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let outputPath = tempDir.appendingPathComponent("\(UUID().uuidString)").path

        let (_, stderr, exitCode) = try await runProcess(
            executablePath: mkvextractPath,
            arguments: [filePath, "attachments", "\(attachmentId):\(outputPath)"]
        )

        guard exitCode == 0 else {
            throw MKVToolnixError.processError(exitCode: exitCode, stderr: stderr)
        }

        return outputPath
    }

    func extractTrack(filePath: String, trackId: Int, outputPath: String) async throws {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw MKVToolnixError.fileNotFound(filePath)
        }

        let info = try await getToolInfo()
        let mkvextractPath = info.mkvextractPath

        let (_, stderr, exitCode) = try await runProcess(
            executablePath: mkvextractPath,
            arguments: [filePath, "tracks", "\(trackId):\(outputPath)"]
        )

        guard exitCode == 0 else {
            throw MKVToolnixError.processError(exitCode: exitCode, stderr: stderr)
        }
    }

    func extractAttachmentTo(filePath: String, attachmentId: Int, outputPath: String) async throws {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw MKVToolnixError.fileNotFound(filePath)
        }

        let info = try await getToolInfo()
        let mkvextractPath = info.mkvextractPath

        let (_, stderr, exitCode) = try await runProcess(
            executablePath: mkvextractPath,
            arguments: [filePath, "attachments", "\(attachmentId):\(outputPath)"]
        )

        guard exitCode == 0 else {
            throw MKVToolnixError.processError(exitCode: exitCode, stderr: stderr)
        }
    }

    func applyChangeset(filePath: String, changeset: ResolvedChangeset, allTracks: [MKVTrack], outputPath: String) async throws {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw MKVToolnixError.fileNotFound(filePath)
        }

        if changeset.hasStructuralChanges {
            try await applyWithMkvmerge(filePath: filePath, changeset: changeset, allTracks: allTracks, outputPath: outputPath)
        } else {
            try await applyWithMkvpropedit(filePath: filePath, changeset: changeset, allTracks: allTracks)
        }
    }

    private func applyWithMkvmerge(filePath: String, changeset: ResolvedChangeset, allTracks: [MKVTrack], outputPath: String) async throws {
        let info = try await getToolInfo()

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

        let (_, stderr, exitCode) = try await runProcess(
            executablePath: info.path,
            arguments: arguments
        )

        guard exitCode <= 1 else {
            throw MKVToolnixError.processError(exitCode: exitCode, stderr: stderr)
        }
    }

    private func applyWithMkvpropedit(filePath: String, changeset: ResolvedChangeset, allTracks: [MKVTrack]) async throws {
        guard !changeset.propertyEdits.isEmpty else { return }

        let info = try await getToolInfo()

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

        let (_, stderr, exitCode) = try await runProcess(
            executablePath: info.mkvpropeditPath,
            arguments: arguments
        )

        guard exitCode <= 1 else {
            throw MKVToolnixError.processError(exitCode: exitCode, stderr: stderr)
        }
    }

    func checkAvailability() async -> MKVToolnixInfo? {
        try? await getToolInfo()
    }

    private func runProcess(executablePath: String, arguments: [String]) async throws -> (stdout: String, stderr: String, exitCode: Int32) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return (stdout, stderr, process.terminationStatus)
    }
}
