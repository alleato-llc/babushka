import SwiftUI
import AppKit

struct AttachmentDetailView: View {
    let attachment: MKVAttachment
    let filePath: String
    let appViewModel: AppViewModel

    @State private var previewImage: NSImage?
    @State private var isExtracting = false

    private var isImageAttachment: Bool {
        attachment.contentType?.hasPrefix("image/") == true
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if isImageAttachment {
                    HStack(alignment: .top, spacing: 20) {
                        imagePreview
                        propertySection
                    }
                } else {
                    propertySection
                }
            }
            .padding()
        }
        .navigationTitle(attachment.displayName)
        .task(id: attachment.id) {
            guard isImageAttachment else { return }
            await loadPreview()
        }
    }

    @ViewBuilder
    private var imagePreview: some View {
        Group {
            if isExtracting {
                ProgressView()
                    .frame(width: 300, height: 200)
            } else if let image = previewImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(radius: 2)
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
                    .frame(width: 300, height: 200)
            }
        }
    }

    private var propertySection: some View {
        PropertySection(title: "Attachment") {
            PropertyRow(label: "ID", value: "\(attachment.id)")
            if let name = attachment.fileName {
                PropertyRow(label: "File Name", value: name)
            }
            if let contentType = attachment.contentType {
                PropertyRow(label: "Content Type", value: contentType)
            }
            if let size = attachment.size {
                PropertyRow(label: "Size", value: "\(size) bytes")
            }
            if let desc = attachment.description {
                PropertyRow(label: "Description", value: desc)
            }
            if let uid = attachment.properties?.uid {
                PropertyRow(label: "UID", value: "\(uid)")
            }
        }
    }

    private func loadPreview() async {
        isExtracting = true
        defer { isExtracting = false }

        do {
            let extractedPath = try await appViewModel.extractAttachment(
                filePath: filePath,
                attachmentId: attachment.id
            )
            previewImage = NSImage(contentsOfFile: extractedPath)
        } catch {
            previewImage = nil
        }
    }
}
