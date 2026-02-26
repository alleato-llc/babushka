import Foundation
import SwiftUI
import AppKit

@Observable
@MainActor
final class AppViewModel {
    private(set) var toolInfo: MKVToolnixInfo?
    private(set) var isToolAvailable = false
    private(set) var isCheckingTool = true

    var showMissingToolAlert = false
    var selectedSidebarItem: SidebarItem?
    var reorderingFileId: UUID?
    var outputMode: OutputMode {
        get {
            OutputMode(rawValue: UserDefaults.standard.string(forKey: "outputMode") ?? OutputMode.backup.rawValue) ?? .backup
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: "outputMode")
        }
    }

    private(set) var openFiles: [FileViewModel] = []

    let service: MKVToolnixService
    let jobsViewModel: JobsViewModel

    init(service: MKVToolnixService = MKVToolnixService()) {
        self.service = service
        self.jobsViewModel = JobsViewModel(service: service)
    }

    func checkToolAvailability() async {
        isCheckingTool = true
        let info = await service.checkAvailability()
        toolInfo = info
        isToolAvailable = info != nil
        isCheckingTool = false

        if info == nil {
            showMissingToolAlert = true
        }
    }

    func openFile() {
        guard isToolAvailable else {
            showMissingToolAlert = true
            return
        }

        let panel = NSOpenPanel()
        panel.title = "Open MKV File"
        panel.allowedContentTypes = [.init(filenameExtension: "mkv")!]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK else { return }

        for url in panel.urls {
            openFileAt(path: url.path)
        }
    }

    func openFileAt(path: String) {
        guard isToolAvailable else {
            showMissingToolAlert = true
            return
        }

        guard !openFiles.contains(where: { $0.filePath == path }) else { return }

        let viewModel = FileViewModel(filePath: path, service: service)
        openFiles.append(viewModel)
        selectedSidebarItem = SidebarItem.file(id: viewModel.id, fileName: viewModel.fileName)

        Task {
            await viewModel.load()
        }
    }

    func closeFile(_ fileViewModel: FileViewModel) {
        if let selectedItem = selectedSidebarItem,
           fileViewModel.containsItem(withId: selectedItem.id) {
            selectedSidebarItem = nil
        }
        openFiles.removeAll { $0.id == fileViewModel.id }
    }

    var activeFileViewModel: FileViewModel? {
        guard let item = selectedSidebarItem else { return nil }
        return fileViewModel(for: item)
    }

    func fileViewModel(for sidebarItem: SidebarItem) -> FileViewModel? {
        openFiles.first { $0.containsItem(withId: sidebarItem.id) }
    }

    func findTrack(for sidebarItem: SidebarItem) -> MKVTrack? {
        for file in openFiles {
            if let track = file.track(for: sidebarItem) {
                return track
            }
        }
        return nil
    }

    func findAttachment(for sidebarItem: SidebarItem) -> MKVAttachment? {
        for file in openFiles {
            if let attachment = file.attachment(for: sidebarItem) {
                return attachment
            }
        }
        return nil
    }

    func extractAttachment(filePath: String, attachmentId: Int) async throws -> String {
        try await service.extractAttachment(filePath: filePath, attachmentId: attachmentId)
    }

    func exportTrack(_ track: MKVTrack, sidebarItem: SidebarItem) {
        guard let fileVM = fileViewModel(for: sidebarItem) else { return }

        let suggestedName = CodecExtensionMap.suggestedFileName(
            for: track, sourceFileName: fileVM.fileName
        )

        let panel = NSSavePanel()
        panel.title = "Export Track"
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        jobsViewModel.exportTrack(
            track: track,
            filePath: fileVM.filePath,
            outputPath: url.path,
            displayName: track.displayName
        )
    }

    func removeTrack(_ track: MKVTrack, sidebarItem: SidebarItem) {
        guard let fileVM = fileViewModel(for: sidebarItem) else { return }
        fileVM.markTrackForRemoval(trackId: track.id)
    }

    func addTrack(to fileVM: FileViewModel, trackType: TrackType) {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select \(trackType.displayName) Track File"
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false

        guard openPanel.runModal() == .OK, let inputURL = openPanel.url else { return }

        let trackFile = TrackFileAddition(
            filePath: inputURL.path,
            language: nil,
            trackName: nil,
            defaultTrack: nil
        )

        fileVM.addTrackFile(trackFile)
    }

    func applyChanges(for fileVM: FileViewModel) {
        guard let identification = fileVM.identification else { return }

        let resolved = fileVM.resolvedChangeset

        let effectiveOutputPath: String
        switch outputMode {
        case .backup, .inline:
            // Write to a temp file, then swap in JobsViewModel
            let tempDir = FileManager.default.temporaryDirectory
                .appendingPathComponent("babushka-apply", isDirectory: true)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            effectiveOutputPath = tempDir.appendingPathComponent("\(UUID().uuidString).mkv").path
        case .specifyLocation:
            let suggestedName = fileVM.fileName.replacingOccurrences(of: ".mkv", with: "_modified.mkv")
            let panel = NSSavePanel()
            panel.title = "Save Modified File"
            panel.nameFieldStringValue = suggestedName
            panel.canCreateDirectories = true
            panel.allowedContentTypes = [.init(filenameExtension: "mkv")!]
            guard panel.runModal() == .OK, let url = panel.url else { return }
            effectiveOutputPath = url.path
        }

        jobsViewModel.applyChangeset(
            resolved: resolved,
            allTracks: identification.tracks,
            filePath: fileVM.filePath,
            outputPath: effectiveOutputPath,
            outputMode: outputMode,
            displayName: "Apply changes to \(fileVM.fileName)"
        ) { [weak fileVM] in
            await fileVM?.cancelAllChanges()
            await fileVM?.reload()
        }
    }

    func undoLastChange(for fileVM: FileViewModel) {
        fileVM.undoLastChange()
    }

    func redoLastChange(for fileVM: FileViewModel) {
        fileVM.redoLastChange()
    }

    func exportAttachment(_ attachment: MKVAttachment, sidebarItem: SidebarItem) {
        guard let fileVM = fileViewModel(for: sidebarItem) else { return }

        let panel = NSSavePanel()
        panel.title = "Export Attachment"
        panel.nameFieldStringValue = attachment.fileName ?? "attachment_\(attachment.id)"
        panel.canCreateDirectories = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        jobsViewModel.exportAttachment(
            attachment: attachment,
            filePath: fileVM.filePath,
            outputPath: url.path,
            displayName: attachment.displayName
        )
    }
}
