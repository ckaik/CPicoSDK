import Foundation

/// Checks a linked image against the flash that BTstack's bond storage owns (spec §11.6).
///
/// The finalize harness compiles `btstack_flash_guard.c` into BLE images only. It publishes the C
/// build's effective `XIP_BASE + PICO_FLASH_BANK_STORAGE_OFFSET` and `XIP_BASE +
/// PICO_FLASH_SIZE_BYTES` as absolute symbols, so the reserved region here is exactly what BTstack
/// erases and writes at runtime: the last 2 sectors on RP2040, and the last 3 on RP2350 with A2
/// support (the 8 KB bank plus the RP2350-E10 erratum sector).
enum BTstackFlashGuard {
    /// Why an image can't be checked.
    enum Error: Swift.Error, Equatable, CustomStringConvertible {
        /// The file isn't an ELF the guard can read.
        case unreadableELF(ELFImage.ParseError)
        /// The image uses BTstack's flash bank, but the harness didn't publish where it is. Accepting
        /// it would let a BLE image through unchecked.
        case missingReservedRegion

        var description: String {
            switch self {
            case .unreadableELF(let error):
                "\(error)"
            case .missingReservedRegion:
                "the image links BTstack's flash bank (\(BTstackFlashGuard.flashBankSymbol)), but not the "
                    + "\(BTstackFlashGuard.reservedStartSymbol) / \(BTstackFlashGuard.reservedEndSymbol) "
                    + "symbols from the finalize harness's btstack_flash_guard.c, so the image can't be checked"
            }
        }
    }

    enum Verdict: Equatable {
        /// The image doesn't use BTstack's flash bank, so nothing is reserved.
        case noReservedRegion
        case clear(flashLoadEnd: UInt32, reserved: Range<UInt32>)
        case overlapping(flashLoadEnd: UInt32, reserved: Range<UInt32>)
    }

    static let reservedStartSymbol = "__cpicosdk_btstack_flash_reserved_start"
    static let reservedEndSymbol = "__cpicosdk_btstack_flash_reserved_end"
    static let flashBankSymbol = "pico_flash_bank_instance"

    static func inspect(elf: Data) throws(Error) -> Verdict {
        let image: ELFImage
        do {
            image = try ELFImage(elf)
        } catch {
            throw .unreadableELF(error)
        }

        guard let reservedStart = image.symbols[reservedStartSymbol],
              let reservedEnd = image.symbols[reservedEndSymbol]
        else {
            guard image.symbols[flashBankSymbol] == nil else { throw .missingReservedRegion }

            return .noReservedRegion
        }

        let reserved = reservedStart..<reservedEnd
        let flashLoadEnd = flashLoadEnd(of: image, below: reservedEnd)

        return flashLoadEnd > reserved.lowerBound
            ? .overlapping(flashLoadEnd: flashLoadEnd, reserved: reserved)
            : .clear(flashLoadEnd: flashLoadEnd, reserved: reserved)
    }

    /// The end of the bytes the image writes to flash: every loadable segment with file contents,
    /// placed at its load (physical) address. Initialised data runs from RAM but loads from flash,
    /// so it counts at its flash address. Zero-filled segments write nothing. Segments that load
    /// beyond the end of flash, such as RAM, aren't flash.
    private static func flashLoadEnd(of image: ELFImage, below flashEnd: UInt32) -> UInt32 {
        let loadable: UInt32 = 1  // PT_LOAD

        return image.segments
            .filter { $0.type == loadable && $0.fileSize > 0 && $0.physicalAddress < flashEnd }
            .map { UInt32(clamping: UInt64($0.physicalAddress) + UInt64($0.fileSize)) }
            .max() ?? 0
    }
}
