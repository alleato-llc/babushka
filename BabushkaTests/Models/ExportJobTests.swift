import Foundation
import Testing
@testable import Babushka

@Suite("ExportJob Tests")
struct ExportJobTests {

    @Test("Initial state is pending")
    @MainActor
    func initialStateIsPending() {
        let job = ExportJob(name: "Track 0", sourceFilePath: "/in.mkv", outputPath: "/out.h264", jobType: .trackExport(trackId: 0))
        #expect(job.status == .pending)
    }

    @Test("markRunning transitions to running")
    @MainActor
    func markRunningTransition() {
        let job = ExportJob(name: "Track 0", sourceFilePath: "/in.mkv", outputPath: "/out.h264", jobType: .trackExport(trackId: 0))
        job.markRunning()
        #expect(job.status == .running)
    }

    @Test("markCompleted transitions to completed")
    @MainActor
    func markCompletedTransition() {
        let job = ExportJob(name: "Track 0", sourceFilePath: "/in.mkv", outputPath: "/out.h264", jobType: .trackExport(trackId: 0))
        job.markRunning()
        job.markCompleted()
        #expect(job.status == .completed)
    }

    @Test("markFailed transitions to failed and preserves message")
    @MainActor
    func markFailedTransition() {
        let job = ExportJob(name: "Track 0", sourceFilePath: "/in.mkv", outputPath: "/out.h264", jobType: .trackExport(trackId: 0))
        job.markRunning()
        job.markFailed("Process exited with code 2")
        #expect(job.status == .failed("Process exited with code 2"))
    }

    @Test("Pending and running are active states")
    @MainActor
    func activeStates() {
        let job = ExportJob(name: "Test", sourceFilePath: "/in.mkv", outputPath: "/out.mkv", jobType: .applyChangeset)
        #expect(job.status == .pending)
        job.markRunning()
        #expect(job.status == .running)
    }

    @Test("Completed and failed are terminal states")
    @MainActor
    func terminalStates() {
        let job1 = ExportJob(name: "Test1", sourceFilePath: "/in.mkv", outputPath: "/out.mkv", jobType: .applyChangeset)
        job1.markCompleted()
        #expect(job1.status == .completed)

        let job2 = ExportJob(name: "Test2", sourceFilePath: "/in.mkv", outputPath: "/out.mkv", jobType: .applyChangeset)
        job2.markFailed("error")
        #expect(job2.status == .failed("error"))
    }

    @Test("JobType actionVerb returns correct strings")
    func actionVerbStrings() {
        #expect(JobType.trackExport(trackId: 0).actionVerb == "Exporting")
        #expect(JobType.attachmentExport(attachmentId: 0).actionVerb == "Exporting")
        #expect(JobType.applyChangeset.actionVerb == "Applying changes")
    }

    @Test("Initializer sets all properties correctly")
    @MainActor
    func initializerSetsProperties() {
        let job = ExportJob(
            name: "Export Audio",
            sourceFilePath: "/path/to/source.mkv",
            outputPath: "/path/to/output.aac",
            jobType: .trackExport(trackId: 3)
        )
        #expect(job.name == "Export Audio")
        #expect(job.sourceFilePath == "/path/to/source.mkv")
        #expect(job.outputPath == "/path/to/output.aac")
        if case .trackExport(let tid) = job.jobType {
            #expect(tid == 3)
        } else {
            Issue.record("Expected trackExport job type")
        }
    }
}
