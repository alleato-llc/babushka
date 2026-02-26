import SwiftUI

struct SidebarView: View {
    let fileViewModels: [FileViewModel]
    @Binding var selection: SidebarItem?
    var onCloseFile: ((FileViewModel) -> Void)?
    var onExportTrack: ((MKVTrack, SidebarItem) -> Void)?
    var onExportAttachment: ((MKVAttachment, SidebarItem) -> Void)?
    var onRemoveTrack: ((MKVTrack, SidebarItem) -> Void)?
    var onAddTrack: ((FileViewModel, TrackType) -> Void)?
    var onReorderTracks: ((FileViewModel) -> Void)?

    var body: some View {
        List(selection: Binding(
            get: { selection?.id },
            set: { newId in
                selection = findItem(by: newId)
            }
        )) {
            ForEach(fileViewModels) { fileVM in
                ForEach(fileVM.sidebarItems) { item in
                    sidebarRow(for: item, in: fileVM)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Files")
    }

    @ViewBuilder
    private func sidebarRow(for item: SidebarItem, in fileVM: FileViewModel) -> some View {
        switch item {
        case .file(let id, _):
            if let children = fileVM.sidebarChildren[id] {
                Section {
                    ForEach(children) { child in
                        groupRow(for: child, in: fileVM)
                    }

                    // Pending additions section
                    let resolved = fileVM.resolvedChangeset
                    if !resolved.addedTracks.isEmpty {
                        DisclosureGroup {
                            ForEach(resolved.addedTracks, id: \.id) { entry in
                                Label(
                                    URL(fileURLWithPath: entry.addition.filePath).lastPathComponent,
                                    systemImage: "plus.circle"
                                )
                                .foregroundStyle(.green)
                            }
                        } label: {
                            Label("Pending Additions (\(resolved.addedTracks.count))", systemImage: "plus.circle")
                                .foregroundStyle(.green)
                        }
                    }
                } header: {
                    HStack(spacing: 4) {
                        Label(item.displayName, systemImage: item.systemImage)
                        if fileVM.hasPendingChanges {
                            Circle()
                                .fill(.orange)
                                .frame(width: 6, height: 6)
                        }
                    }
                    .tag(item.id)
                    .contextMenu {
                        Button("Reorder Tracks...") {
                            onReorderTracks?(fileVM)
                        }
                        Divider()
                        Button("Close File") {
                            onCloseFile?(fileVM)
                        }
                    }
                }
            } else {
                Label(item.displayName, systemImage: item.systemImage)
                    .tag(item.id)
            }

        default:
            Label(item.displayName, systemImage: item.systemImage)
                .tag(item.id)
        }
    }

    @ViewBuilder
    private func groupRow(for item: SidebarItem, in fileVM: FileViewModel) -> some View {
        switch item {
        case .trackGroup(let id, let trackType, _):
            if let children = fileVM.sidebarChildren[id] {
                DisclosureGroup {
                    ForEach(children) { child in
                        childRow(for: child, in: fileVM)
                    }
                } label: {
                    Label(item.displayName, systemImage: item.systemImage)
                        .tag(item.id)
                        .contextMenu {
                            Button("Add \(trackType.displayName) Track...") {
                                onAddTrack?(fileVM, trackType)
                            }
                        }
                }
            }

        case .attachmentGroup(let id, _):
            if let children = fileVM.sidebarChildren[id] {
                DisclosureGroup {
                    ForEach(children) { child in
                        childRow(for: child, in: fileVM)
                    }
                } label: {
                    Label(item.displayName, systemImage: item.systemImage)
                        .tag(item.id)
                }
            }

        default:
            Label(item.displayName, systemImage: item.systemImage)
                .tag(item.id)
        }
    }

    @ViewBuilder
    private func childRow(for item: SidebarItem, in fileVM: FileViewModel) -> some View {
        switch item {
        case .track(_, let track):
            HStack(spacing: 4) {
                Label(item.displayName, systemImage: item.systemImage)
                    .strikethrough(fileVM.isTrackRemoved(track.id))
                    .opacity(fileVM.isTrackRemoved(track.id) ? 0.5 : 1.0)
                if fileVM.hasPropertyEdits(for: track.id) && !fileVM.isTrackRemoved(track.id) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                }
            }
            .tag(item.id)
            .contextMenu {
                Button("Export \(track.displayName)...") {
                    onExportTrack?(track, item)
                }
                Divider()
                if fileVM.isTrackRemoved(track.id) {
                    Button("Restore Track") {
                        fileVM.undoLastChange()
                    }
                } else {
                    Button("Delete Track", role: .destructive) {
                        onRemoveTrack?(track, item)
                    }
                }
            }

        case .attachment(_, let attachment):
            Label(item.displayName, systemImage: item.systemImage)
                .tag(item.id)
                .contextMenu {
                    Button("Export \(attachment.displayName)...") {
                        onExportAttachment?(attachment, item)
                    }
                }

        default:
            Label(item.displayName, systemImage: item.systemImage)
                .tag(item.id)
        }
    }

    private func findItem(by id: UUID?) -> SidebarItem? {
        guard let id = id else { return nil }

        for fileVM in fileViewModels {
            if let found = fileVM.findItem(withId: id) {
                return found
            }
        }

        return nil
    }
}
