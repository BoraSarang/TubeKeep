import SwiftUI

// MARK: - Cached Avatar View

struct CachedAvatarView: View {
    let channelId: String
    let url: String
    let size: CGFloat

    @Environment(\.imageCache) private var cache
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
            } else {
                ProgressView()
                    .frame(width: size, height: size)
                    .task {
                        await loadAvatar()
                    }
            }
        }
        .frame(width: size, height: size)
    }

    private func loadAvatar() async {
        guard !url.isEmpty else { return }
        
        // Check cache first
        if let cached = cache.cachedAvatar(for: channelId) {
            await MainActor.run { image = cached }
            return
        }

        // Download and cache
        guard let urlObj = URL(string: url) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: urlObj)
            if let nsImage = NSImage(data: data) {
                cache.cacheAvatar(for: channelId, data: data)
                await MainActor.run { image = nsImage }
            }
        } catch {
            // Silent fail - show placeholder
        }
    }
}

// MARK: - Cached Thumbnail View

struct CachedThumbnailView: View {
    let videoId: String
    let url: String

    @Environment(\.imageCache) private var cache
    @State private var image: NSImage?

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ProgressView()
                    .task {
                        await loadThumbnail()
                    }
            }
        }
    }

    private func loadThumbnail() async {
        guard !url.isEmpty else { return }
        
        // Check cache first
        if let cached = cache.cachedThumbnail(for: videoId) {
            await MainActor.run { image = cached }
            return
        }

        // Download and cache
        guard let urlObj = URL(string: url) else { return }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: urlObj)
            if let nsImage = NSImage(data: data) {
                cache.cacheThumbnail(for: videoId, data: data)
                await MainActor.run { image = nsImage }
            }
        } catch {
            // Silent fail - show placeholder
        }
    }
}