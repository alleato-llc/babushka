import SwiftUI

struct ChapterEditorView: View {
    let fileViewModel: FileViewModel
    @Bindable var appViewModel: AppViewModel

    @State private var editions: [MKVChapterEdition] = []
    @State private var selectedEditionIndex = 0

    var body: some View {
        VStack(spacing: 0) {
            if editions.count > 1 {
                Picker("Edition", selection: $selectedEditionIndex) {
                    ForEach(Array(editions.indices), id: \.self) { index in
                        Text("Edition \(index + 1)").tag(index)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
            }

            editionToolbar

            if editions.indices.contains(selectedEditionIndex) {
                chapterListView
            }
        }
        .navigationTitle("Edit Chapters — \(fileViewModel.fileName)")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    appViewModel.editingChaptersFileId = nil
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Done") {
                    fileViewModel.editChapters(editions: editions)
                    appViewModel.editingChaptersFileId = nil
                }
            }
        }
        .onAppear {
            if let existing = fileViewModel.effectiveChapters, !existing.isEmpty {
                editions = existing
            } else {
                editions = [
                    MKVChapterEdition(
                        chapters: [
                            MKVChapterAtom(
                                timeStart: 0,
                                displays: [ChapterDisplay(string: "Chapter 1")]
                            ),
                        ]
                    ),
                ]
            }
        }
    }

    private var editionToolbar: some View {
        HStack {
            Button {
                editions.append(MKVChapterEdition())
                selectedEditionIndex = editions.count - 1
            } label: {
                Label("Add Edition", systemImage: "plus")
            }

            if editions.count > 1 {
                Button(role: .destructive) {
                    editions.remove(at: selectedEditionIndex)
                    selectedEditionIndex = min(selectedEditionIndex, editions.count - 1)
                } label: {
                    Label("Remove Edition", systemImage: "minus")
                }
            }

            Spacer()

            if editions.indices.contains(selectedEditionIndex) {
                editionFlagToggles
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var editionFlagToggles: some View {
        HStack(spacing: 12) {
            Toggle("Default", isOn: Binding(
                get: { editions[selectedEditionIndex].isDefault },
                set: { editions[selectedEditionIndex].isDefault = $0 }
            ))
            Toggle("Hidden", isOn: Binding(
                get: { editions[selectedEditionIndex].isHidden },
                set: { editions[selectedEditionIndex].isHidden = $0 }
            ))
            Toggle("Ordered", isOn: Binding(
                get: { editions[selectedEditionIndex].isOrdered },
                set: { editions[selectedEditionIndex].isOrdered = $0 }
            ))
        }
        .toggleStyle(.checkbox)
    }

    private var chapterListView: some View {
        List {
            ForEach(Array(editions[selectedEditionIndex].chapters.enumerated()), id: \.element.id) { index, _ in
                chapterRow(index: index)
            }
            .onDelete { offsets in
                editions[selectedEditionIndex].chapters.remove(atOffsets: offsets)
            }
            .onMove { source, destination in
                editions[selectedEditionIndex].chapters.move(fromOffsets: source, toOffset: destination)
            }

            Button {
                let lastTime = editions[selectedEditionIndex].chapters.last?.timeStart ?? 0
                editions[selectedEditionIndex].chapters.append(
                    MKVChapterAtom(
                        timeStart: lastTime,
                        displays: [ChapterDisplay(string: "")]
                    )
                )
            } label: {
                Label("Add Chapter", systemImage: "plus")
            }
            .buttonStyle(.borderless)
        }
        .listStyle(.plain)
    }

    @ViewBuilder
    private func chapterRow(index: Int) -> some View {
        HStack(spacing: 12) {
            TextField(
                "HH:MM:SS.mmm",
                text: Binding(
                    get: {
                        editions[selectedEditionIndex].chapters[index].formattedTimeStart
                    },
                    set: { newValue in
                        if let ns = MKVChapterAtom.parseTimestamp(newValue) {
                            editions[selectedEditionIndex].chapters[index].timeStart = ns
                        }
                    }
                )
            )
            .font(.body.monospaced())
            .frame(width: 140)

            TextField(
                "Chapter name",
                text: Binding(
                    get: {
                        editions[selectedEditionIndex].chapters[index].displays.first?.string ?? ""
                    },
                    set: { newValue in
                        if editions[selectedEditionIndex].chapters[index].displays.isEmpty {
                            editions[selectedEditionIndex].chapters[index].displays.append(
                                ChapterDisplay(string: newValue)
                            )
                        } else {
                            editions[selectedEditionIndex].chapters[index].displays[0].string = newValue
                        }
                    }
                )
            )

            TextField(
                "Language",
                text: Binding(
                    get: {
                        editions[selectedEditionIndex].chapters[index].displays.first?.language ?? "eng"
                    },
                    set: { newValue in
                        if editions[selectedEditionIndex].chapters[index].displays.isEmpty {
                            editions[selectedEditionIndex].chapters[index].displays.append(
                                ChapterDisplay(string: "", language: newValue)
                            )
                        } else {
                            editions[selectedEditionIndex].chapters[index].displays[0].language = newValue
                        }
                    }
                )
            )
            .frame(width: 60)
        }
    }
}
