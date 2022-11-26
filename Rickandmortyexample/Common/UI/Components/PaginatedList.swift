import SwiftUI

struct PaginatedList<Data, Content>: View where Content: View {
    let data: NetworkData<Data>
    let onRefetch: @Sendable () async -> Void
    let onLoadNextPage: () async -> Void
    @ViewBuilder let content: (_: Data) -> Content

    @State private var loadingNextPage = false

    var body: some View {
        NetworkDataContainer(data: data, onRefetch: onRefetch) { loadedData in
            BottomDetectorScrollView {
                VStack(spacing: 0) {
                    content(loadedData)
                    if loadingNextPage { ProgressView().padding(16) }
                }
            } onBottomReached: {
                handleLoadNextPage()
            }
        }
    }
}

// MARK: - Logic
extension PaginatedList {
    func handleLoadNextPage() {
        if loadingNextPage { return }
        loadingNextPage = true
        Task { @MainActor in
            await onLoadNextPage()
            loadingNextPage = false
        }
    }
}

// MARK: - Previews
struct PaginatedListPreviews: PreviewProvider {
    static var previews: some View {
        PaginatedList(
            data: NetworkData<String>.data("Hello!"),
            onRefetch: delay,
            onLoadNextPage: delay) { data in
            Text(data, variant: .body15)

        }
            .previewDisplayName("With data")
        PaginatedList(
            data: NetworkData<String>.loading,
            onRefetch: delay,
            onLoadNextPage: delay) { _ in }
            .previewDisplayName("Loading")
    }
}