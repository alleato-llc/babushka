import SwiftUI

struct PendingChangesBar: View {
    let fileViewModel: FileViewModel
    @Bindable var appViewModel: AppViewModel

    var body: some View {
        HStack(spacing: 12) {
            Text("\(fileViewModel.changeset.operationCount) pending change\(fileViewModel.changeset.operationCount == 1 ? "" : "s")")
                .font(.callout)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Cancel") {
                fileViewModel.cancelAllChanges()
            }

            Button("Apply Changes") {
                appViewModel.applyChanges(for: fileViewModel)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }
}
