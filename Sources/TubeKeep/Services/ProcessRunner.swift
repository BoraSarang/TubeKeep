import Foundation
import Darwin

enum ProcessError: LocalizedError {
    case notFound(String)
    case executionFailed(String)
    case outputParsingFailed(String)

    var errorDescription: String? {
        switch self {
        case let .notFound(path):
            return "실행 파일을 찾을 수 없음: \(path)"
        case let .executionFailed(msg):
            return "실행 실패: \(msg)"
        case let .outputParsingFailed(msg):
            return "출력 파싱 실패: \(msg)"
        }
    }
}

/// withTaskCancellationHandler의 onCancel에서 실행 중인 Process를 종료하기 위한 참조 박스
final class ProcessBox: @unchecked Sendable {
    var process: Process?
}

actor ProcessRunner {
    private final class MutableData: @unchecked Sendable {
        var data = Data()
    }

    func run(
        executable: String,
        arguments: [String],
        progressHandler: (@Sendable (String) -> Void)? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let process = Process()
                    ProcessRegistry.register(process)
                    if executable.hasPrefix("/") {
                        process.executableURL = URL(fileURLWithPath: executable)
                        process.arguments = arguments
                    } else {
                        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                        process.arguments = [executable] + arguments
                    }

                    let stdoutPipe = Pipe()
                    let stderrPipe = Pipe()
                    process.standardOutput = stdoutPipe
                    process.standardError = stderrPipe

                    try process.run()
                    let pid = process.processIdentifier

                    let stdoutBox = MutableData()
                    let lock = NSLock()

                    let stdoutHandle = stdoutPipe.fileHandleForReading
                    stdoutHandle.readabilityHandler = { handle in
                        let data = handle.availableData
                        guard !data.isEmpty else {
                            stdoutHandle.readabilityHandler = nil
                            return
                        }
                        lock.withLock { stdoutBox.data.append(data) }
                    }

                    let stderrHandle = stderrPipe.fileHandleForReading
                    stderrHandle.readabilityHandler = { handle in
                        let data = handle.availableData
                        guard !data.isEmpty,
                              let output = String(data: data, encoding: .utf8)
                        else { return }
                        continuation.yield(output)
                        progressHandler?(output)
                    }

                    await withTaskCancellationHandler {
                        process.waitUntilExit()
                    } onCancel: {
                        process.terminate()
                        kill(pid, SIGKILL)
                    }
                    stdoutHandle.readabilityHandler = nil
                    stderrHandle.readabilityHandler = nil

                    if Task.isCancelled {
                        continuation.finish(throwing: CancellationError())
                        return
                    }

                    let stdoutOutput = lock.withLock { String(data: stdoutBox.data, encoding: .utf8) ?? "" }
                    if !stdoutOutput.isEmpty {
                        continuation.yield(stdoutOutput)
                    }

                    if process.terminationStatus == 0 {
                        continuation.finish()
                    } else {
                        continuation.finish(
                            throwing: ProcessError.executionFailed(
                                "Exit code: \(process.terminationStatus)"
                            )
                        )
                    }
                } catch {
                    if Task.isCancelled {
                        continuation.finish(throwing: CancellationError())
                    } else {
                        continuation.finish(throwing: error)
                    }
                }
            }
        }
    }

    func runStreamingStdout(
        executable: String,
        arguments: [String],
        environment: [String: String] = [:]
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                let process = Process()
                ProcessRegistry.register(process)
                if executable.hasPrefix("/") {
                    process.executableURL = URL(fileURLWithPath: executable)
                    process.arguments = arguments
                } else {
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                    process.arguments = [executable] + arguments
                }
                if !environment.isEmpty {
                    var env = ProcessInfo.processInfo.environment
                    for (key, value) in environment { env[key] = value }
                    process.environment = env
                }

                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                do {
                    try process.run()
                } catch {
                    continuation.finish(throwing: error)
                    return
                }

                let pid = process.processIdentifier
                let stderrBox = MutableData()
                let lock = NSLock()

                let stdoutHandle = stdoutPipe.fileHandleForReading
                stdoutHandle.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty,
                          let output = String(data: data, encoding: .utf8)
                    else { return }
                    continuation.yield(output)
                }

                let stderrHandle = stderrPipe.fileHandleForReading
                stderrHandle.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty else {
                        stderrHandle.readabilityHandler = nil
                        return
                    }
                    lock.withLock { stderrBox.data.append(data) }
                }

                await withTaskCancellationHandler {
                    process.waitUntilExit()
                } onCancel: {
                    process.terminate()
                    kill(pid, SIGKILL)
                }
                stdoutHandle.readabilityHandler = nil
                stderrHandle.readabilityHandler = nil

                if Task.isCancelled {
                    continuation.finish(throwing: CancellationError())
                    return
                }

                let stderr = lock.withLock { String(data: stderrBox.data, encoding: .utf8) ?? "" }

                if process.terminationStatus == 0 {
                    continuation.finish()
                } else {
                    continuation.finish(
                        throwing: ProcessError.executionFailed(
                            stderr.isEmpty ? "Exit code: \(process.terminationStatus)" : stderr
                        )
                    )
                }
            }
        }
    }

    func runSync(
        executable: String,
        arguments: [String],
        timeout: TimeInterval = 120
    ) async throws -> String {
        let process = Process()
        if executable.hasPrefix("/") {
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [executable] + arguments
        }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let semaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in semaphore.signal() }
        ProcessRegistry.register(process)

        let stdoutBox = MutableData()
        let stderrBox = MutableData()
        let lock = NSLock()

        let stdoutHandle = stdoutPipe.fileHandleForReading
        stdoutHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                stdoutHandle.readabilityHandler = nil
                return
            }
            lock.withLock { stdoutBox.data.append(data) }
        }

        let stderrHandle = stderrPipe.fileHandleForReading
        stderrHandle.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else {
                stderrHandle.readabilityHandler = nil
                return
            }
            lock.withLock { stderrBox.data.append(data) }
        }

        try process.run()

        let pid = process.processIdentifier
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                DispatchQueue.global().async {
                    let result = semaphore.wait(timeout: .now() + timeout)

                    stdoutHandle.readabilityHandler = nil
                    stderrHandle.readabilityHandler = nil

                    if result == .timedOut {
                        process.terminate()
                        kill(pid, SIGKILL)
                        continuation.resume(throwing: ProcessError.executionFailed("Timeout after \(Int(timeout))초"))
                        return
                    }

                    let stderr = lock.withLock { String(data: stderrBox.data, encoding: .utf8) ?? "" }

                    guard process.terminationStatus == 0 else {
                        continuation.resume(throwing: ProcessError.executionFailed(stderr))
                        return
                    }

                    let output = lock.withLock { String(data: stdoutBox.data, encoding: .utf8) ?? "" }
                    continuation.resume(returning: output)
                }
            }
        } onCancel: {
            process.terminate()
            kill(pid, SIGKILL)
        }
    }
}
