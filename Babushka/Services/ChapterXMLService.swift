import Foundation

enum ChapterXMLError: Error, Sendable {
    case invalidRootElement
    case missingRequiredElement(String)
    case invalidTimestamp(String)
}

struct ChapterXMLService: Sendable {

    func parse(xmlString: String) throws -> [MKVChapterEdition] {
        let doc = try XMLDocument(xmlString: xmlString)

        guard let root = doc.rootElement(), root.name == "Chapters" else {
            throw ChapterXMLError.invalidRootElement
        }

        var editions: [MKVChapterEdition] = []

        for editionNode in root.elements(forName: "EditionEntry") {
            let editionUID = editionNode.elements(forName: "EditionUID").first?.stringValue
                .flatMap { UInt64($0) }
            let isDefault = editionNode.elements(forName: "EditionFlagDefault").first?.stringValue == "1"
            let isHidden = editionNode.elements(forName: "EditionFlagHidden").first?.stringValue == "1"
            let isOrdered = editionNode.elements(forName: "EditionFlagOrdered").first?.stringValue == "1"

            var chapters: [MKVChapterAtom] = []

            for atomNode in editionNode.elements(forName: "ChapterAtom") {
                // Skip nested ChapterAtom (only flat)
                let chapterUID = atomNode.elements(forName: "ChapterUID").first?.stringValue
                    .flatMap { UInt64($0) }

                guard let timeStartStr = atomNode.elements(forName: "ChapterTimeStart").first?.stringValue else {
                    throw ChapterXMLError.missingRequiredElement("ChapterTimeStart")
                }
                guard let timeStart = MKVChapterAtom.parseTimestamp(timeStartStr) else {
                    throw ChapterXMLError.invalidTimestamp(timeStartStr)
                }

                let timeEnd: UInt64?
                if let timeEndStr = atomNode.elements(forName: "ChapterTimeEnd").first?.stringValue {
                    guard let parsed = MKVChapterAtom.parseTimestamp(timeEndStr) else {
                        throw ChapterXMLError.invalidTimestamp(timeEndStr)
                    }
                    timeEnd = parsed
                } else {
                    timeEnd = nil
                }

                let isHiddenAtom = atomNode.elements(forName: "ChapterFlagHidden").first?.stringValue == "1"
                let isEnabledAtom = atomNode.elements(forName: "ChapterFlagEnabled").first?.stringValue != "0"

                var displays: [ChapterDisplay] = []
                for displayNode in atomNode.elements(forName: "ChapterDisplay") {
                    let string = displayNode.elements(forName: "ChapterString").first?.stringValue ?? ""
                    let language = displayNode.elements(forName: "ChapterLanguage").first?.stringValue ?? "eng"
                    displays.append(ChapterDisplay(string: string, language: language))
                }

                chapters.append(MKVChapterAtom(
                    uid: chapterUID,
                    timeStart: timeStart,
                    timeEnd: timeEnd,
                    isHidden: isHiddenAtom,
                    isEnabled: isEnabledAtom,
                    displays: displays
                ))
            }

            editions.append(MKVChapterEdition(
                uid: editionUID,
                isDefault: isDefault,
                isHidden: isHidden,
                isOrdered: isOrdered,
                chapters: chapters
            ))
        }

        return editions
    }

    func generate(editions: [MKVChapterEdition]) -> String {
        let root = XMLElement(name: "Chapters")
        let doc = XMLDocument(rootElement: root)
        doc.version = "1.0"

        for edition in editions {
            let editionEl = XMLElement(name: "EditionEntry")

            if let uid = edition.uid {
                editionEl.addChild(xmlElement("EditionUID", value: "\(uid)"))
            }
            editionEl.addChild(xmlElement("EditionFlagDefault", value: edition.isDefault ? "1" : "0"))
            editionEl.addChild(xmlElement("EditionFlagHidden", value: edition.isHidden ? "1" : "0"))
            editionEl.addChild(xmlElement("EditionFlagOrdered", value: edition.isOrdered ? "1" : "0"))

            for chapter in edition.chapters {
                let atomEl = XMLElement(name: "ChapterAtom")

                if let uid = chapter.uid {
                    atomEl.addChild(xmlElement("ChapterUID", value: "\(uid)"))
                }

                atomEl.addChild(xmlElement("ChapterTimeStart", value: formatNanoseconds9(chapter.timeStart)))

                if let timeEnd = chapter.timeEnd {
                    atomEl.addChild(xmlElement("ChapterTimeEnd", value: formatNanoseconds9(timeEnd)))
                }

                atomEl.addChild(xmlElement("ChapterFlagHidden", value: chapter.isHidden ? "1" : "0"))
                atomEl.addChild(xmlElement("ChapterFlagEnabled", value: chapter.isEnabled ? "1" : "0"))

                for display in chapter.displays {
                    let displayEl = XMLElement(name: "ChapterDisplay")
                    displayEl.addChild(xmlElement("ChapterString", value: display.string))
                    displayEl.addChild(xmlElement("ChapterLanguage", value: display.language))
                    atomEl.addChild(displayEl)
                }

                editionEl.addChild(atomEl)
            }

            root.addChild(editionEl)
        }

        return doc.xmlString(options: [.nodePrettyPrint])
    }

    private func xmlElement(_ name: String, value: String) -> XMLElement {
        let el = XMLElement(name: name, stringValue: value)
        return el
    }

    private func formatNanoseconds9(_ ns: UInt64) -> String {
        let totalNanos = ns
        let nanosPart = totalNanos % 1_000_000_000
        let totalSeconds = totalNanos / 1_000_000_000
        let seconds = totalSeconds % 60
        let totalMinutes = totalSeconds / 60
        let minutes = totalMinutes % 60
        let hours = totalMinutes / 60
        return String(format: "%02d:%02d:%02d.%09d", hours, minutes, seconds, nanosPart)
    }
}
