import SwiftUI
import AppKit

struct AppSearchField: View {
    let placeholder: String
    @Binding var text: String
    var isSearching: Bool = false
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 6) {
            NativeSearchField(placeholder: placeholder, text: $text, onSubmit: onSubmit)
            if isSearching {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }
}

/// macOS 네이티브 NSSearchField 래퍼 — 돋보기/클리어 버튼 내장, 라이트/다크 자동 대응.
private struct NativeSearchField: NSViewRepresentable {
    let placeholder: String
    @Binding var text: String
    var onSubmit: (() -> Void)?

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.handleSubmit)
        field.sendsSearchStringImmediately = true
        return field
    }

    func updateNSView(_ nsView: NSSearchField, context: Context) {
        nsView.placeholderString = placeholder
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: NativeSearchField

        init(_ parent: NativeSearchField) {
            self.parent = parent
        }

        func controlTextDidChange(_ obj: Notification) {
            if let field = obj.object as? NSSearchField {
                parent.text = field.stringValue
            }
        }

        @objc func handleSubmit() {
            parent.onSubmit?()
        }
    }
}