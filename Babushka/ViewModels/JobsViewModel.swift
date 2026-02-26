import Foundation

@Observable
@MainActor
final class JobsViewModel {
    private(set) var jobs: [ExportJob] = []

    private let service: MKVToolnixService

    init(service: MKVToolnixService) {
        self.service = service
    }

    var activeJobCount: Int {
        jobs.filter { $0.status == .pending || $0.status == .running }.count
    }

    var hasActiveJobs: Bool {
        activeJobCount > 0
    }

    func exportTrack(track: MKVTrack, filePath: String, outputPath: String, displayName: String) {
        let job = ExportJob(
            name: displayName,
            sourceFilePath: filePath,
            outputPath: outputPath,
            jobType: .trackExport(trackId: track.id)
        )
        jobs.insert(job, at: 0)

        Task {
            job.markRunning()
            do {
                try await service.extractTrack(
                    filePath: filePath,
                    trackId: track.id,
                    outputPath: outputPath
                )
                job.markCompleted()
            } catch {
                job.markFailed(error.localizedDescription)
            }
        }
    }

    func exportAttachment(attachment: MKVAttachment, filePath: String, outputPath: String, displayName: String) {
        let job = ExportJob(
            name: displayName,
            sourceFilePath: filePath,
            outputPath: outputPath,
            jobType: .attachmentExport(attachmentId: attachment.id)
        )
        jobs.insert(job, at: 0)

        Task {
            job.markRunning()
            do {
                try await service.extractAttachmentTo(
                    filePath: filePath,
                    attachmentId: attachment.id,
                    outputPath: outputPath
                )
                job.markCompleted()
            } catch {
                job.markFailed(error.localizedDescription)
            }
        }
    }

    func applyChangeset(
        resolved: ResolvedChangeset,
        allTracks: [MKVTrack],
        filePath: String,
        outputPath: String,
        outputMode: OutputMode,
        displayName: String,
        onComplete: @escaping @Sendable () async -> Void
    ) {
        let job = ExportJob(
            name: displayName,
            sourceFilePath: filePath,
            outputPath: outputPath,
            jobType: .applyChangeset
        )
        jobs.insert(job, at: 0)

        Task {
            job.markRunning()
            do {
                if resolved.hasStructuralChanges {
                    // mkvmerge writes to a new file
                    try await service.applyChangeset(
                        filePath: filePath,
                        changeset: resolved,
                        allTracks: allTracks,
                        outputPath: outputPath
                    )

                    // Handle output mode file operations
                    switch outputMode {
                    case .backup:
                        let backupPath = filePath + ".bak"
                        let fm = FileManager.default
                        if fm.fileExists(atPath: backupPath) {
                            try fm.removeItem(atPath: backupPath)
                        }
                        try fm.moveItem(atPath: filePath, toPath: backupPath)
                        try fm.moveItem(atPath: outputPath, toPath: filePath)
                    case .inline:
                        let fm = FileManager.default
                        try fm.removeItem(atPath: filePath)
                        try fm.moveItem(atPath: outputPath, toPath: filePath)
                    case .specifyLocation:
                        break // output already at user-chosen path
                    }
                } else {
                    // mkvpropedit modifies in place
                    try await service.applyChangeset(
                        filePath: filePath,
                        changeset: resolved,
                        allTracks: allTracks,
                        outputPath: outputPath
                    )
                }

                job.markCompleted()
                await onComplete()
            } catch {
                job.markFailed(error.localizedDescription)
            }
        }
    }

    func clearCompleted() {
        jobs.removeAll { job in
            if case .completed = job.status { return true }
            if case .failed = job.status { return true }
            return false
        }
    }
}
