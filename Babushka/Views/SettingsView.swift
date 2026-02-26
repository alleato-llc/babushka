import SwiftUI

struct SettingsView: View {
    @Bindable var appViewModel: AppViewModel

    var body: some View {
        Form {
            Picker("Output Mode", selection: Binding(
                get: { appViewModel.outputMode },
                set: { appViewModel.outputMode = $0 }
            )) {
                ForEach(OutputMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 350)
    }
}
