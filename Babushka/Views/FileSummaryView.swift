import SwiftUI

struct FileSummaryView: View {
    let identification: MKVIdentification
    let fileViewModel: FileViewModel
    @Bindable var appViewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                containerSection
                tracksSection
                if !identification.globalTags.isEmpty {
                    tagsSection
                }
            }
            .padding()
        }
        .navigationTitle(fileViewModel.fileName)
    }

    @ViewBuilder
    private var containerSection: some View {
        GroupBox("Container") {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                PropertyRow(label: "Type", value: identification.container.type)

                if let duration = identification.container.properties.formattedDuration {
                    PropertyRow(label: "Duration", value: duration)
                }

                if let muxer = identification.container.properties.muxingApplication {
                    PropertyRow(label: "Muxing Application", value: muxer)
                }

                if let writer = identification.container.properties.writingApplication {
                    PropertyRow(label: "Writing Application", value: writer)
                }

                if let date = identification.container.properties.dateUtc {
                    PropertyRow(label: "Date", value: date)
                }

                if let title = identification.container.properties.title {
                    PropertyRow(label: "Title", value: title)
                }

                if let uid = identification.container.properties.segmentUid {
                    PropertyRow(label: "Segment UID", value: uid)
                }

                PropertyRow(label: "Format Version", value: "\(identification.identificationFormatVersion)")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var tracksSection: some View {
        GroupBox("Tracks (\(identification.tracks.count))") {
            VStack(spacing: 0) {
                ForEach(identification.tracks) { track in
                    Button {
                        navigateToTrack(track)
                    } label: {
                        TrackRowView(track: track)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if track.id != identification.tracks.last?.id {
                        Divider()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        GroupBox("Tags") {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(identification.globalTags.enumerated()), id: \.offset) { _, tag in
                    if let entries = tag.numEntries {
                        Text("Global tags: \(entries) entries")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func navigateToTrack(_ track: MKVTrack) {
        // Find the sidebar item for this track
        for (_, children) in fileViewModel.sidebarChildren {
            for child in children {
                if case .track(_, let t) = child, t.id == track.id {
                    appViewModel.selectedSidebarItem = child
                    return
                }
            }
        }
    }
}

struct PropertyRow: View {
    let label: String
    let value: String

    var body: some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            Text(value)
                .textSelection(.enabled)
                .gridColumnAlignment(.leading)
        }
    }
}
