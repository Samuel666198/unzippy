import Foundation
import UnzippyCore

// A small companion CLI, also bundled inside the app for automation.
// unzippy-cli list <archive>
// unzippy-cli extract <archive> [-o dir] [--password p] [--encoding gbk] [--overwrite]
// unzippy-cli create <output.zip> <paths...> [--format zip|7z|tgz] [--level 6]
// unzippy-cli info <archive>

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func formatBytes(_ bytes: Int64) -> String {
    HumanFormat.bytes(bytes)
}

var args = Array(CommandLine.arguments.dropFirst())
guard let command = args.first else {
    print("""
    unzippy-cli — 轻解压的命令行工具

    用法:
      unzippy-cli list <压缩包>
      unzippy-cli info <压缩包>
      unzippy-cli extract <压缩包> [-o 目标目录] [--password 密码] [--encoding gbk|big5|shiftjis|utf8] [--overwrite] [--select 1,2,3]
      unzippy-cli create <输出文件> <文件或文件夹...> [--format zip|7z|tgz] [--level 0-9]
    """)
    exit(0)
}
args.removeFirst()

func option(_ name: String) -> String? {
    guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
    let value = args[index + 1]
    args.removeSubrange(index...(index + 1))
    return value
}

func flag(_ name: String) -> Bool {
    guard let index = args.firstIndex(of: name) else { return false }
    args.remove(at: index)
    return true
}

let password = option("--password")
let encodingValue = option("--encoding")
let output = option("-o") ?? option("--output")
let levelValue = option("--level")
let formatValue = option("--format")
let selectValue = option("--select")
let overwrite = flag("--overwrite")

let encoding: FilenameEncoding = {
    switch encodingValue?.lowercased() {
    case "gbk", "gb18030": return .gb18030
    case "big5": return .big5
    case "shiftjis", "sjis": return .shiftJIS
    case "utf8": return .utf8
    case "cp437": return .cp437
    default: return .automatic
    }
}()

guard let target = args.first else { fail("缺少压缩包路径") }
let targetURL = URL(fileURLWithPath: target).standardizedFileURL

switch command {
case "zipnames":
    let names = ArchiveReader.debugZipEntryNames(url: targetURL, encoding: encoding)
    for name in names { print(name) }

case "list", "info":
    do {
        let reader = try ArchiveReader(url: targetURL, password: password, encoding: encoding)
        let summary = try reader.listEntries()
        print("格式: \(summary.format.displayName)  (\(summary.formatDescription))")
        print("条目: \(summary.entryCount) 个文件 / \(summary.directoryCount) 个文件夹")
        print("原始大小: \(formatBytes(summary.totalSize))   压缩包: \(formatBytes(summary.archiveSize))")
        if summary.hasEncryptedEntries { print("加密: 是") }
        if command == "list" {
            for entry in summary.entries {
                let size = entry.isDirectory ? "-" : formatBytes(entry.size)
                let padding = String(repeating: " ", count: max(0, 10 - size.count))
                print(padding + size + "  " + entry.path)
            }
        }
    } catch {
        fail("错误: \(error.localizedDescription)")
    }

case "extract":
    do {
        let reader = try ArchiveReader(url: targetURL, password: password, encoding: encoding)
        let summary = try reader.listEntries()
        let base = output.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? targetURL.deletingLastPathComponent()
        let destination = ExtractionPlanner.destinationFolder(
            base: base,
            archiveURL: targetURL,
            createSubfolder: output == nil
        )
        var selected: Set<Int>?
        if let selectValue {
            selected = Set(selectValue.split(separator: ",").compactMap { Int($0) })
        }
        let options = ExtractionOptions(
            password: password,
            encoding: encoding,
            conflictPolicy: overwrite ? .replace : .rename,
            selectedIndices: selected
        )
        let progress = ExtractionProgress()
        let request = ExtractionRequest(
            archiveURL: targetURL,
            destination: destination,
            entries: summary.entries,
            options: options
        )
        let result = try ArchiveExtractor.extract(request, progress: progress)
        print("已解压到: \(result.destination.path)")
        print("文件: \(result.filesWritten)   字节: \(formatBytes(result.bytesWritten))   跳过: \(result.skipped)   用时: \(String(format: "%.2f", result.duration))s")
        for warning in result.warnings.prefix(10) { print("提示: \(warning)") }
    } catch {
        fail("错误: \(error.localizedDescription)")
    }

case "create":
    guard let outputPath = args.first else { fail("缺少输出文件路径") }
    args.removeFirst()
    guard !args.isEmpty else { fail("缺少要压缩的文件") }
    let format: CompressionFormat
    switch (formatValue ?? "").lowercased() {
    case "7z", "sevenzip": format = .sevenZip
    case "tgz", "tar.gz", "targz": format = .tarGz
    default: format = .zip
    }
    let level = Int(levelValue ?? "6") ?? 6
    let destination = URL(fileURLWithPath: outputPath).standardizedFileURL
    let progress = ExtractionProgress()
    do {
        let result = try ArchiveWriter.create(
            items: args.map { URL(fileURLWithPath: $0) },
            destination: destination,
            options: CompressionOptions(format: format, level: level, password: password),
            progress: progress
        )
        print("已创建: \(result.destination.path)")
        print("条目: \(result.filesAdded)   原始: \(formatBytes(result.inputBytes))   压缩后: \(formatBytes(result.outputBytes))")
    } catch {
        fail("错误: \(error.localizedDescription)")
    }

default:
    fail("未知命令: \(command)")
}
