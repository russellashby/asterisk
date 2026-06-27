import Foundation

/// On-screen character attributes carried by WordStar inline print-control
/// toggles embedded in the text.
public struct TextAttrs: Equatable {
    public var bold = false
    public var underline = false
    public var italic = false
    public init() {}

    public mutating func toggle(_ f: Format) {
        switch f {
        case .bold:      bold.toggle()
        case .underline: underline.toggle()
        case .italic:    italic.toggle()
        }
    }
}

public enum Format: Equatable { case bold, underline, italic }

// WordStar-style control bytes embedded in the document (entered via ^P).
public let kFormatBold: Character      = "\u{02}"   // ^B
public let kFormatUnderline: Character = "\u{13}"   // ^S
public let kFormatItalic: Character    = "\u{19}"   // ^Y

public func formatControlChar(_ f: Format) -> Character {
    switch f {
    case .bold:      return kFormatBold
    case .underline: return kFormatUnderline
    case .italic:    return kFormatItalic
    }
}

/// If `ch` is an inline format-toggle control byte, which attribute it flips.
public func formatToggled(by ch: Character) -> Format? {
    switch ch {
    case kFormatBold:      return .bold
    case kFormatUnderline: return .underline
    case kFormatItalic:    return .italic
    default:               return nil
    }
}

/// The on-screen marker letter shown (highlighted) in place of a control byte.
public func formatMarkerLetter(_ ch: Character) -> Character? {
    switch ch {
    case kFormatBold:      return "B"
    case kFormatUnderline: return "S"
    case kFormatItalic:    return "Y"
    default:               return nil
    }
}
