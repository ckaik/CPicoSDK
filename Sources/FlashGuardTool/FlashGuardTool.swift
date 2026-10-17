import Foundation

/// Rejects a linked image that reaches BTstack's reserved flash (spec §11.6).
///
/// Usage: `FlashGuardTool <image.elf>`. Exits 0 when the image may be flashed, 1 when it reaches
/// the reserved region, and 2 when the ELF can't be read or checked. FinalizeBinaryPlugin runs it
/// before it writes any flashable artifact.
@main
struct FlashGuardTool {
    static func main() {
        let arguments = CommandLine.arguments.dropFirst()
        guard arguments.count == 1, let elfPath = arguments.first else {
            fail("usage: FlashGuardTool <image.elf>", status: 2)
        }

        let verdict: BTstackFlashGuard.Verdict
        do {
            let elf = try Data(contentsOf: URL(fileURLWithPath: elfPath))
            verdict = try BTstackFlashGuard.inspect(elf: elf)
        } catch {
            fail("BTstack flash guard can't check \(elfPath): \(error)", status: 2)
        }

        if let rejection = verdict.rejection {
            fail(rejection, status: 1)
        }

        if case .clear(let flashLoadEnd, let reserved) = verdict {
            print("[CPicoSDK] BTstack flash guard: \(reserved.lowerBound - flashLoadEnd) bytes free below the reserved flash bank.")
        }
    }

    private static func fail(_ message: String, status: Int32) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(status)
    }
}
