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
