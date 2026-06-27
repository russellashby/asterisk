import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.regular)

let delegate = AppDelegate()   // retained for program lifetime
app.delegate = delegate
app.run()
