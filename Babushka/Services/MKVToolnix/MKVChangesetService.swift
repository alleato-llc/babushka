import Foundation

actor MKVChangesetService {
    private let locator: MKVToolnixLocator
    private let processRunner: ProcessRunner
    private let mergeBuilder: MkvmergeCommandBuilder
    private let propeditBuilder: MkvpropeditCommandBuilder
    private let chapterXMLService: ChapterXMLService
    private var cachedInfo: MKVToolnixInfo?

    init(
        locator: MKVToolnixLocator, processRunner: ProcessRunner,
        mergeBuilder: MkvmergeCommandBuilder = MkvmergeCommandBuilder(),
        propeditBuilder: MkvpropeditCommandBuilder = MkvpropeditCommandBuilder(),
        chapterXMLService: ChapterXMLService = ChapterXMLService()
    ) {
        self.locator = locator
        self.processRunner = processRunner
        self.mergeBuilder = mergeBuilder
        self.propeditBuilder = propeditBuilder
        self.chapterXMLService = chapterXMLService
    }

    func applyChangeset(filePath: String, changeset: ResolvedChangeset, allTracks: [MKVTrack], outputPath: String) async throws {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw MKVToolnixError.fileNotFound(filePath)
        }

        // Write chapter XML to temp file if needed
        var chapterFilePath: String?
        if let chapterEdits = changeset.chapterEdits {
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("babushka-chapters", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            let tempPath = tempDir.appendingPathComponent("\(UUID().uuidString).xml").path
            let xml = chapterXMLService.generate(editions: chapterEdits)
            try xml.write(toFile: tempPath, atomically: true, encoding: .utf8)
            chapterFilePath = tempPath
        }

        defer {
            if let path = chapterFilePath {
                try? FileManager.default.removeItem(atPath: path)
            }
        }

        if changeset.hasStructuralChanges {
            try await applyWithMkvmerge(filePath: filePath, changeset: changeset, allTracks: allTracks, outputPath: outputPath, chapterFilePath: chapterFilePath)
        } else {
            try await applyWithMkvpropedit(filePath: filePath, changeset: changeset, allTracks: allTracks, chapterFilePath: chapterFilePath)
        }
    }

    private func applyWithMkvmerge(filePath: String, changeset: ResolvedChangeset, allTracks: [MKVTrack], outputPath: String, chapterFilePath: String? = nil) async throws {
        let info = try await getToolInfo()
        let arguments = mergeBuilder.buildArguments(
            filePath: filePath, outputPath: outputPath,
            changeset: changeset, allTracks: allTracks,
            chapterFilePath: chapterFilePath
        )

        let (_, stderr, exitCode) = try await processRunner.run(
            executablePath: info.path,
            arguments: arguments
        )

        guard exitCode <= 1 else {
            throw MKVToolnixError.processError(exitCode: exitCode, stderr: stderr)
        }
    }

    private func applyWithMkvpropedit(filePath: String, changeset: ResolvedChangeset, allTracks: [MKVTrack], chapterFilePath: String? = nil) async throws {
        guard !changeset.propertyEdits.isEmpty || changeset.chapterEdits != nil || changeset.removeChapters else { return }

        let info = try await getToolInfo()
        let arguments = propeditBuilder.buildArguments(
            filePath: filePath, changeset: changeset, allTracks: allTracks,
            chapterFilePath: chapterFilePath
        )

        let (_, stderr, exitCode) = try await processRunner.run(
            executablePath: info.mkvpropeditPath,
            arguments: arguments
        )

        guard exitCode <= 1 else {
            throw MKVToolnixError.processError(exitCode: exitCode, stderr: stderr)
        }
    }

    private func getToolInfo() async throws -> MKVToolnixInfo {
        if let cached = cachedInfo {
            return cached
        }

        guard let info = await locator.locate() else {
            throw MKVToolnixError.toolNotFound
        }

        cachedInfo = info
        return info
    }
}
