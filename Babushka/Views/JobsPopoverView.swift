import SwiftUI

struct JobsPopoverView: View {
    @Bindable var jobsViewModel: JobsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Jobs")
                    .font(.headline)
                Spacer()
                if jobsViewModel.jobs.contains(where: { isFinished($0) }) {
                    Button("Clear Finished") {
                        jobsViewModel.clearCompleted()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)

            Divider()

            if jobsViewModel.jobs.isEmpty {
                Text("No jobs")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(jobsViewModel.jobs) { job in
                            JobRowView(job: job)
                            Divider()
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
        .frame(width: 320)
    }

    private func isFinished(_ job: ExportJob) -> Bool {
        switch job.status {
        case .completed, .failed: return true
        default: return false
        }
    }
}

struct JobRowView: View {
    let job: ExportJob

    var body: some View {
        HStack(spacing: 8) {
            statusIcon
            VStack(alignment: .leading, spacing: 2) {
                Text(job.name)
                    .lineLimit(1)
                statusText
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch job.status {
        case .pending:
            Image(systemName: "clock")
                .foregroundStyle(.secondary)
        case .running:
            ProgressView()
                .controlSize(.small)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch job.status {
        case .pending:
            Text("Waiting...")
        case .running:
            Text("\(job.jobType.actionVerb)...")
        case .completed:
            Text("Completed")
        case .failed(let message):
            Text("Failed: \(message)")
                .lineLimit(2)
        }
    }
}
