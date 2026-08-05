import SwiftUI

struct SnippetTextView: View {
    let text: String

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(parseSegments().enumerated()), id: \.offset) { _, seg in
                Text(seg.text)
                    .font(.system(size: 10, weight: seg.isMatch ? .semibold : .regular))
                    .foregroundStyle(seg.isMatch ? Color.accentColor : Color.primary)
            }
        }
    }

    private struct Segment {
        let text: String
        let isMatch: Bool
    }

    private func parseSegments() -> [Segment] {
        var segments: [Segment] = []
        var remaining = text
        while let openRange = remaining.range(of: "<b>") {
            let before = remaining[..<openRange.lowerBound]
            if !before.isEmpty { segments.append(Segment(text: String(before), isMatch: false)) }
            let afterOpen = remaining[openRange.upperBound...]
            if let closeRange = afterOpen.range(of: "</b>") {
                let matchText = afterOpen[..<closeRange.lowerBound]
                if !matchText.isEmpty { segments.append(Segment(text: String(matchText), isMatch: true)) }
                remaining = String(afterOpen[closeRange.upperBound...])
            } else {
                remaining = String(afterOpen)
            }
        }
        if !remaining.isEmpty { segments.append(Segment(text: remaining, isMatch: false)) }
        if segments.isEmpty { segments.append(Segment(text: text, isMatch: false)) }
        return segments
    }
}
