import Foundation
import Testing
@testable import Babushka

@Suite("CropPreset Calculations")
struct CropPresetTests {

    @Test("2.39:1 scope on 1920x1080 crops vertically")
    func anamorphicScope() {
        let crop = CropPreset.anamorphic239.cropValues(sourceWidth: 1920, sourceHeight: 1080)
        #expect(crop != nil)
        let c = crop!
        // Target height = 1920 / 2.39 ≈ 803.3, total vertical crop ≈ 276.7
        // Each side ≈ 138
        #expect(c.top >= 138 && c.top <= 139)
        #expect(c.bottom >= 138 && c.bottom <= 139)
        #expect(c.left == 0)
        #expect(c.right == 0)
        // Symmetric within 1px
        #expect(abs(c.top - c.bottom) <= 1)
    }

    @Test("4:3 on 1920x1080 crops horizontally")
    func classic4x3() {
        let crop = CropPreset.classic4x3.cropValues(sourceWidth: 1920, sourceHeight: 1080)
        #expect(crop != nil)
        let c = crop!
        // Target width = 1080 * (4/3) = 1440, total horizontal crop = 480
        // Each side = 240
        #expect(c.top == 0)
        #expect(c.bottom == 0)
        #expect(c.left == 240)
        #expect(c.right == 240)
    }

    @Test("16:9 on 1920x1080 produces no crop (already matching)")
    func widescreen16x9NoCrop() {
        let crop = CropPreset.widescreen16x9.cropValues(sourceWidth: 1920, sourceHeight: 1080)
        #expect(crop != nil)
        let c = crop!
        #expect(c.top == 0)
        #expect(c.bottom == 0)
        #expect(c.left == 0)
        #expect(c.right == 0)
    }

    @Test("None preset returns nil")
    func nonePresetReturnsNil() {
        let crop = CropPreset.none.cropValues(sourceWidth: 1920, sourceHeight: 1080)
        #expect(crop == nil)
    }

    @Test("1:1 on 1920x1080 crops horizontally")
    func square1x1() {
        let crop = CropPreset.square1x1.cropValues(sourceWidth: 1920, sourceHeight: 1080)
        #expect(crop != nil)
        let c = crop!
        // Target width = 1080 * 1.0 = 1080, total horizontal crop = 840
        // Each side = 420
        #expect(c.top == 0)
        #expect(c.bottom == 0)
        #expect(c.left == 420)
        #expect(c.right == 420)
    }
}
