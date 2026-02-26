import Foundation

actor MKVToolnixService {
    let identification: MKVIdentificationService
    let extraction: MKVExtractionService
    let changeset: MKVChangesetService

    init(locator: MKVToolnixLocator = MKVToolnixLocator(), processRunner: ProcessRunner = ProcessRunner()) {
        self.identification = MKVIdentificationService(locator: locator, processRunner: processRunner)
        self.extraction = MKVExtractionService(locator: locator, processRunner: processRunner)
        self.changeset = MKVChangesetService(locator: locator, processRunner: processRunner)
    }

    func identify(filePath: String) async throws -> MKVIdentification {
        try await identification.identify(filePath: filePath)
    }

    func getToolInfo() async throws -> MKVToolnixInfo {
        try await identification.getToolInfo()
    }

    func extractAttachment(filePath: String, attachmentId: Int) async throws -> String {
        try await extraction.extractAttachment(filePath: filePath, attachmentId: attachmentId)
    }

    func extractTrack(filePath: String, trackId: Int, outputPath: String) async throws {
        try await extraction.extractTrack(filePath: filePath, trackId: trackId, outputPath: outputPath)
    }

    func extractAttachmentTo(filePath: String, attachmentId: Int, outputPath: String) async throws {
        try await extraction.extractAttachmentTo(filePath: filePath, attachmentId: attachmentId, outputPath: outputPath)
    }

    func applyChangeset(filePath: String, changeset resolved: ResolvedChangeset, allTracks: [MKVTrack], outputPath: String) async throws {
        try await changeset.applyChangeset(filePath: filePath, changeset: resolved, allTracks: allTracks, outputPath: outputPath)
    }

    func checkAvailability() async -> MKVToolnixInfo? {
        await identification.checkAvailability()
    }
}
