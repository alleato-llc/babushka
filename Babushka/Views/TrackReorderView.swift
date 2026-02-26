import SwiftUI

struct TrackReorderView: View {
    let fileViewModel: FileViewModel
    @Bindable var appViewModel: AppViewModel

    @State private var orderedTracks: [MKVTrack] = []

    var body: some View {
        VStack(spacing: 0) {
            Text("Drag tracks to reorder. Changes apply when you click Apply Changes.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding()

            List {
                ForEach(orderedTracks) { track in
                    TrackRowView(track: track)
                        .opacity(fileViewModel.isTrackRemoved(track.id) ? 0.4 : 1.0)
                }
                .onMove { source, destination in
                    orderedTracks.move(fromOffsets: source, toOffset: destination)
                    let trackOrder = orderedTracks.map(\.id)
                    fileViewModel.reorderTracks(order: trackOrder)
                }
            }
            .listStyle(.plain)
        }
        .navigationTitle("Reorder Tracks — \(fileViewModel.fileName)")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Done") {
                    appViewModel.reorderingFileId = nil
                }
            }
        }
        .onAppear {
            orderedTracks = fileViewModel.effectiveTracks
        }
    }
}
