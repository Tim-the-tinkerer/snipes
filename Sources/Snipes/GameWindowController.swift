import AppKit

@MainActor
final class GameWindowController: NSWindowController {
    let engine = GameEngine()
    private let gameView = TopDownView()
    private let menuPanel = MenuPanelView()
    private var eventMonitor: Any?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Snipes"
        window.minSize = NSSize(width: 640, height: 480)
        window.isReleasedWhenClosed = false
        window.center()

        let container = NSView(frame: NSRect(x: 0, y: 0, width: 960, height: 640))
        container.autoresizingMask = [.width, .height]
        window.contentView = container

        gameView.frame = container.bounds
        gameView.autoresizingMask = [.width, .height]
        gameView.engine = engine
        container.addSubview(gameView)

        menuPanel.engine = engine
        menuPanel.frame = container.bounds
        menuPanel.autoresizingMask = [.width, .height]
        container.addSubview(menuPanel)

        super.init(window: window)
        menuPanel.onEnterGame = { [weak self] in self?.focusGame() }
        menuPanel.onDismiss = { [weak self] in self?.focusGame() }
        installInputMonitor()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    deinit {
        if let eventMonitor { NSEvent.removeMonitor(eventMonitor) }
    }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
        focusGame()
    }

    private func focusGame() {
        window?.makeFirstResponder(gameView)
    }

    private func installInputMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            guard let self else { return event }
            return self.handleKey(event)
        }
    }

    private func handleKey(_ event: NSEvent) -> NSEvent? {
        if event.modifierFlags.contains(.command) {
            return event
        }

        switch event.type {
        case .keyDown:
            if event.isARepeat { return nil }
            if event.keyCode == 35 {
                if engine.phase == .playing {
                    engine.togglePause()
                    menuPanel.refresh()
                }
                return nil
            }
            if event.keyCode == 46 {
                AudioManager.shared.toggleEnabled()
                menuPanel.refresh()
                return nil
            }
            if event.keyCode == 45 {
                AudioManager.shared.cycleMusicMode()
                menuPanel.refresh()
                return nil
            }
            if event.keyCode == 8 {
                engine.toggleCRT()
                menuPanel.refresh()
                return nil
            }
            guard engine.phase == .playing, !engine.paused else { return event }
            engine.keysDown.insert(event.keyCode)
            engine.pressKey(event.keyCode)
            if event.keyCode == 15 { engine.restartLevel() }
            return nil

        case .keyUp:
            engine.keysDown.remove(event.keyCode)
            return nil

        default:
            return event
        }
    }
}

// MARK: - Menu

@MainActor
final class MenuPanelView: NSView {
    weak var engine: GameEngine?
    var onEnterGame: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let mainPanel = NSView()
    private let gameOverPanel = NSView()
    private let clearedPanel = NSView()
    private var levelButtons: [NSButton] = []
    private var letterLabel = NSTextField(labelWithString: "A")
    private var summaryLabel = NSTextField(labelWithString: "")
    private var bestLabel = NSTextField(labelWithString: "")
    private var crtButton = NSButton()
    private var musicButton = NSButton()
    private var refreshTimer: Timer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        buildUI()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    private func buildUI() {
        for panel in [mainPanel, gameOverPanel, clearedPanel] {
            panel.wantsLayer = true
            panel.layer?.backgroundColor = NSColor(calibratedRed: 0.03, green: 0.11, blue: 0.055, alpha: 0.94).cgColor
            panel.layer?.cornerRadius = 12
            panel.layer?.borderWidth = 1
            panel.layer?.borderColor = NSColor(calibratedRed: 0.24, green: 1, blue: 0.48, alpha: 0.4).cgColor
            addSubview(panel)
        }
        buildMainMenu()
        buildEndPanel(gameOverPanel, title: "GAME OVER", tag: 300, action: #selector(backToMenu))
        buildEndPanel(clearedPanel, title: "MAZE CLEARED", tag: 301, action: #selector(nextLevel), button: "NEXT LEVEL")
    }

    override func layout() {
        super.layout()
        let w: CGFloat = 520
        mainPanel.frame = NSRect(x: (bounds.width - w) / 2, y: (bounds.height - 520) / 2, width: w, height: 520)
        for panel in [gameOverPanel, clearedPanel] {
            panel.frame = NSRect(x: (bounds.width - 400) / 2, y: (bounds.height - 240) / 2, width: 400, height: 240)
        }
    }

    func refresh() {
        guard let engine else { return }
        isHidden = false
        mainPanel.isHidden = engine.phase != .menu
        gameOverPanel.isHidden = engine.phase != .gameOver
        clearedPanel.isHidden = engine.phase != .levelCleared
        if engine.phase == .playing { isHidden = true }

        letterLabel.stringValue = String(engine.letter)
        summaryLabel.stringValue = engine.levelSummary
        for b in levelButtons {
            let on = b.tag == engine.number
            b.layer?.backgroundColor = (on
                ? NSColor(calibratedRed: 0.24, green: 1, blue: 0.42, alpha: 1)
                : NSColor(calibratedRed: 0.24, green: 1, blue: 0.48, alpha: 0.15)).cgColor
        }
        if let score = gameOverPanel.viewWithTag(300) as? NSTextField {
            score.stringValue = "Score: \(engine.score)"
        }
        if let note = gameOverPanel.viewWithTag(310) as? NSTextField {
            if engine.newHighScore {
                note.stringValue = "NEW HIGH SCORE"
            } else if let best = HighScores.bestEntry {
                note.stringValue = "BEST \(best.score) · \(best.level)"
            } else {
                note.stringValue = ""
            }
            note.isHidden = note.stringValue.isEmpty
        }
        if let score = clearedPanel.viewWithTag(301) as? NSTextField {
            score.stringValue = "Score: \(engine.score)"
        }
        if let best = HighScores.bestEntry {
            bestLabel.stringValue = "BEST \(best.score) · \(best.level)"
        } else {
            bestLabel.stringValue = ""
        }
        bestLabel.isHidden = bestLabel.stringValue.isEmpty
        crtButton.title = engine.crtEnabled ? "CRT ON" : "CRT OFF"
        musicButton.title = "MUSIC \(AudioManager.shared.musicMode.label)"
    }

    private func buildMainMenu() {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        mainPanel.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: mainPanel.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: mainPanel.centerYAnchor),
        ])

        stack.addArrangedSubview(title("SNIPES", 34))
        stack.addArrangedSubview(caption("Faithful remake of the 1983 Novell classic"))
        stack.addArrangedSubview(caption("Limited view — explore the maze, destroy Snipes and hives"))

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 24

        let diff = NSStackView()
        diff.orientation = .vertical
        diff.addArrangedSubview(caption("DIFFICULTY"))
        let letterRow = NSStackView()
        letterRow.addArrangedSubview(btn("◀", #selector(letterDown)))
        letterLabel.font = .monospacedSystemFont(ofSize: 28, weight: .bold)
        letterLabel.textColor = .init(calibratedRed: 0.36, green: 1, blue: 0.48, alpha: 1)
        letterRow.addArrangedSubview(letterLabel)
        letterRow.addArrangedSubview(btn("▶", #selector(letterUp)))
        diff.addArrangedSubview(letterRow)
        row.addArrangedSubview(diff)

        let lvl = NSStackView()
        lvl.orientation = .vertical
        lvl.addArrangedSubview(caption("LEVEL"))
        let lvlRow = NSStackView()
        levelButtons.removeAll()
        for n in 1...9 {
            let b = btn("\(n)", #selector(pickLevel(_:)))
            b.tag = n
            levelButtons.append(b)
            lvlRow.addArrangedSubview(b)
        }
        lvl.addArrangedSubview(lvlRow)
        row.addArrangedSubview(lvl)
        stack.addArrangedSubview(row)

        summaryLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        summaryLabel.textColor = .init(calibratedRed: 0.53, green: 0.8, blue: 0.6, alpha: 1)
        summaryLabel.maximumNumberOfLines = 2
        summaryLabel.preferredMaxLayoutWidth = 480
        stack.addArrangedSubview(summaryLabel)

        bestLabel.font = .monospacedSystemFont(ofSize: 12, weight: .semibold)
        bestLabel.textColor = .init(calibratedRed: 1, green: 0.82, blue: 0.4, alpha: 1)
        stack.addArrangedSubview(bestLabel)

        stack.addArrangedSubview(caption(ControlCopy.lineOne))
        stack.addArrangedSubview(caption(ControlCopy.lineTwo))

        let optionRow = NSStackView()
        optionRow.orientation = .horizontal
        optionRow.spacing = 10
        crtButton = btn("CRT OFF", #selector(toggleCRT))
        musicButton = btn("MUSIC FULL", #selector(cycleMusic))
        optionRow.addArrangedSubview(crtButton)
        optionRow.addArrangedSubview(musicButton)
        stack.addArrangedSubview(optionRow)

        let enter = btn("ENTER THE MAZE", #selector(enterGame))
        enter.font = .monospacedSystemFont(ofSize: 14, weight: .semibold)
        stack.addArrangedSubview(enter)
    }

    private func buildEndPanel(_ panel: NSView, title text: String, tag: Int, action: Selector, button: String = "BACK TO MENU") {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: panel.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: panel.centerYAnchor),
        ])
        stack.addArrangedSubview(title(text, 26))
        let score = NSTextField(labelWithString: "Score: 0")
        score.tag = tag
        score.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        score.textColor = .init(calibratedRed: 0.42, green: 0.67, blue: 0.48, alpha: 1)
        stack.addArrangedSubview(score)
        if tag == 300 {
            let note = NSTextField(labelWithString: "")
            note.tag = 310
            note.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
            note.textColor = .init(calibratedRed: 1, green: 0.82, blue: 0.4, alpha: 1)
            stack.addArrangedSubview(note)
        }
        stack.addArrangedSubview(btn(button, action))
    }

    @objc private func letterDown() { stepLetter(-1) }
    @objc private func letterUp() { stepLetter(1) }

    private func stepLetter(_ d: Int) {
        guard let engine, let i = GameConstants.letters.firstIndex(of: engine.letter) else { return }
        engine.letter = GameConstants.letters[(i + d + 26) % 26]
        refresh()
    }

    @objc private func pickLevel(_ sender: NSButton) {
        engine?.number = sender.tag
        refresh()
    }

    @objc private func toggleCRT() {
        engine?.toggleCRT()
        refresh()
    }

    @objc private func cycleMusic() {
        AudioManager.shared.cycleMusicMode()
        refresh()
    }

    @objc private func enterGame() {
        engine?.beginGame()
        refresh()
        onEnterGame?()
    }

    @objc private func backToMenu() {
        engine?.restartToMenu()
        refresh()
    }

    @objc private func nextLevel() {
        engine?.nextLevel()
        refresh()
        onDismiss?()
    }

    private func title(_ s: String, _ size: CGFloat) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.font = .monospacedSystemFont(ofSize: size, weight: .bold)
        l.textColor = .init(calibratedRed: 0.36, green: 1, blue: 0.48, alpha: 1)
        return l
    }

    private func caption(_ s: String) -> NSTextField {
        let l = NSTextField(labelWithString: s)
        l.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        l.textColor = .init(calibratedRed: 0.42, green: 0.67, blue: 0.48, alpha: 1)
        return l
    }

    private func btn(_ title: String, _ action: Selector) -> NSButton {
        let b = NSButton(title: title, target: self, action: action)
        b.bezelStyle = .inline
        b.isBordered = false
        b.wantsLayer = true
        b.layer?.cornerRadius = 6
        b.contentTintColor = .init(calibratedRed: 0.36, green: 1, blue: 0.48, alpha: 1)
        b.layer?.backgroundColor = NSColor(calibratedRed: 0.24, green: 1, blue: 0.48, alpha: 0.12).cgColor
        return b
    }
}