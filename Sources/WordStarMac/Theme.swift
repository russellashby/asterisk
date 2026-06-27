import AppKit

/// Palette for the authentic text-mode screen. Colours are role-based so the
/// cell grid can stay Equatable (cells store a role, not an NSColor).
struct Theme {
    var textBG: NSColor
    var textFG: NSColor
    var statusBG: NSColor
    var statusFG: NSColor
    var rulerFG: NSColor
    var border: NSColor   // the letter-box surround outside the 80-col grid
    var cursor: NSColor

    /// Build a single-phosphor monochrome palette (e.g. amber/green CRT): one
    /// colour on near-black, with the status bar as inverse and the ruler dimmed.
    static func monochrome(_ phosphor: NSColor, glow: NSColor? = nil) -> Theme {
        let bg = NSColor(srgbRed: 0.02, green: 0.015, blue: 0.0, alpha: 1)
        return Theme(
            textBG:   bg,
            textFG:   phosphor,
            statusBG: phosphor,                       // status = inverse bar
            statusFG: bg,
            rulerFG:  phosphor.withAlphaComponent(0.45),
            border:   NSColor.black,                  // screen bezel / surround
            cursor:   glow ?? phosphor
        )
    }

    /// Amber phosphor monitor (the classic orange-on-black look).
    static let amber = monochrome(
        NSColor(srgbRed: 1.00, green: 0.69, blue: 0.00, alpha: 1),
        glow: NSColor(srgbRed: 1.00, green: 0.82, blue: 0.32, alpha: 1)
    )

    /// Green phosphor monitor.
    static let green = monochrome(
        NSColor(srgbRed: 0.20, green: 1.00, blue: 0.40, alpha: 1),
        glow: NSColor(srgbRed: 0.60, green: 1.00, blue: 0.70, alpha: 1)
    )

    /// The earlier gray-on-black look with the blue surround.
    static let classic = Theme(
        textBG:   NSColor(srgbRed: 0.00, green: 0.00, blue: 0.00, alpha: 1),
        textFG:   NSColor(srgbRed: 0.82, green: 0.82, blue: 0.82, alpha: 1),
        statusBG: NSColor(srgbRed: 0.78, green: 0.78, blue: 0.78, alpha: 1),
        statusFG: NSColor(srgbRed: 0.00, green: 0.00, blue: 0.00, alpha: 1),
        rulerFG:  NSColor(srgbRed: 0.45, green: 0.45, blue: 0.45, alpha: 1),
        border:   NSColor(srgbRed: 0.00, green: 0.00, blue: 0.45, alpha: 1),
        cursor:   NSColor(srgbRed: 0.95, green: 0.80, blue: 0.20, alpha: 1)
    )
}
