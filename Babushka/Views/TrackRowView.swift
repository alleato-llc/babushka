import SwiftUI

struct TrackRowView: View {
    let track: MKVTrack

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: track.type.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(track.properties.trackName ?? track.codec)
                        .fontWeight(.medium)

                    if let lang = track.properties.language, lang != "und" {
                        Text(lang.uppercased())
                            .font(.caption)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }

                    if track.properties.flags.defaultTrack == true {
                        Text("Default")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }

                    if track.properties.flags.forcedTrack == true {
                        Text("Forced")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Text(trackDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Track \(track.id)")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 2)
    }

    private var trackDetail: String {
        var parts: [String] = [track.codec]

        switch track.type {
        case .video:
            if let dims = track.properties.video.pixelDimensions {
                parts.append(dims)
            }
            if let fps = track.properties.formattedDefaultDuration {
                parts.append(fps)
            }
        case .audio:
            if let channels = track.properties.audio.channelDescription {
                parts.append(channels)
            }
            if let freq = track.properties.audio.formattedSamplingFrequency {
                parts.append(freq)
            }
        case .subtitles:
            if let enc = track.properties.encoding {
                parts.append(enc)
            }
        case .unknown:
            break
        }

        return parts.joined(separator: " · ")
    }
}
