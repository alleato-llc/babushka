import SwiftUI

struct ChapterDetailView: View {
    let fileViewModel: FileViewModel

    var body: some View {
        Group {
            if fileViewModel.isLoadingChapters {
                ProgressView("Loading chapters...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = fileViewModel.chapterLoadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.red)
                    Text("Error Loading Chapters")
                        .font(.headline)
                    Text(error)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let editions = fileViewModel.effectiveChapters, !editions.isEmpty {
                chapterList(editions: editions)
            } else {
                Text("No chapters found")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Chapters — \(fileViewModel.fileName)")
        .task {
            await fileViewModel.loadChapters()
        }
    }

    @ViewBuilder
    private func chapterList(editions: [MKVChapterEdition]) -> some View {
        if editions.count == 1 {
            editionContent(edition: editions[0], index: 0)
        } else {
            TabView {
                ForEach(Array(editions.enumerated()), id: \.element.id) { index, edition in
                    editionContent(edition: edition, index: index)
                        .tabItem {
                            Text("Edition \(index + 1)")
                        }
                }
            }
        }
    }

    @ViewBuilder
    private func editionContent(edition: MKVChapterEdition, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            editionFlags(edition)
                .padding(.horizontal)
                .padding(.top, 8)

            Table(edition.chapters) {
                TableColumn("#") { chapter in
                    let idx = (edition.chapters.firstIndex(where: { $0.id == chapter.id }) ?? 0) + 1
                    Text("\(idx)")
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .width(min: 30, ideal: 40, max: 50)

                TableColumn("Start") { chapter in
                    Text(chapter.formattedTimeStart)
                        .font(.body.monospaced())
                }
                .width(min: 100, ideal: 130)

                TableColumn("End") { chapter in
                    Text(chapter.formattedTimeEnd ?? "—")
                        .font(.body.monospaced())
                }
                .width(min: 100, ideal: 130)

                TableColumn("Name") { chapter in
                    Text(chapter.displays.first?.string ?? "—")
                }

                TableColumn("Language") { chapter in
                    Text(chapter.displays.first?.language ?? "—")
                        .foregroundStyle(.secondary)
                }
                .width(min: 60, ideal: 80, max: 120)
            }
        }
    }

    @ViewBuilder
    private func editionFlags(_ edition: MKVChapterEdition) -> some View {
        HStack(spacing: 8) {
            if edition.isDefault {
                Text("Default")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            if edition.isHidden {
                Text("Hidden")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            if edition.isOrdered {
                Text("Ordered")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.green.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
    }
}
