import SwiftUI

struct TrackDetailView: View {
    let track: MKVTrack
    let fileViewModel: FileViewModel

    @State private var trackName: String
    @State private var language: String
    @State private var defaultTrack: Bool
    @State private var forcedTrack: Bool
    @State private var enabledTrack: Bool
    @State private var originalTrack: Bool
    @State private var visualImpairedTrack: Bool
    @State private var commentaryTrack: Bool
    @State private var pixelCropTop: Int
    @State private var pixelCropBottom: Int
    @State private var pixelCropLeft: Int
    @State private var pixelCropRight: Int
    @State private var selectedCropPreset: CropPreset = .none

    init(track: MKVTrack, fileViewModel: FileViewModel) {
        self.track = track
        self.fileViewModel = fileViewModel
        self._trackName = State(initialValue: fileViewModel.effectiveTrackName(for: track))
        self._language = State(initialValue: fileViewModel.effectiveLanguage(for: track))
        self._defaultTrack = State(initialValue: fileViewModel.effectiveDefaultTrack(for: track))
        self._forcedTrack = State(initialValue: fileViewModel.effectiveForcedTrack(for: track))
        self._enabledTrack = State(initialValue: fileViewModel.effectiveEnabledTrack(for: track))
        self._originalTrack = State(initialValue: fileViewModel.effectiveOriginalTrack(for: track))
        self._visualImpairedTrack = State(initialValue: fileViewModel.effectiveVisualImpairedTrack(for: track))
        self._commentaryTrack = State(initialValue: fileViewModel.effectiveCommentaryTrack(for: track))
        self._pixelCropTop = State(initialValue: fileViewModel.effectivePixelCropTop(for: track))
        self._pixelCropBottom = State(initialValue: fileViewModel.effectivePixelCropBottom(for: track))
        self._pixelCropLeft = State(initialValue: fileViewModel.effectivePixelCropLeft(for: track))
        self._pixelCropRight = State(initialValue: fileViewModel.effectivePixelCropRight(for: track))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if fileViewModel.isTrackRemoved(track.id) {
                    removalBanner
                }
                generalSection
                typeSpecificSection
                flagsSection
                if !track.properties.tags.isEmpty {
                    tagsSection
                }
                technicalSection
            }
            .padding()
        }
        .navigationTitle("Track \(track.id) — \(track.codec)")
    }

    @ViewBuilder
    private var removalBanner: some View {
        HStack {
            Image(systemName: "trash")
                .foregroundStyle(.red)
            Text("This track is marked for removal")
                .foregroundStyle(.secondary)
            Spacer()
            Button("Restore") {
                // Undo until the removal is reversed - simple approach: just undo once
                // The user can use Cmd+Z for more granular undo
                fileViewModel.undoLastChange()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var generalSection: some View {
        PropertySection(title: "General") {
            PropertyRow(label: "Track ID", value: "\(track.id)")
            PropertyRow(label: "Type", value: track.type.displayName)
            PropertyRow(label: "Codec", value: track.codec)

            if let codecId = track.properties.codecId {
                PropertyRow(label: "Codec ID", value: codecId)
            }

            EditableTextRow(
                label: "Track Name",
                text: $trackName,
                isModified: fileViewModel.isPropertyModified(for: track.id, property: .trackName)
            )
            .onChange(of: trackName) {
                var edits = TrackPropertyEdits()
                edits.trackName = trackName
                fileViewModel.editTrackProperties(trackId: track.id, trackUid: track.properties.uid, edits: edits)
            }

            EditableTextRow(
                label: "Language",
                text: $language,
                isModified: fileViewModel.isPropertyModified(for: track.id, property: .language)
            )
            .onChange(of: language) {
                var edits = TrackPropertyEdits()
                edits.language = language
                fileViewModel.editTrackProperties(trackId: track.id, trackUid: track.properties.uid, edits: edits)
            }

            if let number = track.properties.number {
                PropertyRow(label: "Track Number", value: "\(number)")
            }

            if let uid = track.properties.uid {
                PropertyRow(label: "UID", value: "\(uid)")
            }
        }
    }

    @ViewBuilder
    private var typeSpecificSection: some View {
        switch track.type {
        case .video:
            PropertySection(title: "Video") {
                if let dims = track.properties.video.pixelDimensions {
                    PropertyRow(label: "Pixel Dimensions", value: dims)
                }
                if let display = track.properties.video.displayDimensions {
                    PropertyRow(label: "Display Dimensions", value: display)
                }
                if let unit = track.properties.video.displayUnit {
                    PropertyRow(label: "Display Unit", value: "\(unit)")
                }
                if let fps = track.properties.formattedDefaultDuration {
                    PropertyRow(label: "Frame Rate", value: fps)
                }
                if let packetizer = track.properties.video.packetizer {
                    PropertyRow(label: "Packetizer", value: packetizer)
                }
                if let stereo = track.properties.video.stereoMode {
                    PropertyRow(label: "Stereo Mode", value: "\(stereo)")
                }
            }

            pixelCropSection

        case .audio:
            PropertySection(title: "Audio") {
                if let channels = track.properties.audio.audioChannels {
                    PropertyRow(label: "Channels", value: track.properties.audio.channelDescription ?? "\(channels)")
                }
                if let freq = track.properties.audio.audioSamplingFrequency {
                    PropertyRow(label: "Sampling Frequency", value: track.properties.audio.formattedSamplingFrequency ?? "\(freq) Hz")
                }
                if let bits = track.properties.audio.audioBitsPerSample {
                    PropertyRow(label: "Bits Per Sample", value: "\(bits)")
                }
                if let fps = track.properties.formattedDefaultDuration {
                    PropertyRow(label: "Frame Rate", value: fps)
                }
            }

        case .subtitles:
            PropertySection(title: "Subtitles") {
                if let enc = track.properties.encoding {
                    PropertyRow(label: "Encoding", value: enc)
                }
                if let textSubs = track.properties.textSubtitles {
                    PropertyRow(label: "Text Subtitles", value: textSubs ? "Yes" : "No")
                }
            }

        case .unknown:
            EmptyView()
        }
    }

    @ViewBuilder
    private var flagsSection: some View {
        PropertySection(title: "Flags") {
            EditableToggleRow(
                label: "Enabled",
                isOn: $enabledTrack,
                isModified: fileViewModel.isPropertyModified(for: track.id, property: .enabledTrack)
            )
            .onChange(of: enabledTrack) {
                var edits = TrackPropertyEdits()
                edits.flags.enabledTrack = enabledTrack
                fileViewModel.editTrackProperties(trackId: track.id, trackUid: track.properties.uid, edits: edits)
            }

            EditableToggleRow(
                label: "Default",
                isOn: $defaultTrack,
                isModified: fileViewModel.isPropertyModified(for: track.id, property: .defaultTrack)
            )
            .onChange(of: defaultTrack) {
                var edits = TrackPropertyEdits()
                edits.flags.defaultTrack = defaultTrack
                fileViewModel.editTrackProperties(trackId: track.id, trackUid: track.properties.uid, edits: edits)
            }

            EditableToggleRow(
                label: "Forced",
                isOn: $forcedTrack,
                isModified: fileViewModel.isPropertyModified(for: track.id, property: .forcedTrack)
            )
            .onChange(of: forcedTrack) {
                var edits = TrackPropertyEdits()
                edits.flags.forcedTrack = forcedTrack
                fileViewModel.editTrackProperties(trackId: track.id, trackUid: track.properties.uid, edits: edits)
            }

            EditableToggleRow(
                label: "Original",
                isOn: $originalTrack,
                isModified: fileViewModel.isPropertyModified(for: track.id, property: .originalTrack)
            )
            .onChange(of: originalTrack) {
                var edits = TrackPropertyEdits()
                edits.flags.originalTrack = originalTrack
                fileViewModel.editTrackProperties(trackId: track.id, trackUid: track.properties.uid, edits: edits)
            }

            EditableToggleRow(
                label: "Visual Impaired",
                isOn: $visualImpairedTrack,
                isModified: fileViewModel.isPropertyModified(for: track.id, property: .visualImpairedTrack)
            )
            .onChange(of: visualImpairedTrack) {
                var edits = TrackPropertyEdits()
                edits.flags.visualImpairedTrack = visualImpairedTrack
                fileViewModel.editTrackProperties(trackId: track.id, trackUid: track.properties.uid, edits: edits)
            }

            EditableToggleRow(
                label: "Commentary",
                isOn: $commentaryTrack,
                isModified: fileViewModel.isPropertyModified(for: track.id, property: .commentaryTrack)
            )
            .onChange(of: commentaryTrack) {
                var edits = TrackPropertyEdits()
                edits.flags.commentaryTrack = commentaryTrack
                fileViewModel.editTrackProperties(trackId: track.id, trackUid: track.properties.uid, edits: edits)
            }
        }
    }

    @ViewBuilder
    private var tagsSection: some View {
        PropertySection(title: "Tags") {
            ForEach(track.properties.tags.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                PropertyRow(label: key.replacingOccurrences(of: "tag_", with: ""), value: value)
            }
        }
    }

    @ViewBuilder
    private var technicalSection: some View {
        PropertySection(title: "Technical") {
            if let privLen = track.properties.codecPrivateLength {
                PropertyRow(label: "Codec Private Length", value: "\(privLen) bytes")
            }
            if let minTs = track.properties.minimumTimestamp {
                PropertyRow(label: "Minimum Timestamp", value: formatTimestamp(minTs))
            }
            if let entries = track.properties.numIndexEntries {
                PropertyRow(label: "Index Entries", value: "\(entries)")
            }
            if let defDur = track.properties.defaultDuration {
                PropertyRow(label: "Default Duration", value: "\(defDur) ns")
            }
        }
    }

    @ViewBuilder
    private var pixelCropSection: some View {
        PropertySection(title: "Pixel Crop") {
            GridRow {
                Text("Preset")
                    .foregroundStyle(.secondary)
                    .gridColumnAlignment(.trailing)
                Picker("Preset", selection: $selectedCropPreset) {
                    ForEach(CropPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 200)
                .gridColumnAlignment(.leading)
            }
            .onChange(of: selectedCropPreset) {
                guard let w = track.properties.video.pixelWidth,
                      let h = track.properties.video.pixelHeight,
                      let crop = selectedCropPreset.cropValues(sourceWidth: w, sourceHeight: h)
                else { return }
                pixelCropTop = crop.top
                pixelCropBottom = crop.bottom
                pixelCropLeft = crop.left
                pixelCropRight = crop.right
                applyCropEdits()
            }

            EditableIntRow(
                label: "Top",
                value: $pixelCropTop,
                isModified: fileViewModel.isPropertyModified(for: track.id, property: .pixelCropTop)
            )
            .onChange(of: pixelCropTop) {
                selectedCropPreset = .none
                applyCropEdits()
            }

            EditableIntRow(
                label: "Bottom",
                value: $pixelCropBottom,
                isModified: fileViewModel.isPropertyModified(for: track.id, property: .pixelCropBottom)
            )
            .onChange(of: pixelCropBottom) {
                selectedCropPreset = .none
                applyCropEdits()
            }

            EditableIntRow(
                label: "Left",
                value: $pixelCropLeft,
                isModified: fileViewModel.isPropertyModified(for: track.id, property: .pixelCropLeft)
            )
            .onChange(of: pixelCropLeft) {
                selectedCropPreset = .none
                applyCropEdits()
            }

            EditableIntRow(
                label: "Right",
                value: $pixelCropRight,
                isModified: fileViewModel.isPropertyModified(for: track.id, property: .pixelCropRight)
            )
            .onChange(of: pixelCropRight) {
                selectedCropPreset = .none
                applyCropEdits()
            }
        }
    }

    private func applyCropEdits() {
        var edits = TrackPropertyEdits()
        edits.crop.pixelCropTop = pixelCropTop
        edits.crop.pixelCropBottom = pixelCropBottom
        edits.crop.pixelCropLeft = pixelCropLeft
        edits.crop.pixelCropRight = pixelCropRight
        fileViewModel.editTrackProperties(trackId: track.id, trackUid: track.properties.uid, edits: edits)
    }

    private func formatTimestamp(_ ns: Int) -> String {
        let totalMs = ns / 1_000_000
        let seconds = totalMs / 1000
        let ms = totalMs % 1000
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d.%03d", minutes, secs, ms)
    }
}

struct PropertySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        GroupBox(title) {
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct EditableToggleRow: View {
    let label: String
    @Binding var isOn: Bool
    var isModified: Bool = false

    var body: some View {
        GridRow {
            HStack(spacing: 4) {
                if isModified {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                }
                Text(label)
                    .foregroundStyle(.secondary)
            }
            .gridColumnAlignment(.trailing)
            Toggle(isOn: $isOn) {
                EmptyView()
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .gridColumnAlignment(.leading)
        }
    }
}

struct EditableTextRow: View {
    let label: String
    @Binding var text: String
    var isModified: Bool = false

    var body: some View {
        GridRow {
            HStack(spacing: 4) {
                if isModified {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                }
                Text(label)
                    .foregroundStyle(.secondary)
            }
            .gridColumnAlignment(.trailing)
            TextField(label, text: $text)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 300)
                .gridColumnAlignment(.leading)
        }
    }
}

struct EditableIntRow: View {
    let label: String
    @Binding var value: Int
    var isModified: Bool = false

    var body: some View {
        GridRow {
            HStack(spacing: 4) {
                if isModified {
                    Circle()
                        .fill(.orange)
                        .frame(width: 6, height: 6)
                }
                Text(label)
                    .foregroundStyle(.secondary)
            }
            .gridColumnAlignment(.trailing)
            TextField(label, value: $value, format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 100)
                .gridColumnAlignment(.leading)
        }
    }
}
