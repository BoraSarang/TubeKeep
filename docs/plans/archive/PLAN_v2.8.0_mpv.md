# PLAN v2.8.0 — mpv 플레이어 전환 (AVKit → libmpv) ✅ **COMPLETED**

> **버전**: v2.8.0 (build 19)
> **목표**: AVKit 기반 플레이어를 libmpv로 전환하여 AV1/VP9 네이티브 재생
> **특성**: 싱글 유저 앱, Mac App Store 외부 배포 (GitHub Releases)
> **완료일**: 2026-07-31

---

## 개요

### 현재 문제점

```
yt-dlp 다운로드
  → H.264 (mp4)     → AVPlayer 즉시 재생 ✅
  → AV1/VP9 (mkv/webm) → ffmpeg 변환 5~30초 → AVPlayer 재생 ⚠️
  → HLS (m3u8)       → AVPlayer 가능하나 DRM/인증 복잡
```

YouTube가 AV1 비중을 점점 늘리고 있어 변환 병목이 증가하는 추세.
또한 향후 HLS 영상 플레이 기능 추가 시 AVPlayer + DRM 조합의 복잡성이 있음.

### mpv(libmpv) 도입 효과

| 항목 | AVKit (현재) | mpv (도입 후) |
|------|-------------|---------------|
| H.264/HEVC | ✅ | ✅ |
| AV1/VP9 | ❌ 변환 필요 (5~30초) | ✅ **네이티브 재생** |
| HLS (DRM 없음) | ✅ 가능 | ✅ **네이티브** |
| 자막 (ASS/SSA) | 제한적 | ✅ **네이티브 렌더링** |
| HW 디코딩 | Metal | ✅ **Metal (MoltenVK)** |
| ffmpeg 의존성 | 필요 (변환용) | **제거 가능** |
| 번들 크기 증가 | 0MB | ~15MB (MPVKit xcframework) |
| 구현 복잡도 | 낮음 | 중간 (C API 래퍼 필요) |

---

## 사용 라이브러리: MPVKit

| 항목 | 내용 |
|------|------|
| 저장소 | `mpvkit/MPVKit` (LGPL v3.0) |
| 형태 | SPM + xcframework (libmpv + FFmpeg + MoltenVK 등) |
| macOS 버전 | 10.15+ (현재 프로젝트 14.0과 호환) |
| 아키텍처 | ARM64 + x86_64 |
| 라이선스 | LGPL (개인 사용 무관, 재배포 시 LGPL 준수 필요) |

MPVKit은 libmpv + FFmpeg + MoltenVK + libass + LuaJIT 등 30여개 라이브러리를
하나의 xcframework로 묶어 SPM으로 바로 사용할 수 있게 제공한다.

---

## 변경 파일 목록

### 신규 파일 (2개)

| 파일 | 설명 |
|------|------|
| `Features/Player/MPVController.swift` | libmpv C API Swift 래퍼 (재생/일시정지/seek/이벤트) |
| `Features/Player/MPVVideoView.swift` | mpv 렌더링 NSViewRepresentable (Metal 출력) |

### 수정 파일 (6개)

| 파일 | 변경 내용 |
|------|----------|
| `Package.swift` | MPVKit 패키지 의존성 추가 |
| `PlayerReducer.swift` | 변환 관련 State/Action 제거, mpv 이벤트 Action 추가 |
| `PlayerView.swift` | `NSPlayerView` → `MPVVideoView` 교체, 변환 UI 제거 |
| `NSPlayerView.swift` | **삭제** (AVPlayerView → mpv로 대체) |
| `DownloadManager.swift` | H.264 포맷 필터 제거 (`[ext=mp4][vcodec^=avc1]`) |
| `YouTubeDLService.swift` | H.264 포맷 필터 제거 |
| `scripts/build-macos.sh` | MPVKit xcframework 번들 처리 |

---

## 상세 구현

### 1. MPVController.swift — libmpv C API 래퍼

```swift
import MPVKit  // Libmpv 모듈 제공

actor MPVController {
    private var mpv: OpaquePointer?
    
    func create() {
        mpv = mpv_create()
        mpv_set_option_string(mpv, "vo", "libmpv")
        mpv_set_option_string(mpv, "hwdec", "auto-safe")
        mpv_set_option_string(mpv, "gpu-context", "metal")
        mpv_set_option_string(mpv, "keep-open", "yes")
        mpv_set_option_string(mpv, "sub-auto", "all")
        mpv_initialize(mpv)
    }
    
    func load(url: String) { /* mpv_command("loadfile", url) */ }
    func play()     { /* mpv_command("set", "pause", "no") */ }
    func pause()    { /* mpv_command("set", "pause", "yes") */ }
    func seek(sec: Double) { /* mpv_command("seek", sec, "absolute") */ }
    
    func observeProperties() { /* mpv_observe_property */ }
}
```

**필수 관찰 속성:**
- `time-pos` → 현재 재생 시간
- `duration` → 전체 길이  
- `pause` → 재생 상태
- `eof-reached` → 영상 종료
- `sub-text` → 현재 자막 텍스트

### 2. MPVVideoView.swift — 렌더링 NSView

```swift
import SwiftUI
import MPVKit

struct MPVVideoView: NSViewRepresentable {
    let controller: MPVController
    
    func makeNSView(context: Context) -> MPVRenderView {
        let view = MPVRenderView()
        view.controller = controller
        return view
    }
}

class MPVRenderView: NSView {
    var controller: MPVController?
    private var renderContext: OpaquePointer?
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        setupMetalRendering()
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        renderFrame()
    }
}
```

### 3. PlayerReducer 변경

**제거할 State:**
```swift
var isConverting = false
var conversionProgress: Double = 0
var conversionETA: String = ""
```

**제거할 Action:**
```swift
case setConverting(Bool)
case updateConversionProgress(Double)
case updateConversionETA(String)
```

**추가할 Action:**
```swift
case mpvEvent(MPVEvent)
```

**변경: 자막 처리**
- mpv는 자막을 네이티브로 렌더링
- `SubtitleOverlay.swift` → **제거** (mpv 내장 자막으로 대체)
- `SubtitlePanel.swift` → **유지** (타임스탬프 목록 표시용)
- `showSubtitleOverlay` toggle → mpv의 `sub-visibility` 속성 제어로 변경

### 4. PlayerView 변경

**PlayerView.swift 변경 사항:**

```swift
// AS-IS: AVPlayer + NSPlayerView
NSPlayerView(player: player)

// TO-BE: mpv + MPVVideoView
MPVVideoView(controller: mpvController)
```

**제거할 블록 (~130줄):**
- `needsTranscoding()` / `transcodeAndPlay()` / `transcodeCacheKey()` / `getDuration()`
- `codecCache` get/set
- 변환 UI (ProgressView, ETA 텍스트)
- `timeObserver` (AVPlayer → mpv 이벤트로 대체)

### 5. DownloadManager / YouTubeDLService 변경

**제거할 H.264 포맷 필터:**
```swift
// AS-IS: (세 군데 모두)
[ext=mp4][vcodec^=avc1]

// TO-BE: 확장자/코덱 필터 제거
[height<=\(height)] + bestaudio
```

이제 AV1/VP9도 mpv가 네이티브 재생하므로 MP4 강제 변환이 불필요.

### 6. Package.swift 변경

```swift
dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.10.0"),
    .package(url: "https://github.com/mpvkit/MPVKit.git", from: "1.0.0"),
],
targets: [
    .executableTarget(
        name: "TubeKeep",
        dependencies: [
            .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
            .product(name: "MPVKit", package: "MPVKit"),
        ],
```

---

## 제거/단순화되는 코드

| 파일 | 제거되는 코드 | 예상 줄 수 |
|------|-------------|-----------|
| `PlayerView.swift` | transcoding (SHA256, ffmpeg, progress, ETA) | ~130줄 |
| `PlayerView.swift` | codecCache, needsTranscoding | ~50줄 |
| `PlayerReducer.swift` | conversion State/Action | ~30줄 |
| `NSPlayerView.swift` | **파일 전체 삭제** | ~50줄 |
| `SubtitleOverlay.swift` | **파일 삭제** (mpv 내장 자막) | ~40줄 |
| `DownloadManager.swift` | H.264 filter arg | ~10줄 |
| `YouTubeDLService.swift` | H.264 filter arg | ~10줄 |
| **합계** | | **~320줄 제거** |

신규 코드: MPVController + MPVVideoView = ~200줄

→ **순 감소: ~120줄**

---

## 번들 크기 변화

| 구성 요소 | 현재 | 도입 후 | 증감 |
|----------|------|---------|------|
| 앱 바이너리 | ~5MB | ~5MB | - |
| MPVKit xcframework | 0MB | ~15MB | +15MB |
| ffmpeg (번들) | ~15MB | ~15MB (유지) | - |
| **합계** | **~20MB** | **~35MB** | **+15MB** |

ffmpeg은 Whisper 오디오 추출 + yt-dlp post-processing을 위해 유지.

---

## 이슈 및 주의사항

### 1. LuaJIT 크래시 (Mac App Store)
- libmpv가 LuaJIT을 포함 → 샌드박스 환경에서 JIT 차단 → 앱 종료
- **해결**: GitHub Releases 배포 (Mac App Store 외부) → 영향 없음

### 2. Metal 렌더링
- mpv 0.35+는 `gpu-context=metal` 지원
- MPVKit은 MoltenVK (Vulkan→Metal) 사용 → 성능 오버헤드 약간
- **대안**: `vo=libmpv` 소프트웨어 렌더링 → CPU 사용률 증가

### 3. 자막 호환성
- mpv는 ass/ssa/srt/vtt 모두 네이티브 지원
- `SubtitlePanel.swift`는 유지 (데이터는 mpv event에서 추출)
- `SubtitleOverlay.swift`는 제거 (mpv가 직접 렌더링)

### 4. 기존 기능 영향
| 기능 | 영향 |
|------|------|
| Discover 미리보기 | ✅ mpv로 처리 (stream URL 동일) |
| Q&A 타임스탬프 seek | ✅ mpv_command("seek", ...)로 처리 |
| 트랜스코딩 캐시 | ❌ 제거 (더 이상 불필요) |
| Pin (최상위 고정) | ✅ 영향 없음 |
| 전체 화면 | ✅ mpv는 별도 전체화면 처리 필요 |

---

## 구현 순서

```
Step 1: Package.swift에 MPVKit 의존성 추가 + 빌드 확인
Step 2: MPVController.swift — libmpv 기본 API 래퍼
Step 3: MPVVideoView.swift — Metal 렌더링 NSViewRepresentable
Step 4: PlayerView.swift — NSPlayerView → MPVVideoView 교체
Step 5: PlayerReducer.swift — 변환 State/Action 제거
Step 6: DownloadManager/YouTubeDLService — H.264 필터 제거
Step 7: SubtitleOverlay → 제거 (mpv 내장 자막으로 대체)
Step 8: NSPlayerView.swift → 삭제
Step 9: build-macos.sh — MPVKit 번들 처리 확인
Step 10: 전체 테스트 (H.264/AV1/HLS/자막/Discover)
```
