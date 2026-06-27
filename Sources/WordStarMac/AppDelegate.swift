import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenu()

        let frame = NSRect(x: 0, y: 0, width: 760, height: 560)
        window = NSWindow(contentRect: frame,
                          styleMask: [.titled, .closable, .miniaturizable, .resizable],
                          backing: .buffered,
                          defer: false)
        window.title = "WordStar — UNTITLED.WS"

        let editor = EditorView(frame: frame)
        window.contentView = editor
        window.minSize = NSSize(width: editor.preferredContentWidth, height: 320)

        window.center()
        window.makeFirstResponder(editor)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    private func setupMenu() {
        let mainMenu = NSMenu()

        // Application menu
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About WordStar", action: nil, keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit WordStar",
                        action: #selector(NSApplication.terminate(_:)),
                        keyEquivalent: "q")
        appItem.submenu = appMenu

        // File menu
        let fileItem = NSMenuItem()
        mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "File")
        addItem(fileMenu, "New  (^KN)", #selector(EditorView.wsNew(_:)), "n")
        addItem(fileMenu, "Open…  (^KR)", #selector(EditorView.wsOpen(_:)), "o")
        fileMenu.addItem(.separator())
        addItem(fileMenu, "Save  (^KS)", #selector(EditorView.wsSave(_:)), "s")
        let saveAs = NSMenuItem(title: "Save As…", action: #selector(EditorView.wsSaveAs(_:)), keyEquivalent: "S")
        saveAs.keyEquivalentModifierMask = [.command, .shift]
        saveAs.target = nil
        fileMenu.addItem(saveAs)
        fileItem.submenu = fileMenu

        // Edit menu — native keys mirroring WordStar commands (WS keys shown).
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        addItem(editMenu, "Undo  (^U)", #selector(EditorView.wsUndo(_:)), "z")
        addItem(editMenu, "Redo", #selector(EditorView.wsRedo(_:)), "Z")
        editMenu.addItem(.separator())
        addItem(editMenu, "Find…  (^QF)", #selector(EditorView.wsFind(_:)), "f")
        addItem(editMenu, "Find Next  (^L)", #selector(EditorView.wsFindNext(_:)), "g")
        addItem(editMenu, "Replace…  (^QA)", #selector(EditorView.wsReplace(_:)), "r")
        editItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    /// Add a first-responder-targeted menu item (target nil walks the responder
    /// chain to the focused EditorView).
    private func addItem(_ menu: NSMenu, _ title: String, _ action: Selector, _ key: String) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = nil
        menu.addItem(item)
    }
}
