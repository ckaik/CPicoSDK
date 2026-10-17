import Foundation

/// The parts of a little-endian ELF32 image (what the RP2040/RP2350 Arm toolchains link) that the
/// flash guard needs: loadable segments and the symbol table.
struct ELFImage {
    enum ParseError: Error, Equatable, CustomStringConvertible {
        case notELF32LittleEndian
        case truncated(String)

        var description: String {
            switch self {
            case .notELF32LittleEndian:
                "not a little-endian ELF32 file"
            case .truncated(let part):
                "the \(part) runs past the end of the file"
            }
        }
    }

    struct Segment: Equatable {
        let type: UInt32
        let physicalAddress: UInt32
        let fileSize: UInt32
    }

    let segments: [Segment]
    let symbols: [String: UInt32]

    init(_ data: Data) throws(ParseError) {
        let bytes = [UInt8](data)
        guard bytes.count >= 52, bytes[0..<6] == [0x7F, 0x45, 0x4C, 0x46, 1, 1] else {
            throw .notELF32LittleEndian
        }

        let reader = Reader(bytes: bytes)

        let programHeadersOffset = Int(try reader.uint32(at: 0x1C, in: "ELF header"))
        let programHeaderSize = Int(try reader.uint16(at: 0x2A, in: "ELF header"))
        let programHeaderCount = Int(try reader.uint16(at: 0x2C, in: "ELF header"))

        segments = try (0..<programHeaderCount).map { (index: Int) throws(ParseError) -> Segment in
            let offset = programHeadersOffset + index * programHeaderSize
            return Segment(
                type: try reader.uint32(at: offset, in: "program header table"),
                physicalAddress: try reader.uint32(at: offset + 12, in: "program header table"),
                fileSize: try reader.uint32(at: offset + 16, in: "program header table")
            )
        }

        let sectionHeadersOffset = Int(try reader.uint32(at: 0x20, in: "ELF header"))
        let sectionHeaderSize = Int(try reader.uint16(at: 0x2E, in: "ELF header"))
        let sectionHeaderCount = Int(try reader.uint16(at: 0x30, in: "ELF header"))

        func sectionField(_ section: Int, _ field: Int) throws(ParseError) -> Int {
            Int(try reader.uint32(at: sectionHeadersOffset + section * sectionHeaderSize + field, in: "section header table"))
        }

        var symbols: [String: UInt32] = [:]
        let symbolTableType = 2  // SHT_SYMTAB
        for section in 0..<sectionHeaderCount where try sectionField(section, 4) == symbolTableType {
            let tableOffset = try sectionField(section, 16)
            let tableSize = try sectionField(section, 20)
            let entrySize = max(try sectionField(section, 36), 16)
            let stringTableOffset = try sectionField(try sectionField(section, 24), 16)

            for entry in stride(from: tableOffset, to: tableOffset + tableSize, by: entrySize) {
                let nameOffset = Int(try reader.uint32(at: entry, in: "symbol table"))
                guard nameOffset != 0 else { continue }

                let name = try reader.cString(at: stringTableOffset + nameOffset, in: "string table")
                symbols[name] = try reader.uint32(at: entry + 4, in: "symbol table")
            }
        }
        self.symbols = symbols
    }
}

private struct Reader {
    let bytes: [UInt8]

    func uint16(at offset: Int, in part: String) throws(ELFImage.ParseError) -> UInt16 {
        UInt16(truncatingIfNeeded: try littleEndian(at: offset, count: 2, in: part))
    }

    func uint32(at offset: Int, in part: String) throws(ELFImage.ParseError) -> UInt32 {
        UInt32(truncatingIfNeeded: try littleEndian(at: offset, count: 4, in: part))
    }

    func cString(at offset: Int, in part: String) throws(ELFImage.ParseError) -> String {
        guard offset >= 0, offset < bytes.count,
              let terminator = bytes[offset...].firstIndex(of: 0)
        else {
            throw .truncated(part)
        }

        return String(decoding: bytes[offset..<terminator], as: UTF8.self)
    }

    private func littleEndian(at offset: Int, count: Int, in part: String) throws(ELFImage.ParseError) -> UInt64 {
        guard offset >= 0, offset + count <= bytes.count else { throw .truncated(part) }

        return bytes[offset..<offset + count].reversed().reduce(0) { $0 << 8 | UInt64($1) }
    }
}
