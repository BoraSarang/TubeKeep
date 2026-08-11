import Foundation
import CryptoKit

/// 순수 Swift 기반 Edge TTS 클라이언트 (Python 의존성 없음)
final class EdgeTTSClient: NSObject, URLSessionWebSocketDelegate {
    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var audioData = Data()

    private static let trustedClientToken = "6A5AA1D4EAFF4E9FB37E23D68491D6F4"
    private static let winEpoch: Double = 11644473600
    private static let secMSgecVersion = "1-143.0.3650.75"
    private static let wssBase = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1"

    enum EdgeTTSError: LocalizedError {
        case connectionFailed(String)
        case synthesisFailed(String)

        var errorDescription: String? {
            switch self {
            case .connectionFailed(let msg): return "연결 실패: \(msg)"
            case .synthesisFailed(let msg): return "음성 합성 실패: \(msg)"
            }
        }
    }

    // MARK: - Sec-MS-GEC 토큰 생성

    private static func generateSecMSgec() -> String {
        let now = Date().timeIntervalSince1970
        var ticks = now + winEpoch
        ticks -= ticks.truncatingRemainder(dividingBy: 300)
        ticks *= 1_000_000_000 / 100
        let strToHash = String(format: "%.0f%@", ticks, trustedClientToken)
        let digest = SHA256.hash(data: Data(strToHash.utf8))
        return digest.map { String(format: "%02X", $0) }.joined()
    }

    private static func generateMUID() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, 16, &bytes)
        return bytes.map { String(format: "%02X", $0) }.joined()
    }

    // MARK: - 공개 API

    func synthesize(text: String, voice: String? = nil, rate: String = "+10%") async throws -> Data {
        audioData = Data()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                var hasResumed = false
                let resumeOnce: (Result<Data, Error>) -> Void = { result in
                    guard !hasResumed else { return }
                    hasResumed = true
                    continuation.resume(with: result)
                }

                let config = URLSessionConfiguration.default
                config.waitsForConnectivity = true
                config.timeoutIntervalForRequest = 30
                session = URLSession(configuration: config, delegate: self, delegateQueue: nil)

                let connectionId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
                let secGec = Self.generateSecMSgec()
                let muid = Self.generateMUID()

                let urlString = "\(Self.wssBase)?Sec-MS-GEC=\(secGec)&Sec-MS-GEC-Version=\(Self.secMSgecVersion)&TrustedClientToken=\(Self.trustedClientToken)&ConnectionId=\(connectionId)"

                guard let url = URL(string: urlString) else {
                    resumeOnce(.failure(EdgeTTSError.connectionFailed("URL 생성 실패")))
                    return
                }

                var request = URLRequest(url: url)
                request.addValue("chrome-extension://jdiccldimpdaibmpdkjnbmckianbfold", forHTTPHeaderField: "Origin")
                request.addValue("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/143.0.0.0 Safari/537.36 Edg/143.0.0.0", forHTTPHeaderField: "User-Agent")
                request.addValue("no-cache", forHTTPHeaderField: "Pragma")
                request.addValue("no-cache", forHTTPHeaderField: "Cache-Control")
                request.addValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
                request.addValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
                request.addValue("muid=\(muid);", forHTTPHeaderField: "Cookie")

                webSocket = session?.webSocketTask(with: request)
                webSocket?.resume()

                // config 메시지 전송
                let configJSON = "{\"context\":{\"synthesis\":{\"audio\":{\"metadataOptions\":{\"sentenceBoundaryEnabled\":false,\"wordBoundaryEnabled\":false},\"outputFormat\":\"audio-24khz-48kbitrate-mono-mp3\"}}}}"
                let configMsg = "Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n\(configJSON)"

                webSocket?.send(.string(configMsg)) { [weak self] error in
                    guard let self = self else { return }
                    if let error = error {
                        resumeOnce(.failure(EdgeTTSError.connectionFailed(error.localizedDescription)))
                        return
                    }

                    // SSML 전송
                    let escapedText = text
                        .replacingOccurrences(of: "&", with: "&amp;")
                        .replacingOccurrences(of: "<", with: "&lt;")
                        .replacingOccurrences(of: ">", with: "&gt;")
                        .replacingOccurrences(of: "\"", with: "&quot;")

                    let timestamp = Self.formatTimestamp(Date())
                    let resolvedVoice = voice ?? LanguageService.ttsVoice(for: .edgeTTS, gender: .male)
                    let lang = resolvedVoice.count >= 5 ? String(resolvedVoice.prefix(5)) : LanguageService.systemLanguageCode
                    let ssml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='\(lang)'><voice name='\(resolvedVoice)'><prosody rate='\(rate)'>\(escapedText)</prosody></voice></speak>"
                    let synthMsg = "X-RequestId:\(connectionId)\r\nContent-Type:application/ssml+xml\r\nX-Timestamp:\(timestamp)\r\nPath:ssml\r\n\r\n\(ssml)"

                    self.webSocket?.send(.string(synthMsg)) { error in
                        if let error = error {
                            resumeOnce(.failure(EdgeTTSError.synthesisFailed(error.localizedDescription)))
                        }
                    }

                    self.receiveLoop(resumeOnce: resumeOnce)
                }
            }
        } onCancel: { [weak self] in
            self?.webSocket?.cancel(with: .goingAway, reason: nil)
        }
    }

    private static func formatTimestamp(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f.string(from: date) + "Z"
    }

    // MARK: - 수신

    private func receiveLoop(resumeOnce: @escaping (Result<Data, Error>) -> Void) {
        webSocket?.receive { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self.processBinaryData(data)
                    self.receiveLoop(resumeOnce: resumeOnce)
                case .string(let text):
                    if text.contains("Path:turn.end") {
                        if self.audioData.isEmpty {
                            resumeOnce(.failure(EdgeTTSError.synthesisFailed("오디오 데이터 없음")))
                        } else {
                            resumeOnce(.success(self.audioData))
                        }
                        self.webSocket?.cancel(with: .normalClosure, reason: nil)
                    } else {
                        self.receiveLoop(resumeOnce: resumeOnce)
                    }
                @unknown default:
                    self.receiveLoop(resumeOnce: resumeOnce)
                }
            case .failure(let error):
                if !self.audioData.isEmpty {
                    resumeOnce(.success(self.audioData))
                } else {
                    resumeOnce(.failure(EdgeTTSError.connectionFailed(error.localizedDescription)))
                }
            }
        }
    }

    private func processBinaryData(_ data: Data) {
        guard data.count >= 2 else { return }
        let headerLen = Int(data[0]) << 8 | Int(data[1])
        let audioStart = 2 + headerLen
        guard audioStart < data.count else { return }
        audioData.append(data[audioStart...])
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocol: String?) {}
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {}
}
