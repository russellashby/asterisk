import Foundation

// Minimal XCTest-free assertion harness (CLT has no XCTest).
var failures = 0

func check(_ cond: Bool, _ msg: String, line: UInt = #line) {
    if !cond { failures += 1; print("  FAIL [line \(line)]: \(msg)") }
}

func eq<T: Equatable>(_ a: T, _ b: T, _ msg: String, line: UInt = #line) {
    if a != b {
        failures += 1
        print("  FAIL [line \(line)]: \(msg) — got \(a), expected \(b)")
    }
}

print("PieceTable tests…")
runPieceTableTests()
print("Document tests…")
runDocumentTests()
print("Command / block / find / undo tests…")
runCommandTests()
print("Formatting / dot-command tests…")
runFormattingTests()
print("Margin / pagination tests…")
runMarginTests()
print("Justification tests…")
runJustifyTests()
print("File I/O round-trip tests…")
runIOTests()

if failures == 0 {
    print("\nAll tests passed ✓")
    exit(0)
} else {
    print("\n\(failures) failure(s) ✗")
    exit(1)
}
