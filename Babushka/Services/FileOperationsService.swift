import Foundation

struct FileOperationsService: Sendable {
    func backupAndReplace(originalPath: String, newFilePath: String) throws {
        let backupPath = originalPath + ".bak"
        let fm = FileManager.default
        if fm.fileExists(atPath: backupPath) {
            try fm.removeItem(atPath: backupPath)
        }
        try fm.moveItem(atPath: originalPath, toPath: backupPath)
        try fm.moveItem(atPath: newFilePath, toPath: originalPath)
    }

    func replaceInline(originalPath: String, newFilePath: String) throws {
        let fm = FileManager.default
        try fm.removeItem(atPath: originalPath)
        try fm.moveItem(atPath: newFilePath, toPath: originalPath)
    }
}
