import Foundation
import SwiftData
import AppKit

@MainActor
final class ClipService {
    static let shared = ClipService()

    private var context: ModelContext { PersistenceController.shared.context }

    static func clipsRootDirectory() -> URL {
        URL(fileURLWithPath: Settings.loadSettings().storageDirectory)
            .appendingPathComponent("Clips", isDirectory: true)
    }

    static func clipsDirectory(for videoId: String) -> URL {
        clipsRootDirectory().appendingPathComponent(videoId, isDirectory: true)
    }

    func allClips() -> [ClipItem] {
        let descriptor = FetchDescriptor<ClipItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func clips(for videoId: String) -> [ClipItem] {
        allClips().filter { $0.videoId == videoId }
    }

    func clipCount(for videoId: String) -> Int {
        clips(for: videoId).count
    }

    func hasDuplicateRange(videoId: String, start: Double, end: Double) -> Bool {
        clips(for: videoId).contains {
            abs($0.start - start) < 0.1 && abs($0.end - end) < 0.1
        }
    }

    func saveClip(
        videoId: String,
        channelName: String?,
        title: String,
        sourcePath: String,
        start: Double,
        end: Double,
        progress: @escaping @MainActor (Double) -> Void = { _ in }
    ) async throws -> ClipItem {
        guard start < end else { throw ClipError.invalidRange }
        guard !hasDuplicateRange(videoId: videoId, start: start, end: end) else {
            throw ClipError.duplicateRange
        }
        let dir = Self.clipsDirectory(for: videoId)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let ext = (sourcePath as NSString).pathExtension.isEmpty ? "mp4" : (sourcePath as NSString).pathExtension
        let outURL = dir.appendingPathComponent("clip_\(Int(Date().timeIntervalSince1970)).\(ext)")
        try await runFFmpeg(source: sourcePath, output: outURL.path, start: start, end: end, progress: progress)

        let thumbURL = dir.appendingPathComponent("thumb.jpg")
        generateThumbnail(source: sourcePath, output: thumbURL.path, at: start)

        let item = ClipItem(
            videoId: videoId,
            channelName: channelName,
            title: title,
            filePath: outURL.path,
            thumbnailPath: FileManager.default.fileExists(atPath: thumbURL.path) ? thumbURL.path : nil,
            start: start,
            end: end
        )
        context.insert(item)
        try context.save()
        return item
    }

    private func generateThumbnail(source: String, output: String, at time: Double) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: Constants.ffmpegPath)
        process.arguments = [
            "-y",
            "-ss", String(format: "%.3f", time),
            "-i", source,
            "-frames:v", "1",
            "-q:v", "2",
            output
        ]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        try? process.run()
        process.waitUntilExit()
    }

    func deleteClip(_ clip: ClipItem) {
        BookmarkManager.ensureAccess()
        try? FileManager.default.removeItem(atPath: clip.filePath)
        context.delete(clip)
        try? context.save()
    }

    func deleteClips(for videoId: String) -> Int {
        let clips = clips(for: videoId)
        for clip in clips {
            BookmarkManager.ensureAccess()
            try? FileManager.default.removeItem(atPath: clip.filePath)
            context.delete(clip)
        }
        try? context.save()
        return clips.count
    }

    static func confirmAndDeleteClipsIfAny(for videoId: String) -> Bool {
        let count = ClipService.shared.clipCount(for: videoId)
        guard count > 0 else { return true }
        let alert = NSAlert()
        alert.alertStyle = NSAlert.Style.warning
        alert.messageText = "클립 \(count)개도 함께 삭제할까요?"
        alert.informativeText = "원본 영상을 삭제하면 이 영상에서 저장한 클립 파일도 함께 지워집니다."
        alert.addButton(withTitle: "클립도 삭제")
        alert.addButton(withTitle: "영상만 삭제")
        alert.addButton(withTitle: "취소")
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            _ = ClipService.shared.deleteClips(for: videoId)
            return true
        case .alertSecondButtonReturn:
            return true
        default:
            return false
        }
    }

    private func runFFmpeg(
        source: String,
        output: String,
        start: Double,
        end: Double,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: Constants.ffmpegPath)
        process.arguments = [
            "-y",
            "-ss", String(format: "%.3f", start),
            "-i", source,
            "-t", String(format: "%.3f", end - start),
            "-c", "copy",
            "-progress", "pipe:1",
            "-nostats",
            output
        ]
        let outPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = Pipe()
        try process.run()

        let duration = end - start
        let readTask = Task.detached(priority: .userInitiated) {
            let handle = outPipe.fileHandleForReading
            var buffer = ""
            while true {
                let data = handle.availableData
                guard !data.isEmpty else { break }
                buffer += String(decoding: data, as: UTF8.self)
                while let nl = buffer.firstIndex(of: "\n") {
                    let line = String(buffer[..<nl])
                    buffer.removeSubrange(buffer.startIndex...nl)
                    let parts = line.split(separator: "=", maxSplits: 1)
                    guard parts.count == 2 else { continue }
                    let key = parts[0].trimmingCharacters(in: .whitespaces)
                    let value = parts[1].trimmingCharacters(in: .whitespaces)
                    if key == "out_time_us", let us = Double(value), duration > 0 {
                        let p = min(max(us / (duration * 1_000_000), 0), 1)
                        await MainActor.run { progress(p) }
                    }
                }
            }
        }

        let status = await withCheckedContinuation { cont in
            process.terminationHandler = { cont.resume(returning: $0.terminationStatus) }
        }
        _ = await readTask.value
        guard status == 0 else { throw ClipError.encodeFailed(status) }
    }
}
