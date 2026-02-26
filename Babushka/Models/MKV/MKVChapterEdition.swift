import Foundation

struct ChapterDisplay: Sendable, Equatable, Identifiable {
    let id: UUID
    var string: String
    var language: String

    init(id: UUID = UUID(), string: String, language: String = "eng") {
        self.id = id
        self.string = string
        self.language = language
    }
}

struct MKVChapterAtom: Sendable, Equatable, Identifiable {
    let id: UUID
    var uid: UInt64?
    var timeStart: UInt64
    var timeEnd: UInt64?
    var isHidden: Bool
    var isEnabled: Bool
    var displays: [ChapterDisplay]

    init(
        id: UUID = UUID(), uid: UInt64? = nil,
        timeStart: UInt64, timeEnd: UInt64? = nil,
        isHidden: Bool = false, isEnabled: Bool = true,
        displays: [ChapterDisplay] = []
    ) {
        self.id = id
        self.uid = uid
        self.timeStart = timeStart
        self.timeEnd = timeEnd
        self.isHidden = isHidden
        self.isEnabled = isEnabled
        self.displays = displays
    }

    var formattedTimeStart: String {
        Self.formatNanoseconds(timeStart)
    }

    var formattedTimeEnd: String? {
        guard let timeEnd else { return nil }
        return Self.formatNanoseconds(timeEnd)
    }

    static func formatNanoseconds(_ ns: UInt64) -> String {
        let totalMillis = ns / 1_000_000
        let millis = totalMillis % 1000
        let totalSeconds = totalMillis / 1000
        let seconds = totalSeconds % 60
        let totalMinutes = totalSeconds / 60
        let minutes = totalMinutes % 60
        let hours = totalMinutes / 60
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, millis)
    }

    static func parseTimestamp(_ string: String) -> UInt64? {
        let parts = string.split(separator: ":")
        guard parts.count == 3 else { return nil }

        guard let hours = UInt64(parts[0]) else { return nil }
        guard let minutes = UInt64(parts[1]) else { return nil }

        let secParts = parts[2].split(separator: ".")
        guard !secParts.isEmpty, let seconds = UInt64(secParts[0]) else { return nil }

        var nanos: UInt64 = 0
        if secParts.count == 2 {
            let fracString = String(secParts[1])
            let padded = fracString.padding(toLength: 9, withPad: "0", startingAt: 0)
            guard let fracNanos = UInt64(padded) else { return nil }
            nanos = fracNanos
        }

        return (hours * 3600 + minutes * 60 + seconds) * 1_000_000_000 + nanos
    }
}

struct MKVChapterEdition: Sendable, Equatable, Identifiable {
    let id: UUID
    var uid: UInt64?
    var isDefault: Bool
    var isHidden: Bool
    var isOrdered: Bool
    var chapters: [MKVChapterAtom]

    init(
        id: UUID = UUID(), uid: UInt64? = nil,
        isDefault: Bool = false, isHidden: Bool = false, isOrdered: Bool = false,
        chapters: [MKVChapterAtom] = []
    ) {
        self.id = id
        self.uid = uid
        self.isDefault = isDefault
        self.isHidden = isHidden
        self.isOrdered = isOrdered
        self.chapters = chapters
    }
}
