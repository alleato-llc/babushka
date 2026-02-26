import Foundation

actor MKVIdentificationService {
    private let locator: MKVToolnixLocator
    private let processRunner: ProcessRunner
    private var cachedInfo: MKVToolnixInfo?

    init(locator: MKVToolnixLocator, processRunner: ProcessRunner) {
        self.locator = locator
        self.processRunner = processRunner
    }

    func identify(filePath: String) async throws -> MKVIdentification {
        guard FileManager.default.fileExists(atPath: filePath) else {
            throw MKVToolnixError.fileNotFound(filePath)
        }

        let info = try await getToolInfo()

        let (stdout, stderr, exitCode) = try await processRunner.run(
            executablePath: info.path,
            arguments: ["-J", filePath]
        )

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

    func checkAvailability() async -> MKVToolnixInfo? {
        try? await getToolInfo()
    }
}
