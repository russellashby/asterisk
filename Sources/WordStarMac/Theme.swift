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

    /// A faithful WordStar-ish monochrome-on-black look with the iconic blue surround.
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
