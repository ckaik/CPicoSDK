import Foundation

/// Rejects a linked image that reaches BTstack's reserved flash (spec §11.6).
///
/// Usage: `FlashGuardTool <image.elf>`, which exits with an ``ExitStatus``. FinalizeBinaryPlugin
/// runs it before it copies any flashable artifact to the output directory.
@main
struct FlashGuardTool {
    /// What the tool tells FinalizeBinaryPlugin, which mirrors these values as `FlashGuardStatus`:
    /// a plugin can't import an executable target.
    enum ExitStatus: Int32 {
        /// The image may be flashed.
        case accepted = 0
        /// The image reaches BTstack's reserved flash.
        case rejected = 1
        /// The ELF can't be read or checked.
        case uncheckable = 2
    }

    static func main() {
        let arguments = CommandLine.arguments.dropFirst()
        guard arguments.count == 1, let elfPath = arguments.first else {
            fail("usage: FlashGuardTool <image.elf>", status: .uncheckable)
        }

        let verdict: BTstackFlashGuard.Verdict
        do {
            let elf = try Data(contentsOf: URL(fileURLWithPath: elfPath))
            verdict = try BTstackFlashGuard.inspect(elf: elf)
        } catch {
            fail("BTstack flash guard can't check \(elfPath): \(error)", status: .uncheckable)
        }

        if let rejection = verdict.rejection {
            fail(rejection, status: .rejected)
        }

        if case .clear(let flashLoadEnd, let reserved) = verdict {
            print("[CPicoSDK] BTstack flash guard: \(reserved.lowerBound - flashLoadEnd) bytes free below the reserved flash bank.")
        }
    }

    private static func fail(_ message: String, status: ExitStatus) -> Never {
        FileHandle.standardError.write(Data((message + "\n").utf8))
        exit(status.rawValue)
    }
}
