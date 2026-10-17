import Foundation

/// Builds a minimal little-endian ELF32 file with program headers and a symbol table, shaped like
/// the images the finalize harness links: a flash text segment, and initialised data that runs from
/// RAM but loads from flash.
struct SyntheticELF {
    struct Segment {
        var virtualAddress: UInt32
        var physicalAddress: UInt32
        var fileSize: UInt32
        var memorySize: UInt32

        static func flash(at address: UInt32, size: UInt32) -> Segment {
            Segment(virtualAddress: address, physicalAddress: address, fileSize: size, memorySize: size)
        }

        static func initialisedData(runningAt ramAddress: UInt32, loadedFrom flashAddress: UInt32, size: UInt32) -> Segment {
            Segment(virtualAddress: ramAddress, physicalAddress: flashAddress, fileSize: size, memorySize: size)
        }

        static func zeroFilled(at ramAddress: UInt32, size: UInt32) -> Segment {
            Segment(virtualAddress: ramAddress, physicalAddress: ramAddress, fileSize: 0, memorySize: size)
        }
    }

    var segments: [Segment] = []
    var symbols: [(name: String, value: UInt32)] = []

    /// The pico_w_ble constants: 2 MB of flash, the bank in the last 2 sectors.
    static let picoWBLESymbols: [(name: String, value: UInt32)] = [
        ("__cpicosdk_btstack_flash_reserved_start", 0x101F_E000),
        ("__cpicosdk_btstack_flash_reserved_end", 0x1020_0000),
    ]

    var data: Data {
        let headerSize = 52
        let programHeaderSize = 32
        let sectionHeaderSize = 40

        var stringTable = Data([0])
        var symbolTable = Data(count: 16)  // the null symbol
        for symbol in symbols {
            let nameOffset = UInt32(stringTable.count)
            stringTable.append(contentsOf: Array(symbol.name.utf8) + [0])
            symbolTable.appendLittleEndian(nameOffset)
            symbolTable.appendLittleEndian(symbol.value)
            symbolTable.appendLittleEndian(UInt32(0))  // st_size
            symbolTable.append(0x10)  // st_info: GLOBAL, NOTYPE
            symbolTable.append(0)  // st_other
            symbolTable.appendLittleEndian(UInt16(0xFFF1))  // st_shndx: SHN_ABS
        }

        let programHeadersOffset = headerSize
        let symbolTableOffset = programHeadersOffset + programHeaderSize * segments.count
        let stringTableOffset = symbolTableOffset + symbolTable.count
        let sectionHeadersOffset = stringTableOffset + stringTable.count

        var elf = Data()
        elf.append(contentsOf: [0x7F, 0x45, 0x4C, 0x46, 1, 1, 1, 0])  // ELFCLASS32, ELFDATA2LSB
        elf.append(Data(count: 8))
        elf.appendLittleEndian(UInt16(2))  // ET_EXEC
        elf.appendLittleEndian(UInt16(40))  // EM_ARM
        elf.appendLittleEndian(UInt32(1))  // e_version
        elf.appendLittleEndian(UInt32(0x1000_0000))  // e_entry
        elf.appendLittleEndian(UInt32(programHeadersOffset))
        elf.appendLittleEndian(UInt32(sectionHeadersOffset))
        elf.appendLittleEndian(UInt32(0x0500_0000))  // e_flags
        elf.appendLittleEndian(UInt16(headerSize))
        elf.appendLittleEndian(UInt16(programHeaderSize))
        elf.appendLittleEndian(UInt16(segments.count))
        elf.appendLittleEndian(UInt16(sectionHeaderSize))
        elf.appendLittleEndian(UInt16(3))  // null, .symtab, .strtab
        elf.appendLittleEndian(UInt16(0))  // e_shstrndx: no section names

        for segment in segments {
            elf.appendLittleEndian(UInt32(1))  // PT_LOAD
            elf.appendLittleEndian(UInt32(0))  // p_offset: contents aren't modelled
            elf.appendLittleEndian(segment.virtualAddress)
            elf.appendLittleEndian(segment.physicalAddress)
            elf.appendLittleEndian(segment.fileSize)
            elf.appendLittleEndian(segment.memorySize)
            elf.appendLittleEndian(UInt32(5))  // p_flags
            elf.appendLittleEndian(UInt32(4))  // p_align
        }

        elf.append(symbolTable)
        elf.append(stringTable)

        elf.append(Data(count: sectionHeaderSize))  // the null section
        elf.appendSectionHeader(type: 2, offset: symbolTableOffset, size: symbolTable.count, link: 2, entrySize: 16)
        elf.appendSectionHeader(type: 3, offset: stringTableOffset, size: stringTable.count, link: 0, entrySize: 0)

        return elf
    }
}

private extension Data {
    mutating func appendLittleEndian<Value: FixedWidthInteger>(_ value: Value) {
        Swift.withUnsafeBytes(of: value.littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendSectionHeader(type: UInt32, offset: Int, size: Int, link: UInt32, entrySize: UInt32) {
        appendLittleEndian(UInt32(0))  // sh_name
        appendLittleEndian(type)
        appendLittleEndian(UInt32(0))  // sh_flags
        appendLittleEndian(UInt32(0))  // sh_addr
        appendLittleEndian(UInt32(offset))
        appendLittleEndian(UInt32(size))
        appendLittleEndian(link)
        appendLittleEndian(UInt32(0))  // sh_info
        appendLittleEndian(UInt32(4))  // sh_addralign
        appendLittleEndian(entrySize)
    }
}
