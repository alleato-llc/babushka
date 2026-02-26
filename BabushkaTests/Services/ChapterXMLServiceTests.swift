import Foundation
import Testing
@testable import Babushka

@Suite("ChapterXMLService Tests")
struct ChapterXMLServiceTests {

    let service = ChapterXMLService()

    @Test("Parse single edition with chapters")
    func parseSingleEdition() throws {
        let xml = """
        <?xml version="1.0"?>
        <Chapters>
          <EditionEntry>
            <EditionUID>123</EditionUID>
            <EditionFlagDefault>1</EditionFlagDefault>
            <EditionFlagHidden>0</EditionFlagHidden>
            <EditionFlagOrdered>0</EditionFlagOrdered>
            <ChapterAtom>
              <ChapterUID>1001</ChapterUID>
              <ChapterTimeStart>00:00:00.000000000</ChapterTimeStart>
              <ChapterTimeEnd>00:05:00.000000000</ChapterTimeEnd>
              <ChapterFlagHidden>0</ChapterFlagHidden>
              <ChapterFlagEnabled>1</ChapterFlagEnabled>
              <ChapterDisplay>
                <ChapterString>Introduction</ChapterString>
                <ChapterLanguage>eng</ChapterLanguage>
              </ChapterDisplay>
            </ChapterAtom>
            <ChapterAtom>
              <ChapterUID>1002</ChapterUID>
              <ChapterTimeStart>00:05:00.000000000</ChapterTimeStart>
              <ChapterDisplay>
                <ChapterString>Main Content</ChapterString>
                <ChapterLanguage>eng</ChapterLanguage>
              </ChapterDisplay>
            </ChapterAtom>
          </EditionEntry>
        </Chapters>
        """

        let editions = try service.parse(xmlString: xml)
        #expect(editions.count == 1)
        #expect(editions[0].uid == 123)
        #expect(editions[0].isDefault == true)
        #expect(editions[0].chapters.count == 2)
        #expect(editions[0].chapters[0].uid == 1001)
        #expect(editions[0].chapters[0].timeStart == 0)
        #expect(editions[0].chapters[0].timeEnd == 300_000_000_000)
        #expect(editions[0].chapters[0].displays[0].string == "Introduction")
        #expect(editions[0].chapters[1].timeStart == 300_000_000_000)
        #expect(editions[0].chapters[1].timeEnd == nil)
    }

    @Test("Parse multiple editions")
    func parseMultipleEditions() throws {
        let xml = """
        <?xml version="1.0"?>
        <Chapters>
          <EditionEntry>
            <EditionFlagDefault>1</EditionFlagDefault>
            <EditionFlagHidden>0</EditionFlagHidden>
            <EditionFlagOrdered>0</EditionFlagOrdered>
            <ChapterAtom>
              <ChapterTimeStart>00:00:00.000000000</ChapterTimeStart>
              <ChapterDisplay>
                <ChapterString>Chapter 1</ChapterString>
                <ChapterLanguage>eng</ChapterLanguage>
              </ChapterDisplay>
            </ChapterAtom>
          </EditionEntry>
          <EditionEntry>
            <EditionFlagDefault>0</EditionFlagDefault>
            <EditionFlagHidden>1</EditionFlagHidden>
            <EditionFlagOrdered>1</EditionFlagOrdered>
            <ChapterAtom>
              <ChapterTimeStart>00:00:00.000000000</ChapterTimeStart>
              <ChapterDisplay>
                <ChapterString>Alt Chapter 1</ChapterString>
                <ChapterLanguage>jpn</ChapterLanguage>
              </ChapterDisplay>
            </ChapterAtom>
          </EditionEntry>
        </Chapters>
        """

        let editions = try service.parse(xmlString: xml)
        #expect(editions.count == 2)
        #expect(editions[0].isDefault == true)
        #expect(editions[1].isHidden == true)
        #expect(editions[1].isOrdered == true)
        #expect(editions[1].chapters[0].displays[0].language == "jpn")
    }

    @Test("Round-trip: generate then parse produces equivalent result")
    func roundTrip() throws {
        let editions = [
            MKVChapterEdition(
                uid: 456,
                isDefault: true,
                isHidden: false,
                isOrdered: false,
                chapters: [
                    MKVChapterAtom(
                        uid: 2001,
                        timeStart: 0,
                        timeEnd: 60_000_000_000,
                        isHidden: false,
                        isEnabled: true,
                        displays: [
                            ChapterDisplay(string: "Intro", language: "eng"),
                            ChapterDisplay(string: "Einleitung", language: "ger"),
                        ]
                    ),
                    MKVChapterAtom(
                        uid: 2002,
                        timeStart: 60_000_000_000,
                        isHidden: true,
                        isEnabled: false,
                        displays: [
                            ChapterDisplay(string: "Credits", language: "eng")
                        ]
                    ),
                ]
            ),
        ]

        let xml = service.generate(editions: editions)
        let parsed = try service.parse(xmlString: xml)

        #expect(parsed.count == 1)
        #expect(parsed[0].uid == 456)
        #expect(parsed[0].isDefault == true)
        #expect(parsed[0].chapters.count == 2)
        #expect(parsed[0].chapters[0].uid == 2001)
        #expect(parsed[0].chapters[0].timeStart == 0)
        #expect(parsed[0].chapters[0].timeEnd == 60_000_000_000)
        #expect(parsed[0].chapters[0].displays.count == 2)
        #expect(parsed[0].chapters[0].displays[0].string == "Intro")
        #expect(parsed[0].chapters[0].displays[1].language == "ger")
        #expect(parsed[0].chapters[1].isHidden == true)
        #expect(parsed[0].chapters[1].isEnabled == false)
    }

    @Test("Parse variable-precision timestamps")
    func parseVariablePrecisionTimestamps() throws {
        let xml = """
        <?xml version="1.0"?>
        <Chapters>
          <EditionEntry>
            <EditionFlagDefault>0</EditionFlagDefault>
            <EditionFlagHidden>0</EditionFlagHidden>
            <EditionFlagOrdered>0</EditionFlagOrdered>
            <ChapterAtom>
              <ChapterTimeStart>00:01:30.500</ChapterTimeStart>
              <ChapterDisplay>
                <ChapterString>A</ChapterString>
                <ChapterLanguage>eng</ChapterLanguage>
              </ChapterDisplay>
            </ChapterAtom>
            <ChapterAtom>
              <ChapterTimeStart>01:00:00.000000000</ChapterTimeStart>
              <ChapterDisplay>
                <ChapterString>B</ChapterString>
                <ChapterLanguage>eng</ChapterLanguage>
              </ChapterDisplay>
            </ChapterAtom>
          </EditionEntry>
        </Chapters>
        """

        let editions = try service.parse(xmlString: xml)
        // 00:01:30.500 = 90.5 seconds = 90_500_000_000 ns
        #expect(editions[0].chapters[0].timeStart == 90_500_000_000)
        // 01:00:00.000000000 = 3600 seconds
        #expect(editions[0].chapters[1].timeStart == 3_600_000_000_000)
    }

    @Test("Handle missing optional fields")
    func handleMissingOptionalFields() throws {
        let xml = """
        <?xml version="1.0"?>
        <Chapters>
          <EditionEntry>
            <ChapterAtom>
              <ChapterTimeStart>00:00:00.000000000</ChapterTimeStart>
              <ChapterDisplay>
                <ChapterString>Test</ChapterString>
              </ChapterDisplay>
            </ChapterAtom>
          </EditionEntry>
        </Chapters>
        """

        let editions = try service.parse(xmlString: xml)
        #expect(editions.count == 1)
        #expect(editions[0].uid == nil)
        #expect(editions[0].isDefault == false)
        #expect(editions[0].chapters[0].uid == nil)
        #expect(editions[0].chapters[0].timeEnd == nil)
        #expect(editions[0].chapters[0].isHidden == false)
        #expect(editions[0].chapters[0].isEnabled == true)
        #expect(editions[0].chapters[0].displays[0].language == "eng")
    }

    @Test("Generate produces valid XML with all fields")
    func generateProducesValidXML() throws {
        let editions = [
            MKVChapterEdition(
                uid: 789,
                isDefault: false,
                isHidden: true,
                isOrdered: true,
                chapters: [
                    MKVChapterAtom(
                        uid: 3001,
                        timeStart: 1_500_000_000,
                        timeEnd: 3_000_000_000,
                        isHidden: true,
                        isEnabled: false,
                        displays: [
                            ChapterDisplay(string: "Hidden Chapter", language: "fra")
                        ]
                    ),
                ]
            ),
        ]

        let xml = service.generate(editions: editions)

        #expect(xml.contains("<Chapters>"))
        #expect(xml.contains("<EditionUID>789</EditionUID>"))
        #expect(xml.contains("<EditionFlagHidden>1</EditionFlagHidden>"))
        #expect(xml.contains("<EditionFlagOrdered>1</EditionFlagOrdered>"))
        #expect(xml.contains("<ChapterUID>3001</ChapterUID>"))
        #expect(xml.contains("<ChapterTimeStart>00:00:01.500000000</ChapterTimeStart>"))
        #expect(xml.contains("<ChapterTimeEnd>00:00:03.000000000</ChapterTimeEnd>"))
        #expect(xml.contains("<ChapterFlagHidden>1</ChapterFlagHidden>"))
        #expect(xml.contains("<ChapterFlagEnabled>0</ChapterFlagEnabled>"))
        #expect(xml.contains("<ChapterString>Hidden Chapter</ChapterString>"))
        #expect(xml.contains("<ChapterLanguage>fra</ChapterLanguage>"))

        // Verify it's valid XML by re-parsing
        let parsed = try service.parse(xmlString: xml)
        #expect(parsed.count == 1)
    }
}
