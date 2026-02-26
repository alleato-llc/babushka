import AppKit
import UniformTypeIdentifiers

@MainActor
struct FileDialogService {
    func openMKVFiles() -> [URL]? {
        let panel = NSOpenPanel()
        panel.title = "Open MKV File"
        panel.allowedContentTypes = [.init(filenameExtension: "mkv")!]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK else { return nil }
        return panel.urls
    }

    func saveFile(title: String, suggestedName: String, contentType: String? = nil) -> URL? {
        let panel = NSSavePanel()
        panel.title = title
        panel.nameFieldStringValue = suggestedName
        panel.canCreateDirectories = true
        if let contentType, let utType = UTType(filenameExtension: contentType) {
            panel.allowedContentTypes = [utType]
        }

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    func openFile(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}
