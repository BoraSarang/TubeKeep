import SwiftUI

struct SubtitleOverlay: View {
    let cues: [SubtitleCue]
    let currentTime: Double

    private var fixedCues: [SubtitleCue] {
        guard !cues.isEmpty else { return [] }
        var fixed = cues
        for i in 0..<(fixed.count - 1) {
            if fixed[i].endTime > fixed[i + 1].startTime {
                fixed[i] = SubtitleCue(startTime: fixed[i].startTime, endTime: fixed[i + 1].startTime, text: fixed[i].text)
            }
        }
        fixed[fixed.count - 1] = SubtitleCue(startTime: fixed.last!.startTime, endTime: .greatestFiniteMagnitude, text: fixed.last!.text)
        return fixed
    }

    private var activeCue: SubtitleCue? {
        fixedCues.first { $0.startTime <= currentTime && $0.endTime >= currentTime && !$0.text.isEmpty }
    }

    var body: some View {
        VStack {
            Spacer()
            if let cue = activeCue {
                Text(cue.text)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(10)
                    .padding(.bottom, 50)
                    .transition(.opacity.animation(.easeInOut(duration: 0.15)))
            }
        }
    }
}
