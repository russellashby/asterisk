import Foundation

// WordStar layout defaults (1-based columns). lm/rm default to the document's
// wrap region; the page model below drives automatic pagination.
let kDefaultPageLength   = 66   // .pl — total lines per physical page
let kDefaultMarginTop    = 3    // .mt — blank lines reserved at the top
let kDefaultMarginBottom = 3    // .mb — blank lines reserved at the bottom
let kMaxColumns          = 80   // hard ceiling for .rm (matches the 80-col grid)

/// A parsed WordStar dot command. Only the field(s) named by the command are
/// set; everything else stays nil/false. A command affects the *following*
/// text (region-based), except `.pa` which requests a break before the next line.
struct DotDirective: Equatable {
    var lm: Int?
    var rm: Int?
    var pa: Bool = false
    var pl: Int?
    var mt: Int?
    var mb: Int?
}

/// Parse a logical line as a recognised WordStar dot command, or return nil if
/// it isn't one (the line may still be a dot line that's displayed dimmed but
/// has no layout effect). Commands are two letters, case-insensitive, an
/// optional space, then an integer argument (`.pa` takes none).
func parseDot(_ chars: ArraySlice<Character>) -> DotDirective? {
    let arr = Array(chars)
    guard arr.count >= 3, arr[0] == "." else { return nil }
    let c1 = wsLower(arr[1]), c2 = wsLower(arr[2])

    // Integer argument following the 2-letter command (allows a leading space
    // and an optional minus sign); nil if no digits are present.
    func intArg() -> Int? {
        var i = 3
        while i < arr.count, arr[i] == " " { i += 1 }
        var sign = 1
        if i < arr.count, arr[i] == "-" { sign = -1; i += 1 }
        var value = 0, sawDigit = false
        while i < arr.count, arr[i].isASCII, arr[i].isNumber,
              let d = arr[i].wholeNumberValue {
            value = value * 10 + d; i += 1; sawDigit = true
        }
        return sawDigit ? sign * value : nil
    }

    switch (c1, c2) {
    case ("l", "m"): if let n = intArg() { return DotDirective(lm: n) }
    case ("r", "m"): if let n = intArg() { return DotDirective(rm: n) }
    case ("p", "a"): return DotDirective(pa: true)
    case ("p", "l"): if let n = intArg() { return DotDirective(pl: n) }
    case ("m", "t"): if let n = intArg() { return DotDirective(mt: n) }
    case ("m", "b"): if let n = intArg() { return DotDirective(mb: n) }
    default: break
    }
    return nil
}
