import Foundation
import Testing
@testable import Babushka

@Suite("MKVToolnixLocator")
struct MKVToolnixLocatorTests {

    @Test("Locates mkvmerge on this system")
    func locateMkvmerge() async throws {
        let locator = MKVToolnixLocator()
        let info = await locator.locate()

        #expect(info != nil, "mkvmerge should be installed on this system")
        #expect(info?.path.hasSuffix("mkvmerge") == true)
        #expect(info?.version.hasPrefix("v") == true)
    }

    @Test("Parses version string correctly")
    func parseVersionString() async {
        let locator = MKVToolnixLocator()

        let v1 = await locator.parseVersionString("mkvmerge v97.0 ('You Don't Have A Clue') 64-bit")
        #expect(v1 == "v97.0")

        let v2 = await locator.parseVersionString("mkvmerge v85.0.1 ('Thinking Out Loud') 64-bit")
        #expect(v2 == "v85.0.1")

        let invalid = await locator.parseVersionString("not a version string")
        #expect(invalid == nil)
    }
}
