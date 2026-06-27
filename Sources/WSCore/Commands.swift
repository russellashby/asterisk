import Foundation

/// A WordStar editor command resolved from a prefix + key. Pure data so the
/// key→command mapping is unit-testable independently of AppKit.
public enum EditorCommand: Equatable {
    // ^K block menu
    case markBlockBegin, markBlockEnd
    case copyBlock, moveBlock, deleteBlock, hideBlock
    // ^Q quick menu
    case lineStart, lineEnd, docStart, docEnd
    case toBlockBegin, toBlockEnd
    case deleteToLineEnd
    case find, findReplace
}

/// Resolve a key pressed after the ^K (block) prefix.
public func resolveBlockCommand(_ key: Character) -> EditorCommand? {
    switch wsLower(key) {
    case "b": return .markBlockBegin
    case "k": return .markBlockEnd
    case "c": return .copyBlock
    case "v": return .moveBlock
    case "y": return .deleteBlock
    case "h": return .hideBlock
    default:  return nil
    }
}

/// Resolve a key pressed after the ^Q (quick) prefix.
public func resolveQuickCommand(_ key: Character) -> EditorCommand? {
    switch wsLower(key) {
    case "s": return .lineStart
    case "d": return .lineEnd
    case "r": return .docStart
    case "c": return .docEnd
    case "b": return .toBlockBegin
    case "k": return .toBlockEnd
    case "y": return .deleteToLineEnd
    case "f": return .find
    case "a": return .findReplace
    default:  return nil
    }
}

/// Lowercase a single Character (Character.lowercased() returns a String).
func wsLower(_ c: Character) -> Character {
    c.lowercased().first ?? c
}
