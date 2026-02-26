import Foundation
import Testing
@testable import Babushka

@Suite("FileViewModel")
struct FileViewModelTests {

    @Test("Sidebar tree construction from test5.mkv")
    @MainActor
    func sidebarTreeConstruction() async throws {
        let filePath = try await TestFileManager.shared.path(for: .test5)
        let service = MKVToolnixService()
        let viewModel = FileViewModel(filePath: filePath, service: service)

        await viewModel.load()

        #expect(viewModel.identification != nil)
        #expect(viewModel.sidebarItems.count == 1) // One file item

        let fileItem = viewModel.sidebarItems[0]
        if case .file(let id, let name) = fileItem {
            #expect(name == "test5.mkv")

            let children = viewModel.sidebarChildren[id]
            #expect(children != nil)
            #expect(children!.count == 3) // Video, Audio, Subtitles groups

            // Verify group ordering: Video, Audio, Subtitles
            if case .trackGroup(_, let type1, let count1) = children![0] {
                #expect(type1 == .video)
                #expect(count1 == 1)
            } else {
                Issue.record("First group should be Video")
            }

            if case .trackGroup(_, let type2, let count2) = children![1] {
                #expect(type2 == .audio)
                #expect(count2 == 2)
            } else {
                Issue.record("Second group should be Audio")
            }

            if case .trackGroup(let groupId, let type3, let count3) = children![2] {
                #expect(type3 == .subtitles)
                #expect(count3 == 8)

                // Verify subtitle tracks are present as children of the group
                let subtitleChildren = viewModel.sidebarChildren[groupId]
                #expect(subtitleChildren?.count == 8)
            } else {
                Issue.record("Third group should be Subtitles")
            }
        } else {
            Issue.record("First sidebar item should be a file")
        }
    }

    @Test("Loading state transitions")
    @MainActor
    func loadingStateTransitions() async throws {
        let filePath = try await TestFileManager.shared.path(for: .test5)
        let service = MKVToolnixService()
        let viewModel = FileViewModel(filePath: filePath, service: service)

        // Initial state
        #expect(viewModel.identification == nil)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)

        await viewModel.load()

        // After loading
        #expect(viewModel.identification != nil)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Error state for invalid file")
    @MainActor
    func errorStateForInvalidFile() async throws {
        let service = MKVToolnixService()
        let viewModel = FileViewModel(filePath: "/nonexistent/file.mkv", service: service)

        await viewModel.load()

        #expect(viewModel.identification == nil)
        #expect(viewModel.errorMessage != nil)
    }

    @Test("Track lookup from sidebar item")
    @MainActor
    func trackLookup() async throws {
        let filePath = try await TestFileManager.shared.path(for: .test5)
        let service = MKVToolnixService()
        let viewModel = FileViewModel(filePath: filePath, service: service)

        await viewModel.load()

        // Find a track sidebar item
        for (_, children) in viewModel.sidebarChildren {
            for child in children {
                if case .track = child {
                    let track = viewModel.track(for: child)
                    #expect(track != nil)
                    return
                }
            }
        }
        Issue.record("Should have found at least one track sidebar item")
    }
}
