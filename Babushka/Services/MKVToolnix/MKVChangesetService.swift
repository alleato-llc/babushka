import Foundation

actor MKVChangesetService {
    private let locator: MKVToolnixLocator
    private let processRunner: ProcessRunner
    private let mergeBuilder: MkvmergeCommandBuilder
    private let propeditBuilder: MkvpropeditCommandBuilder
    private var cachedInfo: MKVToolnixInfo?

    init(
        locator: MKVToolnixLocator, processRunner: ProcessRunner,
        mergeBuilder: MkvmergeCommandBuilder = MkvmergeCommandBuilder(),
        propeditBuilder: MkvpropeditCommandBuilder = MkvpropeditCommandBuilder()
    ) {
        self.locator = locator
        self.processRunner = processRunner
        self.mergeBuilder = mergeBuilder
        self.propeditBuilder = propeditBuilder
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
        let arguments = mergeBuilder.buildArguments(
            filePath: filePath, outputPath: outputPath,
            changeset: changeset, allTracks: allTracks
        )

        let (_, stderr, exitCode) = try await processRunner.run(
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
        let arguments = propeditBuilder.buildArguments(
            filePath: filePath, changeset: changeset, allTracks: allTracks
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
