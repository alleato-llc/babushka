import Foundation

enum TestFile: String, CaseIterable {
    case test5 = "test5.mkv"

    var url: URL {
        switch self {
        case .test5:
            return URL(string: "https://github.com/ietf-wg-cellar/matroska-test-files/raw/master/test_files/test5.mkv")!
        }
    }
}

actor TestFileManager {
    static let shared = TestFileManager()

    private let cacheDirectory: URL

    private init() {
        let tempDir = FileManager.default.temporaryDirectory
        cacheDirectory = tempDir.appendingPathComponent("BabushkaTestFiles")
        try? FileManager.default.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func path(for file: TestFile) async throws -> String {
        let localURL = cacheDirectory.appendingPathComponent(file.rawValue)

        if FileManager.default.fileExists(atPath: localURL.path) {
            return localURL.path
        }

        let (data, response) = try await URLSession.shared.data(from: file.url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw TestFileError.downloadFailed(file.rawValue)
        }

        try data.write(to: localURL)
        return localURL.path
    }
}

enum TestFileError: Error, LocalizedError {
    case downloadFailed(String)

    var errorDescription: String? {
        switch self {
        case .downloadFailed(let name):
            return "Failed to download test file: \(name)"
        }
    }
}
