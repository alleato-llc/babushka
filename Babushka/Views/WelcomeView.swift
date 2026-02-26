import SwiftUI

struct WelcomeView: View {
    let onOpenFile: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("Babushka")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("MKV File Inspector")
                .font(.title3)
                .foregroundStyle(.secondary)

            Button("Open MKV File...") {
                onOpenFile()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut("o", modifiers: .command)

            Text("or drag and drop .mkv files here")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
