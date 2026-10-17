import Foundation
import Testing
@testable import FlashGuardTool

@Suite struct BTstackFlashGuardTests {
    @Test func `a BLE image that ends below the reserved region is accepted`() throws {
        let elf = SyntheticELF(
            segments: [
                .flash(at: 0x1000_0000, size: 0x1F_D000),
                .initialisedData(runningAt: 0x2000_0000, loadedFrom: 0x101F_D000, size: 0x1000),
                .zeroFilled(at: 0x2000_1000, size: 0x8000),
            ],
            symbols: SyntheticELF.picoWBLESymbols
        )

        let verdict = try BTstackFlashGuard.inspect(elf: elf.data)

        #expect(verdict == .clear(flashLoadEnd: 0x101F_E000, reserved: 0x101F_E000..<0x1020_0000))
    }

    @Test func `a BLE image whose code reaches the reserved region is rejected`() throws {
        let elf = SyntheticELF(
            segments: [.flash(at: 0x1000_0000, size: 0x1F_E001)],
            symbols: SyntheticELF.picoWBLESymbols
        )

        let verdict = try BTstackFlashGuard.inspect(elf: elf.data)

        #expect(verdict == .overlapping(flashLoadEnd: 0x101F_E001, reserved: 0x101F_E000..<0x1020_0000))
    }

    @Test func `initialised data that loads into the reserved region gets the image rejected`() throws {
        let elf = SyntheticELF(
            segments: [
                .flash(at: 0x1000_0000, size: 0x1F_D000),
                .initialisedData(runningAt: 0x2000_0000, loadedFrom: 0x101F_D000, size: 0x1004),
            ],
            symbols: SyntheticELF.picoWBLESymbols
        )

        let verdict = try BTstackFlashGuard.inspect(elf: elf.data)

        #expect(verdict == .overlapping(flashLoadEnd: 0x101F_E004, reserved: 0x101F_E000..<0x1020_0000))
    }

    @Test func `on RP2350 the erratum sector moves the reserved region down by one sector`() throws {
        let pico2WBLESymbols: [(name: String, value: UInt32)] = [
            ("__cpicosdk_btstack_flash_reserved_start", 0x103F_D000),
            ("__cpicosdk_btstack_flash_reserved_end", 0x1040_0000),
        ]
        let elf = SyntheticELF(
            segments: [.flash(at: 0x1000_0000, size: 0x3F_E000)],
            symbols: pico2WBLESymbols
        )

        let verdict = try BTstackFlashGuard.inspect(elf: elf.data)

        #expect(verdict == .overlapping(flashLoadEnd: 0x103F_E000, reserved: 0x103F_D000..<0x1040_0000))
    }

    @Test func `an image without BTstack's flash bank has nothing reserved`() throws {
        let elf = SyntheticELF(segments: [.flash(at: 0x1000_0000, size: 0x20_0000)])

        let verdict = try BTstackFlashGuard.inspect(elf: elf.data)

        #expect(verdict == .noReservedRegion)
    }

    @Test func `an image that links the flash bank without the guard constants is an error`() {
        let elf = SyntheticELF(
            segments: [.flash(at: 0x1000_0000, size: 0x1000)],
            symbols: [("pico_flash_bank_instance", 0x1000_0101)]
        )

        #expect(throws: BTstackFlashGuard.Error.missingReservedRegion) {
            try BTstackFlashGuard.inspect(elf: elf.data)
        }
    }

    @Test func `a file that isn't ELF32 is an error`() {
        #expect(throws: BTstackFlashGuard.Error.unreadableELF(.notELF32LittleEndian)) {
            try BTstackFlashGuard.inspect(elf: Data("not an elf".utf8))
        }
    }

    @Test func `the rejection names the extent, the reserved region and the overshoot`() throws {
        let verdict = BTstackFlashGuard.Verdict.overlapping(
            flashLoadEnd: 0x101F_E004,
            reserved: 0x101F_E000..<0x1020_0000
        )

        let rejection = try #require(verdict.rejection)

        #expect(rejection.contains("0x101FE004"))
        #expect(rejection.contains("0x101FE000..<0x10200000"))
        #expect(rejection.contains("by at least 4 bytes"))
    }

    @Test(arguments: [
        BTstackFlashGuard.Verdict.noReservedRegion,
        .clear(flashLoadEnd: 0x101F_E000, reserved: 0x101F_E000..<0x1020_0000),
    ])
    func `accepted images have no rejection`(verdict: BTstackFlashGuard.Verdict) {
        #expect(verdict.rejection == nil)
    }
}
