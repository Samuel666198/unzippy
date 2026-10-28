import Foundation

/// Raw central-directory information for ZIP files.
///
/// libarchive decodes non-UTF-8 ZIP names as CP437 and offers no way to override
/// that for the zip reader, so we read the central directory ourselves. Besides
/// correct Chinese names this also gives us per-entry compressed sizes, which
/// libarchive does not expose.
struct ZipRawEntry {
    var nameBytes: [UInt8]
    var isUTF8: Bool
    var compressedSize: UInt64
    var uncompressedSize: UInt64
}

enum ZipCentralDirectory {
    private static let eocdSignature: UInt32 = 0x0605_4b50
    private static let eocd64Signature: UInt32 = 0x0606_4b50
    private static let eocd64LocatorSignature: UInt32 = 0x0706_4b50
    private static let centralSignature: UInt32 = 0x0201_4b50

    static func read(url: URL) -> [ZipRawEntry]? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let fileSize = try? handle.seekToEnd(), fileSize > 22 else { return nil }

        let tailSize = Int(min(fileSize, 66_000))
        guard let tailData = readAt(handle, offset: fileSize - UInt64(tailSize), count: tailSize) else { return nil }
        let tail = [UInt8](tailData)

        guard let eocdOffsetInTail = findEOCD(in: tail) else { return nil }
        let eocdFileOffset = fileSize - UInt64(tailSize) + UInt64(eocdOffsetInTail)

        var entryCount = UInt64(readU32(tail, eocdOffsetInTail + 10))
        var cdSize = UInt64(readU32(tail, eocdOffsetInTail + 12))
        var cdOffset = UInt64(readU32(tail, eocdOffsetInTail + 16))

        var cdEnd = eocdFileOffset
        if entryCount == 0xFFFF || cdSize == 0xFFFF_FFFF || cdOffset == 0xFFFF_FFFF {
            if let locatorOffset = findSignature(eocd64LocatorSignature, in: tail, before: eocdOffsetInTail) {
                let zip64Offset = readU64(tail, locatorOffset + 8)
                if let headerData = readAt(handle, offset: zip64Offset, count: 56) {
                    let header = [UInt8](headerData)
                    if header.count >= 56, readU32(header, 0) == eocd64Signature {
                        entryCount = readU64(header, 32)
                        cdSize = readU64(header, 40)
                        cdOffset = readU64(header, 48)
                        cdEnd = zip64Offset
                    }
                }
            }
        }

        guard cdSize > 0, cdSize <= 64 * 1024 * 1024 else { return nil }
        var centralData: [UInt8]?
        for candidate in [cdOffset, cdEnd &- cdSize] {
            guard candidate + cdSize <= fileSize else { continue }
            if let chunk = readAt(handle, offset: candidate, count: Int(cdSize)) {
                let bytes = [UInt8](chunk)
                if bytes.count >= 4, readU32(bytes, 0) == centralSignature {
                    centralData = bytes
                    break
                }
            }
        }
        guard let cd = centralData else { return nil }

        var entries: [ZipRawEntry] = []
        entries.reserveCapacity(Int(min(entryCount, 100_000)))
        var offset = 0
        var index: UInt64 = 0
        while offset + 46 <= cd.count && index < entryCount {
            guard readU32(cd, offset) == centralSignature else { break }
            let flags = readU16(cd, offset + 8)
            var compressed = UInt64(readU32(cd, offset + 20))
            var uncompressed = UInt64(readU32(cd, offset + 24))
            let nameLength = Int(readU16(cd, offset + 28))
            let extraLength = Int(readU16(cd, offset + 30))
            let commentLength = Int(readU16(cd, offset + 32))

            let nameStart = offset + 46
            let nameEnd = nameStart + nameLength
            let extraStart = nameEnd
            let extraEnd = extraStart + extraLength
            guard nameEnd <= cd.count, extraEnd <= cd.count else { break }

            let nameBytes = Array(cd[nameStart..<nameEnd])
            if compressed == 0xFFFF_FFFF || uncompressed == 0xFFFF_FFFF {
                applyZip64Sizes(
                    extra: Array(cd[extraStart..<extraEnd]),
                    compressed: &compressed,
                    uncompressed: &uncompressed
                )
            }
            entries.append(
                ZipRawEntry(
                    nameBytes: nameBytes,
                    isUTF8: flags & 0x0800 != 0,
                    compressedSize: compressed,
                    uncompressedSize: uncompressed
                )
            )
            offset = extraEnd + commentLength
            index += 1
        }
        return entries.isEmpty ? nil : entries
    }

    static func decodeName(_ raw: ZipRawEntry, encoding: FilenameEncoding) -> String? {
        let data = Data(raw.nameBytes)
        if raw.isUTF8 {
            return String(data: data, encoding: .utf8)
        }
        switch encoding {
        case .cp437:
            return nil
        case .utf8:
            return String(data: data, encoding: .utf8)
        case .gb18030, .big5, .shiftJIS:
            guard let enc = encoding.foundationEncoding else { return nil }
            return String(data: data, encoding: enc)
        case .automatic:
            if raw.nameBytes.allSatisfy({ $0 < 0x80 }) {
                return String(decoding: raw.nameBytes, as: UTF8.self)
            }
            if let utf8 = String(data: data, encoding: .utf8), FilenameRepair.containsCJK(utf8) {
                return utf8
            }
            if let gbkEncoding = FilenameEncoding.gb18030.foundationEncoding,
               let gbk = String(data: data, encoding: gbkEncoding),
               FilenameRepair.containsCJK(gbk) {
                return gbk
            }
            return nil
        }
    }

    private static func applyZip64Sizes(extra: [UInt8], compressed: inout UInt64, uncompressed: inout UInt64) {
        var offset = 0
        while offset + 4 <= extra.count {
            let tag = readU16(extra, offset)
            let size = Int(readU16(extra, offset + 2))
            let dataStart = offset + 4
            guard dataStart + size <= extra.count else { return }
            if tag == 0x0001 {
                var cursor = dataStart
                if uncompressed == 0xFFFF_FFFF, cursor + 8 <= dataStart + size {
                    uncompressed = readU64(extra, cursor)
                    cursor += 8
                }
                if compressed == 0xFFFF_FFFF, cursor + 8 <= dataStart + size {
                    compressed = readU64(extra, cursor)
                }
                return
            }
            offset = dataStart + size
        }
    }

    private static func readAt(_ handle: FileHandle, offset: UInt64, count: Int) -> Data? {
        guard let fileSize = try? handle.seekToEnd(), offset + UInt64(count) <= fileSize else { return nil }
        do {
            try handle.seek(toOffset: offset)
            return try handle.read(upToCount: count)
        } catch {
            return nil
        }
    }

    // MARK: - Little-endian helpers

    private static func findEOCD(in data: [UInt8]) -> Int? {
        guard data.count >= 22 else { return nil }
        var index = data.count - 22
        while index >= 0 {
            if readU32(data, index) == eocdSignature {
                let commentLength = Int(readU16(data, index + 20))
                if index + 22 + commentLength == data.count {
                    return index
                }
            }
            index -= 1
        }
        return nil
    }

    private static func findSignature(_ signature: UInt32, in data: [UInt8], before limit: Int) -> Int? {
        guard limit >= 4 else { return nil }
        var index = limit - 4
        while index >= 0 {
            if readU32(data, index) == signature { return index }
            index -= 1
        }
        return nil
    }

    private static func readU16(_ data: [UInt8], _ offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        return UInt16(data[offset]) | UInt16(data[offset + 1]) << 8
    }

    private static func readU32(_ data: [UInt8], _ offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return UInt32(data[offset])
            | UInt32(data[offset + 1]) << 8
            | UInt32(data[offset + 2]) << 16
            | UInt32(data[offset + 3]) << 24
    }

    private static func readU64(_ data: [UInt8], _ offset: Int) -> UInt64 {
        UInt64(readU32(data, offset)) | UInt64(readU32(data, offset + 4)) << 32
    }
}
