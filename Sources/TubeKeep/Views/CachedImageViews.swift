import SwiftUI

// MARK: - Cached Avatar View

struct CachedAvatarView: View {
    let channelId: String
    let url: String
    let size: CGFloat

    @Environment(\.imageCache) private var cache
    @State private var image: NSImage?
    @State private var failed = false

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
            } else if failed {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
                    .frame(width: size, height: size)
            } else {
                ProgressView()
                    .frame(width: size, height: size)
            }
        }
        .frame(width: size, height: size)
        .onChange(of: channelId) { _, _ in
            image = nil
            failed = false
            Task { await loadAvatar() }
        }
        .onChange(of: url) { _, _ in
            image = nil
            failed = false
            Task { await loadAvatar() }
        }
        .onReceive(NotificationCenter.default.publisher(for: Constants.channelInfoDidUpdateNotification)) { note in
            guard let updatedId = note.userInfo?["channelId"] as? String, updatedId == channelId else { return }
            image = nil
            failed = false
            Task { await loadAvatar() }
        }
        .task {
            await loadAvatar()
        }
    }

    private func loadAvatar() async {
        // 캐시는 channelId 키로 공유 → url과 무관하게 우선 조회
        if let cached = cache.cachedAvatar(for: channelId) {
            await MainActor.run { image = cached }
            return
        }

        guard !url.isEmpty else {
            await MainActor.run { failed = true }
            return
        }

        // Download and cache
        guard let urlObj = URL(string: url) else {
            await MainActor.run { failed = true }
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: urlObj)
            if let nsImage = NSImage(data: data) {
                cache.cacheAvatar(for: channelId, data: data)
                await MainActor.run { image = nsImage }
            } else {
                await MainActor.run { failed = true }
            }
        } catch {
            await MainActor.run { failed = true }
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
            }
        }
        .onChange(of: videoId) { _, _ in
            image = nil
            Task { await loadThumbnail() }
        }
        .task {
            await loadThumbnail()
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