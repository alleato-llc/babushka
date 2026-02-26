import Foundation

struct MKVToolnixInfo: Sendable {
    let path: String
    let version: String

    var mkvpropeditPath: String {
        (path as NSString).deletingLastPathComponent.appending("/mkvpropedit")
    }

    var mkvextractPath: String {
        (path as NSString).deletingLastPathComponent.appending("/mkvextract")
    }
}

actor MKVToolnixLocator {
    private static let searchPaths = [
        "/opt/homebrew/bin/mkvmerge",
        "/usr/local/bin/mkvmerge",
    ]

    func locate() async -> MKVToolnixInfo? {
        // Check known paths first
        for path in Self.searchPaths {
            if let info = await validate(path: path) {
                return info
            }
        }

        // Fallback to `which`
        if let whichPath = await findViaWhich() {
            return await validate(path: whichPath)
        }

        return nil
    }

    private func validate(path: String) async -> MKVToolnixInfo? {
        let fileManager = FileManager.default
        guard fileManager.isExecutableFile(atPath: path) else { return nil }

        guard let version = await parseVersion(at: path) else { return nil }
        return MKVToolnixInfo(path: path, version: version)
    }

    private func parseVersion(at path: String) async -> String? {
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = ["--version"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else { return nil }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }

            // Parse "mkvmerge v97.0 ('You Don't Have A Clue') 64-bit"
            return parseVersionString(output)
        } catch {
            return nil
        }
    }

    func parseVersionString(_ output: String) -> String? {
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        // Match "mkvmerge v<version>"
        guard let range = trimmed.range(of: #"v[\d]+\.[\d]+\.?[\d]*"#, options: .regularExpression) else {
            return nil
        }
        return String(trimmed[range])
    }

    private func findViaWhich() async -> String? {
        do {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            process.arguments = ["mkvmerge"]

            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else { return nil }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !path.isEmpty else { return nil }

            return path
        } catch {
            return nil
        }
    }
}
