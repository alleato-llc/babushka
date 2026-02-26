import Foundation

actor MKVExtractionService {
    private let locator: MKVToolnixLocator
    private let processRunner: ProcessRunner
    private var cachedInfo: MKVToolnixInfo?

    init(locator: MKVToolnixLocator, processRunner: ProcessRunner) {
        self.locator = locator
        self.processRunner = processRunner
    }

    func extractTrack(filePath: String, trackId: Int, outputPath: String) async throws {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw MKVToolnixError.fileNotFound(filePath)
        }

        let info = try await getToolInfo()

        let (_, stderr, exitCode) = try await processRunner.run(
            executablePath: info.mkvextractPath,
            arguments: [filePath, "tracks", "\(trackId):\(outputPath)"]
        )

        guard exitCode == 0 else {
            throw MKVToolnixError.processError(exitCode: exitCode, stderr: stderr)
        }
    }

    func extractAttachment(filePath: String, attachmentId: Int) async throws -> String {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw MKVToolnixError.fileNotFound(filePath)
        }

        let info = try await getToolInfo()

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("babushka-attachments", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let outputPath = tempDir.appendingPathComponent("\(UUID().uuidString)").path

        let (_, stderr, exitCode) = try await processRunner.run(
            executablePath: info.mkvextractPath,
            arguments: [filePath, "attachments", "\(attachmentId):\(outputPath)"]
        )

        guard exitCode == 0 else {
            throw MKVToolnixError.processError(exitCode: exitCode, stderr: stderr)
        }

        return outputPath
    }

    func extractChapters(filePath: String) async throws -> String? {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw MKVToolnixError.fileNotFound(filePath)
        }

        let info = try await getToolInfo()

        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("babushka-chapters", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let outputPath = tempDir.appendingPathComponent("\(UUID().uuidString).xml").path

        let (_, stderr, exitCode) = try await processRunner.run(
            executablePath: info.mkvextractPath,
            arguments: [filePath, "chapters", outputPath]
        )

        guard exitCode <= 1 else {
            throw MKVToolnixError.processError(exitCode: exitCode, stderr: stderr)
        }

        defer { try? FileManager.default.removeItem(atPath: outputPath) }

        guard FileManager.default.fileExists(atPath: outputPath) else {
            return nil
        }

        let content = try String(contentsOfFile: outputPath, encoding: .utf8)
        return content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : content
    }

    func extractAttachmentTo(filePath: String, attachmentId: Int, outputPath: String) async throws {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw MKVToolnixError.fileNotFound(filePath)
        }

        let info = try await getToolInfo()

        let (_, stderr, exitCode) = try await processRunner.run(
            executablePath: info.mkvextractPath,
            arguments: [filePath, "attachments", "\(attachmentId):\(outputPath)"]
        )

        guard exitCode == 0 else {
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
