import SwiftUI

@main
struct BabushkaApp: App {
    @State private var appViewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView(appViewModel: appViewModel)
                .frame(minWidth: 800, minHeight: 500)
                .task {
                    await appViewModel.checkToolAvailability()
                }
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open MKV File...") {
                    appViewModel.openFile()
                }
                .keyboardShortcut("o", modifiers: .command)
            }

            CommandGroup(replacing: .undoRedo) {
                Button("Undo Change") {
                    if let fileVM = appViewModel.activeFileViewModel {
                        appViewModel.undoLastChange(for: fileVM)
                    }
                }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(appViewModel.activeFileViewModel?.canUndo != true)

                Button("Redo Change") {
                    if let fileVM = appViewModel.activeFileViewModel {
                        appViewModel.redoLastChange(for: fileVM)
                    }
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(appViewModel.activeFileViewModel?.canRedo != true)
            }
        }

        Settings {
            SettingsView(appViewModel: appViewModel)
        }

        Window("About Babushka", id: "about") {
            AboutView(toolInfo: appViewModel.toolInfo)
        }
        .windowResizability(.contentSize)
    }
}
