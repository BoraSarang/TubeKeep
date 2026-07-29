import Foundation
import SQLite3

final class DatabaseManager {
    static let shared = DatabaseManager()

    private var _db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.borasarang.tubekeep.db")

    private let dbFileName = "tubekeep_ai.db"

    private var dbPath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("com.borasarang.tubekeep")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(dbFileName).path
    }

    private init() {
        openDatabase()
        createTables()
        if let db = _db {
            var countStmt: OpaquePointer?
            if sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM video_ai_data;", -1, &countStmt, nil) == SQLITE_OK {
                if sqlite3_step(countStmt) == SQLITE_ROW {
                    let count = sqlite3_column_int(countStmt, 0)
                    log("[DB] 초기 행 수: \(count)")
                }
            }
            sqlite3_finalize(countStmt)
        }
    }

    deinit {
        if let db = _db {
            sqlite3_close(db)
        }
    }

    // MARK: - Database Open

    private func openDatabase() {
        if sqlite3_open(dbPath, &_db) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(_db))
            log("[DB] 데이터베이스 열기 실패: \(errmsg)")
            _db = nil
        } else {
            log("[DB] 데이터베이스 열기 성공: \(dbPath)")
        }
    }

    // MARK: - Table Creation

    private func createTables() {
        let createVideoAIData = """
        CREATE TABLE IF NOT EXISTS video_ai_data (
            video_id TEXT PRIMARY KEY,
            transcript TEXT,
            transcript_language TEXT,
            summary TEXT,
            chapters JSON,
            mindmap JSON,
            podcast_path TEXT,
            tags TEXT,
            subtitles_json TEXT,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
        );
        """

        let createQnAHistory = """
        CREATE TABLE IF NOT EXISTS qna_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            video_id TEXT,
            question TEXT,
            answer TEXT,
            timestamps JSON,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (video_id) REFERENCES video_ai_data(video_id) ON DELETE CASCADE
        );
        """

        let createDownloadHistory = """
        CREATE TABLE IF NOT EXISTS download_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            video_id TEXT,
            title TEXT NOT NULL,
            channel_name TEXT,
            url TEXT NOT NULL,
            format_label TEXT,
            resolution INTEGER,
            file_size INTEGER,
            file_path TEXT,
            downloaded_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            status TEXT DEFAULT 'completed'
        );
        """

        execute(createVideoAIData)
        execute("ALTER TABLE video_ai_data ADD COLUMN subtitles_json TEXT;")
        execute(createQnAHistory)
        execute(createDownloadHistory)
        log("[DB] 테이블 생성 완료")
    }

    // MARK: - SQLITE_TRANSIENT (SQLite가 문자열을 복사하도록)

    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    // MARK: - Execute

    @discardableResult
    private func execute(_ sql: String) -> Bool {
        guard let db = _db else { return false }
        var errMsg: UnsafeMutablePointer<CChar>?
        if sqlite3_exec(db, sql, nil, nil, &errMsg) != SQLITE_OK {
            let errmsg = String(cString: errMsg!)
            sqlite3_free(errMsg)
            log("[DB] 실행 실패: \(errmsg)")
            return false
        }
        return true
    }

    // MARK: - Serial Queue

    @discardableResult
    private func sync<T>(_ block: () throws -> T) rethrows -> T {
        try queue.sync(execute: block)
    }

    // MARK: - Video AI Data CRUD

    func saveVideoAIData(_ data: VideoAIData) {
        sync {
            let sql = """
            INSERT OR REPLACE INTO video_ai_data
            (video_id, transcript, transcript_language, summary, chapters, mindmap, podcast_path, tags, subtitles_json, updated_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP);
            """

            guard let db = _db else { return }
            var stmt: OpaquePointer?

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                log("[DB] saveVideoAIData prepare 실패")
                return
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, data.videoId, -1, Self.transient)
            bindOptionalText(stmt, 2, data.transcript)
            bindOptionalText(stmt, 3, data.transcriptLanguage)
            bindOptionalText(stmt, 4, data.summary)
            bindOptionalData(stmt, 5, data.chapters)
            bindOptionalData(stmt, 6, data.mindmap)
            bindOptionalText(stmt, 7, data.podcastPath)
            bindOptionalData(stmt, 8, data.tags)
            bindOptionalText(stmt, 9, data.subtitlesData.flatMap { String(data: $0, encoding: .utf8) })

            if sqlite3_step(stmt) != SQLITE_DONE {
                log("[DB] saveVideoAIData 실행 실패")
            } else {
                log("[DB] saveVideoAIData 성공 — videoId: \(data.videoId)")
                NotificationCenter.default.post(name: Constants.videoAIDidChangeNotification, object: nil, userInfo: ["videoId": data.videoId])
            }
        }
    }

    func loadVideoAIData(videoId: String) -> VideoAIData? {
        sync {
            let sql = "SELECT * FROM video_ai_data WHERE video_id = ?;"

            guard let db = _db else {
                log("[DB] loadVideoAIData db=nil — videoId: \(videoId)")
                return nil
            }
            var stmt: OpaquePointer?

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                log("[DB] loadVideoAIData prepare 실패: \(videoId)")
                return nil
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, videoId, -1, Self.transient)

            let stepResult = sqlite3_step(stmt)
            guard stepResult == SQLITE_ROW else {
                return nil
            }

            return VideoAIData(
                videoId: columnText(stmt, 0) ?? videoId,
                transcript: columnText(stmt, 1),
                transcriptLanguage: columnText(stmt, 2),
                summary: columnText(stmt, 3),
                chapters: columnData(stmt, 4),
                mindmap: columnData(stmt, 5),
                podcastPath: columnText(stmt, 6),
                tags: columnData(stmt, 7),
                subtitlesData: columnText(stmt, 8).flatMap { $0.data(using: .utf8) }
            )
        }
    }

    func updateVideoAIData(_ data: VideoAIData) {
        saveVideoAIData(data)
    }

    func deleteVideoAIData(videoId: String) {
        sync {
            let sql = "DELETE FROM video_ai_data WHERE video_id = ?;"

            guard let db = _db else { return }
            var stmt: OpaquePointer?

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                log("[DB] deleteVideoAIData prepare 실패")
                return
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, videoId, -1, Self.transient)

            if sqlite3_step(stmt) != SQLITE_DONE {
                log("[DB] deleteVideoAIData 실행 실패")
            } else {
                log("[DB] deleteVideoAIData 성공 — videoId: \(videoId)")
            }
        }
    }

    func updateTranscript(videoId: String, transcript: String, language: String) {
        sync {
            let sql = """
            UPDATE video_ai_data
            SET transcript = ?, transcript_language = ?, updated_at = CURRENT_TIMESTAMP
            WHERE video_id = ?;
            """

            guard let db = _db else { return }
            var stmt: OpaquePointer?

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                log("[DB] updateTranscript prepare 실패")
                return
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, transcript, -1, Self.transient)
            sqlite3_bind_text(stmt, 2, language, -1, Self.transient)
            sqlite3_bind_text(stmt, 3, videoId, -1, Self.transient)

            if sqlite3_step(stmt) != SQLITE_DONE {
                log("[DB] updateTranscript 실행 실패")
            }
        }
    }

    func updateSummary(videoId: String, summary: String?) {
        sync {
            let sql = """
            INSERT INTO video_ai_data (video_id, summary, updated_at)
            VALUES (?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(video_id) DO UPDATE SET summary = ?, updated_at = CURRENT_TIMESTAMP;
            """

            guard let db = _db else { return }
            var stmt: OpaquePointer?

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                log("[DB] updateSummary prepare 실패")
                return
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, videoId, -1, Self.transient)
            bindOptionalText(stmt, 2, summary)
            bindOptionalText(stmt, 3, summary)

            if sqlite3_step(stmt) != SQLITE_DONE {
                log("[DB] updateSummary 실행 실패")
            }
        }
    }

    func updateChapters(videoId: String, chapters: Data) {
        sync {
            let sql = """
            INSERT INTO video_ai_data (video_id, chapters, updated_at)
            VALUES (?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(video_id) DO UPDATE SET chapters = ?, updated_at = CURRENT_TIMESTAMP;
            """

            guard let db = _db else { return }
            var stmt: OpaquePointer?

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                log("[DB] updateChapters prepare 실패")
                return
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, videoId, -1, Self.transient)
            bindOptionalData(stmt, 2, chapters)
            bindOptionalData(stmt, 3, chapters)

            if sqlite3_step(stmt) != SQLITE_DONE {
                log("[DB] updateChapters 실행 실패")
            }
        }
    }

    func updateTags(videoId: String, tags: Data) {
        sync {
            let sql = """
            UPDATE video_ai_data
            SET tags = ?, updated_at = CURRENT_TIMESTAMP
            WHERE video_id = ?;
            """

            guard let db = _db else { return }
            var stmt: OpaquePointer?

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                log("[DB] updateTags prepare 실패")
                return
            }
            defer { sqlite3_finalize(stmt) }

            bindOptionalData(stmt, 1, tags)
            sqlite3_bind_text(stmt, 2, videoId, -1, Self.transient)

            if sqlite3_step(stmt) != SQLITE_DONE {
                log("[DB] updateTags 실행 실패")
            }
        }
    }

    func updatePodcastPath(videoId: String, podcastPath: String?) {
        sync {
            let sql = """
            INSERT INTO video_ai_data (video_id, podcast_path, updated_at)
            VALUES (?, ?, CURRENT_TIMESTAMP)
            ON CONFLICT(video_id) DO UPDATE SET podcast_path = ?, updated_at = CURRENT_TIMESTAMP;
            """

            guard let db = _db else { return }
            var stmt: OpaquePointer?

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                log("[DB] updatePodcastPath prepare 실패")
                return
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, videoId, -1, Self.transient)
            bindOptionalText(stmt, 2, podcastPath)
            bindOptionalText(stmt, 3, podcastPath)

            if sqlite3_step(stmt) != SQLITE_DONE {
                log("[DB] updatePodcastPath 실행 실패")
            }
        }
    }

    // MARK: - Q&A History CRUD

    func saveQnAEntry(_ entry: QnAEntry) {
        sync {
            let sql = """
            INSERT INTO qna_history (video_id, question, answer, timestamps)
            VALUES (?, ?, ?, ?);
            """

            guard let db = _db else { return }
            var stmt: OpaquePointer?

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                log("[DB] saveQnAEntry prepare 실패")
                return
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, entry.videoId, -1, Self.transient)
            sqlite3_bind_text(stmt, 2, entry.question, -1, Self.transient)
            sqlite3_bind_text(stmt, 3, entry.answer, -1, Self.transient)
            bindOptionalData(stmt, 4, entry.timestamps)

            if sqlite3_step(stmt) != SQLITE_DONE {
                log("[DB] saveQnAEntry 실행 실패")
            }
        }
    }

    func loadQnAHistory(videoId: String) -> [QnAEntry] {
        sync {
            let sql = "SELECT * FROM qna_history WHERE video_id = ? ORDER BY created_at DESC;"

            guard let db = _db else { return [] }
            var stmt: OpaquePointer?
            var results: [QnAEntry] = []

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                log("[DB] loadQnAHistory prepare 실패")
                return []
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_text(stmt, 1, videoId, -1, Self.transient)

            while sqlite3_step(stmt) == SQLITE_ROW {
                let entry = QnAEntry(
                    id: sqlite3_column_int(stmt, 0),
                    videoId: columnText(stmt, 1) ?? videoId,
                    question: columnText(stmt, 2) ?? "",
                    answer: columnText(stmt, 3) ?? "",
                    timestamps: columnData(stmt, 4)
                )
                results.append(entry)
            }

            return results
        }
    }

    func deleteQnAEntry(id: Int32) {
        sync {
            let sql = "DELETE FROM qna_history WHERE id = ?;"

            guard let db = _db else { return }
            var stmt: OpaquePointer?

            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                log("[DB] deleteQnAEntry prepare 실패")
                return
            }
            defer { sqlite3_finalize(stmt) }

            sqlite3_bind_int(stmt, 1, id)

            if sqlite3_step(stmt) != SQLITE_DONE {
                log("[DB] deleteQnAEntry 실행 실패")
            }
        }
    }

    // MARK: - Helpers

    private func bindOptionalText(_ stmt: OpaquePointer?, _ index: Int32, _ value: String?) {
        if let value = value {
            sqlite3_bind_text(stmt, index, value, -1, Self.transient)
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func bindOptionalData(_ stmt: OpaquePointer?, _ index: Int32, _ value: Data?) {
        if let value = value {
            value.withUnsafeBytes { rawBufferPointer in
                let bufferPointer = rawBufferPointer.bindMemory(to: UInt8.self)
                sqlite3_bind_blob(stmt, index, bufferPointer.baseAddress, Int32(value.count), Self.transient)
            }
        } else {
            sqlite3_bind_null(stmt, index)
        }
    }

    private func columnText(_ stmt: OpaquePointer?, _ index: Int32) -> String? {
        guard let cString = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: cString)
    }

    private func columnData(_ stmt: OpaquePointer?, _ index: Int32) -> Data? {
        guard let blob = sqlite3_column_blob(stmt, index) else { return nil }
        let size = sqlite3_column_bytes(stmt, index)
        return Data(bytes: blob, count: Int(size))
    }

    // MARK: - Q&A History

    func saveQAHistory(videoId: String, question: String, answer: String, timestamps: [QATimestamp]) -> Int64 {
        sync {
            guard let db = _db else { return -1 }
            let json = (try? JSONEncoder().encode(timestamps)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
            var stmt: OpaquePointer?
            let sql = "INSERT INTO qna_history (video_id, question, answer, timestamps) VALUES (?, ?, ?, ?);"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return -1 }
            sqlite3_bind_text(stmt, 1, videoId, -1, Self.transient)
            sqlite3_bind_text(stmt, 2, question, -1, Self.transient)
            sqlite3_bind_text(stmt, 3, answer, -1, Self.transient)
            sqlite3_bind_text(stmt, 4, json, -1, Self.transient)
            let result = sqlite3_step(stmt) == SQLITE_DONE ? sqlite3_last_insert_rowid(db) : -1
            sqlite3_finalize(stmt)
            return result
        }
    }

    func loadQAHistory(videoId: String) -> [QAHistoryItem] {
        sync {
            guard let db = _db else { return [] }
            var stmt: OpaquePointer?
            let sql = "SELECT id, video_id, question, answer, timestamps, created_at FROM qna_history WHERE video_id = ? ORDER BY created_at DESC;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
            sqlite3_bind_text(stmt, 1, videoId, -1, Self.transient)
            var items: [QAHistoryItem] = []
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                let vId = String(cString: sqlite3_column_text(stmt, 1))
                let question = String(cString: sqlite3_column_text(stmt, 2))
                let answer = String(cString: sqlite3_column_text(stmt, 3))
                let timestampsJSON = sqlite3_column_text(stmt, 4).map { String(cString: $0) } ?? "[]"
                let createdAtStr = sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? ""
                let timestamps: [QATimestamp] = (try? JSONDecoder().decode([QATimestamp].self, from: Data(timestampsJSON.utf8))) ?? []
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                let createdAt = dateFormatter.date(from: createdAtStr) ?? Date()
                items.append(QAHistoryItem(id: id, videoId: vId, question: question, answer: answer, timestamps: timestamps, createdAt: createdAt))
            }
            sqlite3_finalize(stmt)
            return items
        }
    }

    func deleteQAHistory(id: Int64) {
        sync {
            guard let db = _db else { return }
            var stmt: OpaquePointer?
            let sql = "DELETE FROM qna_history WHERE id = ?;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            sqlite3_bind_int64(stmt, 1, id)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }

    func deleteAllQAHistory(videoId: String) {
        sync {
            guard let db = _db else { return }
            var stmt: OpaquePointer?
            let sql = "DELETE FROM qna_history WHERE video_id = ?;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            sqlite3_bind_text(stmt, 1, videoId, -1, Self.transient)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
        }
    }

    // MARK: - Download History CRUD

    func saveDownloadHistory(_ item: DownloadHistoryItem) {
        sync {
            let sql = """
            INSERT INTO download_history
            (video_id, title, channel_name, url, format_label, resolution, file_size, file_path, status, downloaded_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
            guard let db = _db else { return }
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
                log("[DB] saveDownloadHistory prepare 실패")
                return
            }
            defer { sqlite3_finalize(stmt) }
            bindOptionalText(stmt, 1, item.videoId)
            sqlite3_bind_text(stmt, 2, item.title, -1, Self.transient)
            bindOptionalText(stmt, 3, item.channelName)
            sqlite3_bind_text(stmt, 4, item.url, -1, Self.transient)
            bindOptionalText(stmt, 5, item.formatLabel)
            if let res = item.resolution { sqlite3_bind_int(stmt, 6, Int32(res)) }
            else { sqlite3_bind_null(stmt, 6) }
            if let size = item.fileSize { sqlite3_bind_int64(stmt, 7, size) }
            else { sqlite3_bind_null(stmt, 7) }
            bindOptionalText(stmt, 8, item.filePath)
            sqlite3_bind_text(stmt, 9, item.status, -1, Self.transient)
            let dateStr = ISO8601DateFormatter().string(from: item.downloadedAt)
            sqlite3_bind_text(stmt, 10, dateStr, -1, Self.transient)
            if sqlite3_step(stmt) != SQLITE_DONE {
                log("[DB] saveDownloadHistory 실행 실패")
            } else {
                log("[DB] saveDownloadHistory 성공 — \(item.title)")
            }
        }
    }

    func loadDownloadHistory() -> [DownloadHistoryItem] {
        sync {
            var results: [DownloadHistoryItem] = []
            let sql = """
            SELECT id, video_id, title, channel_name, url, format_label,
                   resolution, file_size, file_path, downloaded_at, status
            FROM download_history ORDER BY downloaded_at DESC;
            """
            guard let db = _db else { return results }
            var stmt: OpaquePointer?
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return results }
            defer { sqlite3_finalize(stmt) }
            while sqlite3_step(stmt) == SQLITE_ROW {
                let id = sqlite3_column_int64(stmt, 0)
                let videoId = columnText(stmt, 1)
                let title = columnText(stmt, 2) ?? ""
                let channelName = columnText(stmt, 3)
                let url = columnText(stmt, 4) ?? ""
                let formatLabel = columnText(stmt, 5)
                let resolution = sqlite3_column_type(stmt, 6) == SQLITE_NULL ? nil : Int(sqlite3_column_int(stmt, 6))
                let fileSize = sqlite3_column_type(stmt, 7) == SQLITE_NULL ? nil : sqlite3_column_int64(stmt, 7)
                let filePath = columnText(stmt, 8)
                let dateStr = columnText(stmt, 9) ?? ""
                let status = columnText(stmt, 10) ?? "completed"
                let downloadedAt = ISO8601DateFormatter().date(from: dateStr) ?? Date()
                results.append(DownloadHistoryItem(
                    id: id, videoId: videoId, title: title, channelName: channelName,
                    url: url, formatLabel: formatLabel, resolution: resolution,
                    fileSize: fileSize, filePath: filePath, downloadedAt: downloadedAt, status: status
                ))
            }
            return results
        }
    }

    func deleteDownloadHistory(id: Int64) {
        sync {
            guard let db = _db else { return }
            var stmt: OpaquePointer?
            let sql = "DELETE FROM download_history WHERE id = ?;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            sqlite3_bind_int64(stmt, 1, id)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
            log("[DB] deleteDownloadHistory — id: \(id)")
        }
    }

    func deleteDownloadHistory(channel: String) {
        sync {
            guard let db = _db else { return }
            var stmt: OpaquePointer?
            let sql = "DELETE FROM download_history WHERE channelName = ?;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            sqlite3_bind_text(stmt, 1, (channel as NSString).utf8String, -1, nil)
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
            log("[DB] deleteDownloadHistory — channel: \(channel)")
        }
    }

    func deleteAllDownloadHistory() {
        sync {
            guard let db = _db else { return }
            var stmt: OpaquePointer?
            let sql = "DELETE FROM download_history;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            sqlite3_step(stmt)
            sqlite3_finalize(stmt)
            log("[DB] deleteAllDownloadHistory")
        }
    }

    private func log(_ message: String) {
        #if DEBUG
        Task { @MainActor in
            DebugLogManager.shared?.append(message)
        }
        #endif
    }
}

// MARK: - Data Models

struct VideoAIData {
    let videoId: String
    var transcript: String?
    var transcriptLanguage: String?
    var summary: String?
    var chapters: Data?
    var mindmap: Data?
    var podcastPath: String?
    var tags: Data?
    var subtitlesData: Data?
}

struct QnAEntry {
    let id: Int32
    let videoId: String
    let question: String
    let answer: String
    let timestamps: Data?
}
