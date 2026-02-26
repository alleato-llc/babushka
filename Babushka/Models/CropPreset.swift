import Foundation

enum CropPreset: String, CaseIterable, Identifiable, Sendable {
    case none
    case widescreen16x9
    case anamorphic239
    case theatrical185
    case classic4x3
    case square1x1

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: "None"
        case .widescreen16x9: "16:9 (1.78:1)"
        case .anamorphic239: "2.39:1 Scope"
        case .theatrical185: "1.85:1 Flat"
        case .classic4x3: "4:3 (1.33:1)"
        case .square1x1: "1:1 Square"
        }
    }

    var aspectRatio: Double? {
        switch self {
        case .none: nil
        case .widescreen16x9: 16.0 / 9.0
        case .anamorphic239: 2.39
        case .theatrical185: 1.85
        case .classic4x3: 4.0 / 3.0
        case .square1x1: 1.0
        }
    }

    func cropValues(sourceWidth: Int, sourceHeight: Int) -> (top: Int, bottom: Int, left: Int, right: Int)? {
        guard let targetAR = aspectRatio else { return nil }
        guard sourceWidth > 0, sourceHeight > 0 else { return nil }

        let sourceAR = Double(sourceWidth) / Double(sourceHeight)

        if abs(sourceAR - targetAR) < 0.01 {
            return (top: 0, bottom: 0, left: 0, right: 0)
        }

        if sourceAR > targetAR {
            // Source is wider — crop sides
            let targetWidth = Double(sourceHeight) * targetAR
            let totalCrop = Double(sourceWidth) - targetWidth
            let cropPerSide = Int(round(totalCrop / 2.0))
            return (top: 0, bottom: 0, left: cropPerSide, right: cropPerSide)
        } else {
            // Source is taller — crop top/bottom
            let targetHeight = Double(sourceWidth) / targetAR
            let totalCrop = Double(sourceHeight) - targetHeight
            let cropPerSide = Int(round(totalCrop / 2.0))
            return (top: cropPerSide, bottom: cropPerSide, left: 0, right: 0)
        }
    }
}
