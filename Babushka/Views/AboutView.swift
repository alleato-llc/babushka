import SwiftUI

struct AboutView: View {
    let toolInfo: MKVToolnixInfo?

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "film.stack")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Babushka")
                .font(.title)
                .fontWeight(.bold)

            Text("MKV File Inspector")
                .foregroundStyle(.secondary)

            Divider()

            GroupBox("mkvtoolnix Status") {
                Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                    GridRow {
                        Text("Status")
                            .foregroundStyle(.secondary)
                        HStack(spacing: 4) {
                            Image(systemName: toolInfo != nil ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(toolInfo != nil ? .green : .red)
                            Text(toolInfo != nil ? "Available" : "Not Found")
                        }
                    }

                    if let info = toolInfo {
                        GridRow {
                            Text("Version")
                                .foregroundStyle(.secondary)
                            Text(info.version)
                        }
                        GridRow {
                            Text("Path")
                                .foregroundStyle(.secondary)
                            Text(info.path)
                                .textSelection(.enabled)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            VStack(spacing: 4) {
                Text("MIT License")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\u{00A9} Alleato L.L.C")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(30)
        .frame(width: 360)
    }
}
