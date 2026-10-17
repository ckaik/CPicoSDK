extension BTstackFlashGuard.Verdict {
    /// Why the image must not be flashed, or `nil` when it may be.
    var rejection: String? {
        guard case .overlapping(let flashLoadEnd, let reserved) = self else { return nil }

        return """
            The BLE image reaches the flash that BTstack reserves for bond storage. Its flash load \
            extent (code, read-only data and initialised data) ends at \(hex(flashLoadEnd)), but \
            \(hex(reserved.lowerBound))..<\(hex(reserved.upperBound)) (\(reserved.count / 1024) KiB) \
            belongs to BTstack's flash bank (PICO_FLASH_BANK_STORAGE_OFFSET, plus the RP2350-E10 \
            erratum sector on RP2350). Flashing it would let bond storage and the firmware overwrite \
            each other. Shrink the image by at least \(flashLoadEnd - reserved.lowerBound) bytes.
            """
    }

    private func hex(_ address: UInt32) -> String {
        "0x" + String(address, radix: 16, uppercase: true)
    }
}
