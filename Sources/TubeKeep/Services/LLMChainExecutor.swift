import Foundation

/// 체인 단계 실행 중 던질 수 있는 공통 오류.
enum LLMChainStepError: LocalizedError {
    /// 실행은 성공했지만 출력이 비어 있어 다음 단계로 넘겨야 하는 경우
    case invalidOutput

    var errorDescription: String? {
        switch self {
        case .invalidOutput: return "AI 출력이 유효하지 않음"
        }
    }
}

/// AI 폴백 체인의 한 단계를 정의한다.
/// - `provider`: 로그/결과에 표시할 서비스 이름 (e.g. "Gemini")
/// - `isAvailable`: 키 존재 여부 등 이 단계를 실행할 수 있는지
/// - `execute`: 실제 호출 (실패 시 throw)
/// - `validate`: 특정 타입의 결과를 검증. 기본은 항상 통과
struct LLMChainStep<Output> {
    let provider: String
    let isAvailable: Bool
    let execute: () async throws -> Output
    let validate: (Output) -> Bool

    init(
        provider: String,
        isAvailable: Bool,
        validate: @escaping (Output) -> Bool = { _ in true },
        execute: @escaping () async throws -> Output
    ) {
        self.provider = provider
        self.isAvailable = isAvailable
        self.execute = execute
        self.validate = validate
    }
}

/// LLM 폴백 체인 실행기 — 순서가 정의된 단계들을 순차 시도해 첫 성공 결과를 반환한다.
/// Summarization/Tagging/ChannelInsight/SimilarVideo의 중복된 폴백 로직을 단일화한다.
enum LLMChainExecutor {
    /// 모든 단계를 순차 실행. 성공 시 (provider, output), 전부 실패 시 nil.
    static func run<Output>(
        _ steps: [LLMChainStep<Output>],
        logSkipped: (String) -> Void = { _ in },
        logFailed: (String, Error) -> Void = { _, _ in }
    ) async -> (provider: String, output: Output)? {
        for step in steps {
            guard step.isAvailable else {
                logSkipped(step.provider)
                continue
            }
            do {
                let output = try await step.execute()
                guard step.validate(output) else {
                    logSkipped(step.provider)
                    continue
                }
                return (step.provider, output)
            } catch {
                logFailed(step.provider, error)
            }
        }
        return nil
    }
}