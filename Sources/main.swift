import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var controller: TranslateWindowController?
    private let themeMenu = NSMenu(title: L("Appearance"))

    func applicationDidFinishLaunching(_ note: Notification) {
        NSApp.mainMenu = buildMenu()
        showWindow(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { showWindow(nil) }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    @objc private func showWindow(_ sender: Any?) {
        if controller == nil {
            controller = TranslateWindowController()
            controller?.load(TranslateWindowController.home)
        }
        controller?.showWindow(nil)
        NSApp.activate()
    }

    // MARK: Меню

    private func buildMenu() -> NSMenu {
        let main = NSMenu()

        let app = submenu(main, "Translate Desktop")
        app.addItem(withTitle: L("About Translate Desktop"),
                    action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: L("Hide Translate Desktop"), action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let others = app.addItem(withTitle: L("Hide Others"),
                                 action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        others.keyEquivalentModifierMask = [.command, .option]
        app.addItem(withTitle: L("Show All"), action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        app.addItem(.separator())
        app.addItem(withTitle: L("Quit Translate Desktop"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        let file = submenu(main, L("File"))
        file.addItem(withTitle: L("Translator Window"), action: #selector(showWindow(_:)), keyEquivalent: "n").target = self
        file.addItem(withTitle: L("Close Window"), action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let edit = submenu(main, L("Edit"))
        edit.addItem(withTitle: L("Undo"), action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: L("Redo"), action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: L("Cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: L("Copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: L("Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: L("Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let view = submenu(main, L("View"))
        view.addItem(withTitle: L("Reload"), action: #selector(TranslateWindowController.reload(_:)), keyEquivalent: "r")
        view.addItem(.separator())
        view.addItem(withTitle: L("Zoom In"), action: #selector(TranslateWindowController.zoomIn(_:)), keyEquivalent: "+")
        // ⌘= — то же, что ⌘+, как в браузерах: на клавиатуре «+» — это Shift и «=».
        let zoomIn = view.addItem(withTitle: L("Zoom In"), action: #selector(TranslateWindowController.zoomIn(_:)), keyEquivalent: "=")
        zoomIn.isHidden = true
        zoomIn.allowsKeyEquivalentWhenHidden = true
        view.addItem(withTitle: L("Zoom Out"), action: #selector(TranslateWindowController.zoomOut(_:)), keyEquivalent: "-")
        view.addItem(withTitle: L("Actual Size"), action: #selector(TranslateWindowController.actualSize(_:)), keyEquivalent: "0")
        view.addItem(.separator())
        let full = view.addItem(withTitle: L("Enter Full Screen"), action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        full.keyEquivalentModifierMask = [.command, .control]

        main.addItem(withTitle: L("Appearance"), action: nil, keyEquivalent: "").submenu = themeMenu
        themeMenu.delegate = self

        let window = submenu(main, L("Window"))
        window.addItem(withTitle: L("Minimize"), action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        window.addItem(withTitle: L("Zoom"), action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        window.addItem(.separator())
        window.addItem(withTitle: L("Bring All to Front"), action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        NSApp.windowsMenu = window
        return main
    }

    private func submenu(_ main: NSMenu, _ title: String) -> NSMenu {
        let menu = NSMenu(title: title)
        main.addItem(withTitle: title, action: nil, keyEquivalent: "").submenu = menu
        return menu
    }

    /// Меню «Оформление» собирается заново при каждом открытии — отмечен текущий выбор.
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === themeMenu else { return }
        menu.removeAllItems()
        for (theme, title) in [(Theme.system, L("Auto")), (.light, L("Light")), (.dark, L("Dark"))] {
            let item = menu.addItem(withTitle: title, action: #selector(chooseTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = theme.rawValue
            item.state = Theme.current == theme ? .on : .off
        }
    }

    @objc private func chooseTheme(_ sender: NSMenuItem) {
        Theme.current = Theme(rawValue: sender.representedObject as? String ?? "") ?? .system
        controller?.applyTheme()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
