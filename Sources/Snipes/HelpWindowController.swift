import AppKit

@MainActor
final class HelpWindowController: NSWindowController {
    private static var shared: HelpWindowController?

    static func show() {
        if let shared, shared.window?.isVisible == true {
            shared.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let controller = HelpWindowController()
        shared = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    init() {
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false

        let textView = NSTextView()
        textView.isEditable = false
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 20, height: 20)
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        textView.textStorage?.setAttributedString(HelpDocument.attributedText)

        scroll.documentView = textView

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 620, height: 560))
        scroll.frame = container.bounds
        scroll.autoresizingMask = [.width, .height]
        container.addSubview(scroll)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 560),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Snipes Help"
        window.minSize = NSSize(width: 480, height: 360)
        window.contentView = container
        window.backgroundColor = NSColor(calibratedRed: 0.03, green: 0.11, blue: 0.055, alpha: 1)
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }
}

// MARK: - Help content

@MainActor
enum HelpDocument {
    private static let green = NSColor(calibratedRed: 0.36, green: 1, blue: 0.48, alpha: 1)
    private static let body = NSColor(calibratedRed: 0.53, green: 0.8, blue: 0.6, alpha: 1)
    private static let muted = NSColor(calibratedRed: 0.42, green: 0.67, blue: 0.48, alpha: 1)

    static var attributedText: NSAttributedString {
        if let loaded = loadFromBundle() {
            return styledMarkdown(loaded)
        }
        return styledMarkdown(fallbackText)
    }

    private static func loadFromBundle() -> String? {
        guard let url = Bundle.main.url(forResource: "HELP", withExtension: "md"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }
        return text
    }

    private static func styledMarkdown(_ source: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let bodyFont = NSFont.systemFont(ofSize: 13)
        let h1Font = NSFont.systemFont(ofSize: 22, weight: .bold)
        let h2Font = NSFont.systemFont(ofSize: 15, weight: .semibold)
        let monoFont = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)

        let paragraphs = source.components(separatedBy: "\n")
        var inTable = false

        for (index, line) in paragraphs.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                if inTable { inTable = false }
                result.append(NSAttributedString(string: "\n", attributes: bodyAttrs(bodyFont)))
                continue
            }

            if trimmed == "---" {
                result.append(NSAttributedString(string: "\n", attributes: bodyAttrs(bodyFont)))
                continue
            }

            if trimmed.hasPrefix("# ") {
                appendBlock(result, String(trimmed.dropFirst(2)), font: h1Font, color: green, spacing: 10)
                continue
            }

            if trimmed.hasPrefix("## ") {
                appendBlock(result, String(trimmed.dropFirst(3)), font: h2Font, color: green, spacing: 8)
                continue
            }

            if trimmed.hasPrefix("| ") && trimmed.contains("|") {
                inTable = true
                let cells = trimmed.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
                if cells.allSatisfy({ $0.contains("---") }) { continue }
                let row = cells.joined(separator: "    ")
                let font = cells.first?.contains("**") == true ? monoFont : bodyFont
                let cleaned = row.replacingOccurrences(of: "**", with: "")
                appendBlock(result, cleaned, font: font, color: body, spacing: 2)
                continue
            }

            if trimmed.hasPrefix("- ") {
                let item = "• " + String(trimmed.dropFirst(2)).replacingOccurrences(of: "**", with: "")
                appendBlock(result, item, font: bodyFont, color: body, spacing: 3)
                continue
            }

            if let dot = trimmed.firstIndex(of: "."),
               dot > trimmed.startIndex,
               trimmed[trimmed.index(after: dot)...].first == " ",
               trimmed[..<dot].allSatisfy(\.isNumber) {
                let item = trimmed.replacingOccurrences(of: "**", with: "")
                appendBlock(result, item, font: bodyFont, color: body, spacing: 3)
                continue
            }

            let plain = trimmed.replacingOccurrences(of: "**", with: "")
            appendBlock(result, plain, font: bodyFont, color: muted, spacing: 4)

            if index == paragraphs.count - 1 { continue }
        }

        let style = NSMutableParagraphStyle()
        style.lineSpacing = 2
        result.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: result.length))
        return result
    }

    private static func bodyAttrs(_ font: NSFont) -> [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: body]
    }

    private static func appendBlock(
        _ result: NSMutableAttributedString,
        _ text: String,
        font: NSFont,
        color: NSColor,
        spacing: CGFloat
    ) {
        let para = NSMutableParagraphStyle()
        para.paragraphSpacing = spacing
        result.append(NSAttributedString(
            string: text + "\n",
            attributes: [.font: font, .foregroundColor: color, .paragraphStyle: para]
        ))
    }

    private static let fallbackText = """
    # Snipes Help

    Press ⌘? anytime to reopen this guide. Full documentation is in docs/HELP.md.
    """
}