import AppKit

@main
enum SnipesMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = SnipesAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}

@MainActor
final class SnipesAppDelegate: NSObject, NSApplicationDelegate {
    private var windowController: GameWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        windowController = GameWindowController()
        guard let window = windowController?.window else { return }
        windowController?.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func setupMainMenu() {
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Snipes"
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: appName)
        appMenuItem.submenu = appMenu

        let about = NSMenuItem(title: "About \(appName)", action: #selector(showAbout(_:)), keyEquivalent: "")
        about.target = self
        appMenu.addItem(about)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
            .keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let helpMenuItem = NSMenuItem()
        mainMenu.addItem(helpMenuItem)

        let helpMenu = NSMenu(title: "Help")
        helpMenuItem.submenu = helpMenu

        let help = NSMenuItem(title: "\(appName) Help", action: #selector(showHelp(_:)), keyEquivalent: "?")
        help.target = self
        helpMenu.addItem(help)
    }

    @objc private func showHelp(_ sender: Any?) {
        HelpWindowController.show()
    }

    @objc private func showAbout(_ sender: Any?) {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.2.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "3"
        let credits = NSMutableAttributedString()
        credits.append(NSAttributedString(
            string: "Faithful remake of the 1983 Novell classic.\n\n",
            attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)]
        ))
        credits.append(NSAttributedString(
            string: "Original game by SuperSet Software\n(Drew Major, Dale Neibaur, Kyle Powell).\n\n",
            attributes: [.font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)]
        ))
        credits.append(NSAttributedString(
            string: "\(ControlCopy.lineOne)\n\(ControlCopy.lineTwo)",
            attributes: [
                .font: NSFont.monospacedSystemFont(ofSize: NSFont.smallSystemFontSize, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        ))

        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "Snipes",
            .applicationVersion: version,
            .version: "Build \(build)",
            .credits: credits,
        ])
    }
}