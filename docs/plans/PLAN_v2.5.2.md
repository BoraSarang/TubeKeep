# PLAN v2.5.2 — AI 팟캐스트 생성

## 개요

YouTube 영상의 자막(트랜스크립트)을 분석하여 2인 대화형 팟캐스트 스크립트를 생성하고, macOS 내장 TTS(AVSpeechSynthesizer)를 사용하여 오디오 파일로 변환하는 기능.

## 결정 사항

| 항목 | 결정 |
|------|------|
| **TTS 엔진** | macOS 내장 AVSpeechSynthesizer (완전 무료, 오프라인) |
| **음성** | 한국어 음성 2종 (남성/여성) 선택 가능 |
| **대화 스크립트** | 기존 SummarizationService의 LLM 폴백 체인 활용 (OpenRouter → yTeaser → A.X 4.0 → Gemini) |
| **오디오 형식** | AIFF (AVSpeechSynthesizer 기본) → 필요 시 ffmpeg로 MP3 변환 |
| **저장 위치** | `~/Documents/TubeKeep/Podcasts/{videoId}/` |
| **DB 연동** | 기존 `podcast_path` 컬럼 활용 |

---

## 아키텍처

```
┌─────────────────────────────────────────────────────────┐
│                    PodcastService                        │
│  1. 대화 스크립트 생성 (LLM API)                         │
│  2. TTS 변환 (AVSpeechSynthesizer)                      │
│  3. 오디오 파일 저장                                     │
│  4. DB 업데이트 (podcast_path)                           │
└─────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
┌─────────────────────┐    ┌─────────────────────────────┐
│  SummarizationService│    │  AVSpeechSynthesizer        │
│  (OpenRouter 등)     │    │  - 한국어 음성 선택           │
│  → 대화 스크립트 생성  │    │  - 속도 조절 (0.8~1.2x)     │
└─────────────────────┘    │  - 파일 저장 (.aiff)         │
                           └─────────────────────────────┘
```

---

## 구현 단계

### T-520: PodcastService.swift 생성

**파일**: `Sources/TubeKeep/Services/PodcastService.swift`

```swift
actor PodcastService {
    static let shared = PodcastService()
    
    // 대화 스크립트 생성
    func generatePodcastScript(
        transcript: String,
        title: String,
        channel: String
    ) async throws -> PodcastScript
    
    // TTS 변환
    func synthesizeAudio(
        script: PodcastScript,
        outputDir: String
    ) async throws -> String
    
    // 전체 파이프라인
    func generatePodcast(
        videoId: String,
        title: String,
        channel: String,
        transcript: String
    ) async throws -> PodcastResult
}
```

**모델**:
```swift
struct PodcastScript: Codable, Equatable {
    let segments: [PodcastSegment]
}

struct PodcastSegment: Codable, Equatable {
    let speaker: String      // "진행자A", "진행자B"
    let text: String
    let timestamp: TimeInterval?
}

struct PodcastResult: Equatable {
    let audioPath: String
    let script: PodcastScript
    let duration: TimeInterval
}
```

### T-521: AI 대화 스크립트 생성 프롬프트

기존 SummarizationService의 LLM API를 활용하여 대화 스크립트 생성.

**프롬프트 설계**:
```
당신은 YouTube 영상을 기반으로 팟캐스트 대화 스크립트를 작성하는 전문가입니다.
반드시 한국어로만 답변하세요. 영어 사용 금지.

영상 제목: {title}
채널: {channel}

아래 트랜스크립트를 분석하여 2인 팟캐스트 대화를 작성하세요.

규칙:
1. 진행자A(남성)와 진행자B(여성)가 대화
2. 영상의 핵심 내용을 자연스럽게 대화形式으로 전달
3. 각 대사는 1~3문장으로 간결하게
4. 총 15~25개 세그먼트
5. 타임스탬프는 불필요

출력 형식 (JSON 배열):
[
  {"speaker": "진행자A", "text": "안녕하세요, 오늘은..."},
  {"speaker": "진행자B", "text": "네, 정말 흥미로운 내용이네요."}
]

트랜스크립트:
{transcript}
```

### T-522: TTS 연동 (macOS 내장)

**AVSpeechSynthesizer 사용법**:
```swift
import AVFoundation

class TTSService {
    private let synthesizer = AVSpeechSynthesizer()
    
    // 한국어 음성 선택
    private var koreanVoice: AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice(language: "ko-KR")
    }
    
    // 파일로 저장
    func synthesizeToFile(
        text: String,
        outputPath: String,
        rate: Float = AVSpeechUtteranceDefaultSpeechRate
    ) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = koreanVoice
        utterance.rate = rate
        
        // 파일 URL
        let fileURL = URL(fileURLWithPath: outputPath)
        
        // 파일 저장
        synthesizer.write(to: fileURL) { utterance in
            // 완료
        }
    }
}
```

**음성 선택 옵션**:
- `ko-KR` — 한국어 (기본)
- 음성별 레이블: "Yuna", "Siwoo" 등 (시스템에 설치된 음성에 따라 다름)
- 속도: 0.8 (느림) ~ 1.2 (빠름), 기본값 1.0

### T-523: 오디오 파일 저장 로직

**저장 경로**: `~/Documents/TubeKeep/Podcasts/{videoId}/`
- `{videoId}_script.json` — 대화 스크립트
- `{videoId}_full.aiff` — 전체 팟캐스트 오디오
- `{videoId}_seg_001.aiff` — 세그먼트별 오디오 (선택적)

**파일 정리**:
- 팟캐스트 삭제 시 디렉토리 전체 삭제
- 디스크 사용량 계산에 포함

### T-524: DB에 podcast_path 저장

기존 `DatabaseManager.updatePodcastPath()` 메서드 추가:
```swift
func updatePodcastPath(videoId: String, podcastPath: String?) {
    // UPDATE video_ai_data SET podcast_path = ? WHERE video_id = ?
}
```

### T-525: 팟캐스트 재생 UI

**요약 팝업에 팟캐스트 컨트롤 추가**:
```
┌─────────────────────────────────────┐
│  AI 요약정보 보기           [복사] [🔄] │
├─────────────────────────────────────┤
│  개요: ...                          │
│  핵심 포인트:                        │
│  • ...                              │
│  챕터:                              │
│  • [0:00 - 2:30] 제목               │
├─────────────────────────────────────┤
│  🎙️ AI 팟캐스트                     │
│  [▶ 재생] [⏸ 일시정지] [⏹ 정지]     │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
│  00:00 ━━━━━━━●━━━━━━━━━━ 03:45    │
└─────────────────────────────────────┘
```

**상태 관리**:
- `LibraryReducer`에 팟캐스트 관련 State/Action 추가
- `podcastLoading`, `podcastGenerating`, `podcastPlaying`, `podcastProgress`

### T-526: 팟캐스트 파일 정리

- 팟캐스트 삭제: `DatabaseManager.updatePodcastPath(videoId: nil)`
- 디렉토리 삭제: `FileManager.default.removeItem(atPath:)`
- 디스크 사용량 재계산

### T-527: Info.plist 버전 2.5.2

---

## State/Action 설계

### LibraryReducer 추가 State
```swift
// 팟캐스트 (v2.5.2)
var podcastGeneratingIds: Set<String> = []
var podcastPlayingId: String?
var podcastError: String?
var podcastAvailableIds: Set<String> = []  // 팟캐스트 보유 영상 추적
```

### LibraryReducer 추가 Action
```swift
// 팟캐스트 (v2.5.2)
case generatePodcast(String)           // 팟캐스트 생성 시작 + 요약 팝업 열기
case podcastGenerated(String, PodcastResult)  // 생성 완료
case podcastGenerationFailed(String, String)  // 생성 실패
case playPodcast(String)               // 재생 시작
case stopPodcast                       // 정지
case deletePodcast(String)             // 삭제
```

### LibraryReducer 추가 메서드
```swift
static func hasPodcast(for videoId: String) -> Bool  // 팟캐스트 존재 여부 확인
```

---

## UI 통합

### 컨텍스트 메뉴
기존 "AI 요약정보 보기" 아래에 추가:
```
🎙️ AI 팟캐스트 만들기
🔊 AI 팟캐스트 듣기  (podcastPath가 있을 때만)
🗑️ AI 팟캐스트 삭제  (podcastPath가 있을 때만)
```

### 요약 팝업
기존 요약 결과 하단에 팟캐스트 컨트롤 추가:
- 팟캐스트 없으면: "팟캐스트 생성" 버튼
- 팟캐스트 있으면: 재생 컨트롤 + 재생 바

---

## 테스트 계획

| TC | 테스트명 | 내용 |
|----|---------|------|
| TC-01 | 팟캐스트 생성 | 자막이 있는 영상 → 대화 스크립트 생성 → TTS 변환 → 오디오 파일 확인 |
| TC-02 | 팟캐스트 재생 | 생성된 팟캐스트 → 재생/일시정지/정지 동작 확인 |
| TC-03 | 팟캐스트 삭제 | 팟캐스트 삭제 → DB + 파일시스템에서 제거 확인 |
| TC-04 | 컨텍스트 메뉴 | 우클릭 → 팟캐스트 생성/듣기/삭제 메뉴 표시 확인 |
| TC-05 | 요약 팝업 | 요약 팝업 하단에 팟캐스트 컨트롤 표시 확인 |
| TC-06 | 에러 처리 | 자막 없음 → 적절한 에러 메시지 표시 |
| TC-07 | 한국어 TTS | 한국어 음성으로 자연스러운 발음 확인 |
| TC-08 | 디스크 사용량 | 팟캐스트 생성/삭제 시 디스크 사용량 갱신 확인 |

---

## 참조

- `SummarizationService.swift:384-409` — 기존 요약 프롬프트 패턴
- `DatabaseManager.swift:63` — `podcast_path` 컬럼
- `DatabaseManager.swift:424` — `VideoAIData.podcastPath`
- `MainView.swift:187-257` — 요약 팝업 UI 패턴
- `LibraryGridView.swift` — 컨텍스트 메뉴 패턴
