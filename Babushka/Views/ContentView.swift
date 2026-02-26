import SwiftUI

struct ContentView: View {
    @Bindable var appViewModel: AppViewModel

    @State private var showJobsPopover = false
    @State private var dropErrorMessage: String?
    @State private var showDropError = false

    var body: some View {
        NavigationSplitView {
            SidebarView(
                fileViewModels: appViewModel.openFiles,
                selection: $appViewModel.selectedSidebarItem,
                onCloseFile: { fileVM in
                    appViewModel.closeFile(fileVM)
                },
                onExportTrack: { track, item in
                    appViewModel.exportTrack(track, sidebarItem: item)
                },
                onExportAttachment: { attachment, item in
                    appViewModel.exportAttachment(attachment, sidebarItem: item)
                },
                onRemoveTrack: { track, item in
                    appViewModel.removeTrack(track, sidebarItem: item)
                },
                onAddTrack: { fileVM, trackType in
                    appViewModel.addTrack(to: fileVM, trackType: trackType)
                },
                onReorderTracks: { fileVM in
                    appViewModel.reorderingFileId = fileVM.id
                },
                onEditChapters: { fileVM in
                    appViewModel.editingChaptersFileId = fileVM.id
                },
                onAddChapters: { fileVM in
                    appViewModel.editingChaptersFileId = fileVM.id
                }
            )
        } detail: {
            VStack(spacing: 0) {
                detailContent
                    .frame(maxHeight: .infinity)

                // Pending changes bar
                if let fileVM = activeFileViewModel, fileVM.hasPendingChanges {
                    Divider()
                    PendingChangesBar(
                        fileViewModel: fileVM,
                        appViewModel: appViewModel
                    )
                }
            }
        }
        .dropDestination(for: URL.self) { urls, _ in
            handleDrop(urls: urls)
            return true
        }
        .toolbar {
            if case .chapterGroup = appViewModel.selectedSidebarItem,
               let fileVM = activeFileViewModel {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit Chapters...") {
                        appViewModel.editingChaptersFileId = fileVM.id
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showJobsPopover.toggle()
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "list.bullet.circle")
                        if appViewModel.jobsViewModel.hasActiveJobs {
                            Circle()
                                .fill(.blue)
                                .frame(width: 8, height: 8)
                                .offset(x: 2, y: -2)
                        }
                    }
                }
                .help("Jobs")
                .popover(isPresented: $showJobsPopover) {
                    JobsPopoverView(jobsViewModel: appViewModel.jobsViewModel)
                }
            }
        }
        .alert("Cannot Import", isPresented: $showDropError) {
            Button("OK") {}
        } message: {
            Text(dropErrorMessage ?? "")
        }
        .alert("mkvtoolnix Not Found", isPresented: $appViewModel.showMissingToolAlert) {
            Button("OK") {}
        } message: {
            Text("mkvmerge was not found on this system. Please install mkvtoolnix via Homebrew:\n\nbrew install mkvtoolnix")
        }
    }

    private var activeFileViewModel: FileViewModel? {
        if let reorderingId = appViewModel.reorderingFileId {
            return appViewModel.openFiles.first { $0.id == reorderingId }
        }
        if let chapterEditId = appViewModel.editingChaptersFileId {
            return appViewModel.openFiles.first { $0.id == chapterEditId }
        }
        guard let item = appViewModel.selectedSidebarItem else { return nil }
        return appViewModel.fileViewModel(for: item)
    }

    private func handleDrop(urls: [URL]) {
        let mkvURLs = urls.filter { $0.pathExtension.lowercased() == "mkv" }
        let nonMKVURLs = urls.filter { $0.pathExtension.lowercased() != "mkv" }

        for url in mkvURLs {
            appViewModel.openFileAt(path: url.path)
        }

        if !nonMKVURLs.isEmpty {
            if appViewModel.openFiles.isEmpty && mkvURLs.isEmpty {
                dropErrorMessage = "Please open an MKV file first."
            } else {
                dropErrorMessage = "Import of non-MKV files is not supported yet."
            }
            showDropError = true
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        if let reorderingId = appViewModel.reorderingFileId,
           let fileVM = appViewModel.openFiles.first(where: { $0.id == reorderingId }) {
            TrackReorderView(
                fileViewModel: fileVM,
                appViewModel: appViewModel
            )
        } else if let chapterEditId = appViewModel.editingChaptersFileId,
                  let fileVM = appViewModel.openFiles.first(where: { $0.id == chapterEditId }) {
            ChapterEditorView(
                fileViewModel: fileVM,
                appViewModel: appViewModel
            )
        } else if let selected = appViewModel.selectedSidebarItem {
            detailRouter(for: selected)
        } else if !appViewModel.openFiles.isEmpty {
            Text("Select an item from the sidebar")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            WelcomeView {
                appViewModel.openFile()
            }
        }
    }

    @ViewBuilder
    private func detailRouter(for item: SidebarItem) -> some View {
        switch item {
        case .file:
            if let fileVM = appViewModel.fileViewModel(for: item),
               let identification = fileVM.identification {
                FileSummaryView(
                    identification: identification,
                    fileViewModel: fileVM,
                    appViewModel: appViewModel
                )
            } else if let fileVM = appViewModel.fileViewModel(for: item) {
                fileStateView(for: fileVM)
            }

        case .track(_, let track):
            if let fileVM = appViewModel.fileViewModel(for: item) {
                TrackDetailView(
                    track: track,
                    fileViewModel: fileVM
                )
            }

        case .trackGroup:
            if let fileVM = appViewModel.fileViewModel(for: item),
               let identification = fileVM.identification {
                FileSummaryView(
                    identification: identification,
                    fileViewModel: fileVM,
                    appViewModel: appViewModel
                )
            }

        case .attachment(_, let attachment):
            if let fileVM = appViewModel.fileViewModel(for: item) {
                AttachmentDetailView(
                    attachment: attachment,
                    filePath: fileVM.filePath,
                    appViewModel: appViewModel
                )
            }

        case .attachmentGroup:
            if let fileVM = appViewModel.fileViewModel(for: item),
               let identification = fileVM.identification {
                FileSummaryView(
                    identification: identification,
                    fileViewModel: fileVM,
                    appViewModel: appViewModel
                )
            }

        case .chapterGroup:
            if let fileVM = appViewModel.fileViewModel(for: item) {
                ChapterDetailView(
                    fileViewModel: fileVM
                )
            }
        }
    }

    @ViewBuilder
    private func fileStateView(for fileVM: FileViewModel) -> some View {
        if fileVM.isLoading {
            ProgressView("Loading...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = fileVM.errorMessage {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                Text("Error Loading File")
                    .font(.headline)
                Text(error)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Text("Select an item from the sidebar")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
