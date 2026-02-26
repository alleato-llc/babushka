import Foundation

enum JobStatus: Sendable, Equatable {
    case pending
    case running
    case completed
    case failed(String)
}

enum JobType: Sendable {
    case trackExport(trackId: Int)
    case attachmentExport(attachmentId: Int)
    case applyChangeset

    var actionVerb: String {
        switch self {
        case .trackExport, .attachmentExport: "Exporting"
        case .applyChangeset: "Applying changes"
        }
    }
}

@Observable
@MainActor
final class ExportJob: Identifiable {
    let id = UUID()
    let name: String
    let sourceFilePath: String
    let outputPath: String
    let jobType: JobType
    let createdAt: Date

    private(set) var status: JobStatus = .pending

    init(name: String, sourceFilePath: String, outputPath: String, jobType: JobType) {
        self.name = name
        self.sourceFilePath = sourceFilePath
        self.outputPath = outputPath
        self.jobType = jobType
        self.createdAt = Date()
    }

    func markRunning() { status = .running }
    func markCompleted() { status = .completed }
    func markFailed(_ message: String) { status = .failed(message) }
}
