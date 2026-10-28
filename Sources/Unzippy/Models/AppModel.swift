import AppKit
import SwiftUI
import UniformTypeIdentifiers
import UnzippyCore

struct BannerMessage: Identifiable, Equatable {
    enum Style { case success, error, info }
    let id = UUID()
    var title: String
    var detail: String?
    var style: Style
}

struct PasswordPrompt: Identifiable {
    enum Retry {
        case inspect
        case extract(destination: URL?, selection: Set<Int>?)
    }

    let id = UUID()
    var jobID: UUID
    var archiveName: String
    var retry: Retry
    var message: String?
}

struct CompressionDraft: Identifiable, Equatable {
    let id = UUID()
    var items: [URL]
    var fileName: String
    var format: CompressionFormat
    var level: Int
    var destination: URL
    var password: String = ""
}

@MainActor
final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published var jobs: [ArchiveJob] = []
    @Published var selectedJobID: UUID?
    @Published var detailSummary: ArchiveSummary?
    @Published var detailLoading = false
    @Published var detailError: String?
    @Published var detailEncoding: FilenameEncoding = Prefs.encoding
    @Published var passwordPrompt: PasswordPrompt?
    @Published var banner: BannerMessage?
    @Published var compressionDraft: CompressionDraft?
    @Published var isCompressing = false
    @Published var compressionFraction: Double = 0
    @Published var compressionStatus = ""
    @Published var compressionError: String?
    @Published var batchRunning = false
    @Published var isDropTargeted = false

    private var summaryCache: [UUID: ArchiveSummary] = [:]
    private var cacheOrder: [UUID] = []
    private var loadTasks: [UUID: Task<Void, Never>] = [:]
    private var activeProgress: ExtractionProgress?
    private var activeJobID: UUID?
    private var progressTask: Task<Void, Never>?
    private var batchTask: Task<Void, Never>?

    private init() {}

    // MARK: - Queue

    func add(urls: [URL]) {
        var archiveURLs: [URL] = []
        var compressible: [URL] = []
        for url in urls {
            let standardized = url.standardizedFileURL
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: standardized.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                compressible.append(standardized)
            } else if ArchiveFormat.looksLikeArchive(url: standardized) {
                archiveURLs.append(standardized)
            } else {
                // Unknown extension: still try as an archive, libarchive detects magic.
                archiveURLs.append(standardized)
            }
        }

        var firstNew: UUID?
        for url in archiveURLs {
            if jobs.contains(where: { $0.url == url && $0.state != .done && $0.state != .cancelled }) {
                continue
            }
            var job = ArchiveJob(
                url: url,
                format: ArchiveFormat.detect(url: url),
                size: (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0
            )
            if Prefs.rememberPasswords, let saved = PasswordStore.password(for: url) {
                job.password = saved
            }
            if let argument = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("--demo-password=") }) {
                job.password = String(argument.dropFirst("--demo-password=".count))
            }
            jobs.append(job)
            if firstNew == nil { firstNew = jobs.last?.id }
        }

        if let firstNew {
            select(firstNew)
        }
        if !compressible.isEmpty {
            openCompressionSheet(items: compressible)
        }
        if archiveURLs.isEmpty && compressible.isEmpty {
            showBanner(title: "没有可处理的项目", detail: "请拖入压缩包或文件夹", style: .error)
        }
        // Testing hook used by the development scripts; invisible in normal use.
        if ProcessInfo.processInfo.arguments.contains("--auto-extract"), let firstNew {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.extract(jobID: firstNew)
            }
        }
        if ProcessInfo.processInfo.arguments.contains("--auto-extract-all") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                self?.extractAll()
            }
        }
    }

    func remove(jobID: UUID) {
        guard let job = job(jobID), !job.state.isActive else { return }
        loadTasks[jobID]?.cancel()
        loadTasks[jobID] = nil
        jobs.removeAll { $0.id == jobID }
        summaryCache[jobID] = nil
        cacheOrder.removeAll { $0 == jobID }
        if selectedJobID == jobID {
            selectedJobID = jobs.first?.id
            detailSummary = nil
            detailError = nil
            if let id = selectedJobID { select(id) }
        }
    }

    func clearFinished() {
        let ids = jobs.filter { $0.state == .done || $0.state == .cancelled || $0.state == .failed }.map(\.id)
        jobs.removeAll { ids.contains($0.id) }
        if let selectedJobID, ids.contains(selectedJobID) {
            self.selectedJobID = jobs.first?.id
            detailSummary = nil
            if let id = self.selectedJobID { select(id) }
        }
    }

    func select(_ id: UUID?) {
        selectedJobID = id
        detailSummary = nil
        detailError = nil
        guard let id, let job = job(id) else { return }
        detailEncoding = job.encoding
        if let cached = summaryCache[id] {
            detailSummary = cached
            detailLoading = false
        } else {
            loadDetail(jobID: id)
        }
    }

    func job(_ id: UUID?) -> ArchiveJob? {
        guard let id else { return nil }
        return jobs.first { $0.id == id }
    }

    private func updateJob(_ id: UUID, _ mutate: (inout ArchiveJob) -> Void) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        mutate(&jobs[index])
    }

    // MARK: - Inspecting

    func loadDetail(jobID: UUID, force: Bool = false) {
        guard let job = job(jobID) else { return }
        if !force, let cached = summaryCache[jobID] {
            cacheSummary(cached, for: jobID)
            if selectedJobID == jobID {
                detailSummary = cached
                detailLoading = false
                detailError = nil
            }
            return
        }
        guard loadTasks[jobID] == nil else { return }
        if selectedJobID == jobID {
            detailLoading = true
            detailError = nil
        }
        updateJob(jobID) { $0.state = .inspecting; $0.errorMessage = nil }

        let url = job.url
        let encoding = job.encoding
        let password = job.password

        let task = Task { [weak self] in
            do {
                let summary = try await Task.detached(priority: .userInitiated) {
                    let reader = try ArchiveReader(url: url, password: password, encoding: encoding)
                    return try reader.listEntries()
                }.value
                guard !Task.isCancelled else { return }
                self?.finishInspect(jobID: jobID, summary: summary)
            } catch {
                guard !Task.isCancelled else { return }
                self?.failInspect(jobID: jobID, error: error)
            }
        }
        loadTasks[jobID] = task
    }

    private func finishInspect(jobID: UUID, summary: ArchiveSummary) {
        loadTasks[jobID] = nil
        cacheSummary(summary, for: jobID)
        updateJob(jobID) { job in
            job.state = .ready
            job.entryCount = summary.entryCount
            job.totalUncompressed = summary.totalSize
            job.isEncrypted = summary.hasEncryptedEntries
            job.format = summary.format
            job.size = summary.archiveSize
            job.errorMessage = nil
        }
        if selectedJobID == jobID {
            detailSummary = summary
            detailLoading = false
            detailError = nil
        }
    }

    private func failInspect(jobID: UUID, error: Error) {
        loadTasks[jobID] = nil
        let message = error.localizedDescription
        if selectedJobID == jobID { detailLoading = false }
        if let archiveError = error as? ArchiveError {
            switch archiveError {
            case .passwordRequired, .wrongPassword:
                updateJob(jobID) { $0.state = .waiting; $0.entryCount = nil }
                if selectedJobID == jobID {
                    detailSummary = nil
                    detailError = "这个压缩包已加密，需要密码才能查看内容"
                    passwordPrompt = PasswordPrompt(
                        jobID: jobID,
                        archiveName: job(jobID)?.name ?? "",
                        retry: .inspect,
                        message: nil
                    )
                }
                return
            case .notAnArchive:
                updateJob(jobID) { $0.state = .failed; $0.errorMessage = "不是可识别的压缩文件" }
                if selectedJobID == jobID { detailError = "不是可识别的压缩文件，或者文件已损坏。" }
                return
            default:
                break
            }
        }
        updateJob(jobID) { $0.state = .failed; $0.errorMessage = message }
        if selectedJobID == jobID { detailError = message }
    }

    private func cacheSummary(_ summary: ArchiveSummary, for id: UUID) {
        summaryCache[id] = summary
        cacheOrder.removeAll { $0 == id }
        cacheOrder.append(id)
        while cacheOrder.count > 4 {
            let evicted = cacheOrder.removeFirst()
            summaryCache[evicted] = nil
        }
    }

    private func loadSummary(for job: ArchiveJob) async throws -> ArchiveSummary {
        if let cached = summaryCache[job.id] { return cached }
        if selectedJobID == job.id { detailLoading = true }
        let summary = try await Task.detached(priority: .userInitiated) {
            let reader = try ArchiveReader(url: job.url, password: job.password, encoding: job.encoding)
            return try reader.listEntries()
        }.value
        finishInspect(jobID: job.id, summary: summary)
        return summary
    }

    func setEncoding(_ encoding: FilenameEncoding, for jobID: UUID) {
        guard job(jobID)?.encoding != encoding else { return }
        updateJob(jobID) { $0.encoding = encoding }
        detailEncoding = encoding
        summaryCache[jobID] = nil
        loadDetail(jobID: jobID, force: true)
    }

    // MARK: - Extraction

    func extract(jobID: UUID, destination: URL? = nil, selection: Set<Int>? = nil) {
        guard let job = job(jobID), job.state != .extracting else { return }
        guard activeJobID == nil, !isCompressing else {
            showBanner(title: "已有任务在进行", detail: "请等待当前解压或压缩完成", style: .info)
            return
        }
        Task {
            _ = await performExtraction(jobID: jobID, destinationOverride: destination, selection: selection)
        }
    }

    func extractAll() {
        guard !batchRunning, activeJobID == nil else { return }
        let pending = jobs.filter { job in
            job.state == .waiting || job.state == .ready || job.state == .failed
        }.map(\.id)
        guard !pending.isEmpty else { return }

        batchRunning = true
        batchTask = Task {
            for (index, id) in pending.enumerated() {
                if Task.isCancelled { break }
                if selectedJobID != id { select(id) }
                let ok = await performExtraction(jobID: id, destinationOverride: nil, selection: nil)
                if !ok, let job = job(id), job.state == .failed, index < pending.count - 1 {
                    // Keep going: one broken archive should not block the rest.
                }
                if job(id)?.state == .cancelled { break }
            }
            batchRunning = false
            batchTask = nil
        }
    }

    func cancelActive() {
        activeProgress?.cancel()
        batchTask?.cancel()
    }

    @discardableResult
    private func performExtraction(jobID: UUID, destinationOverride: URL?, selection: Set<Int>?) async -> Bool {
        guard var job = job(jobID) else { return false }
        let summaryData: ArchiveSummary
        do {
            summaryData = try await loadSummary(for: job)
        } catch {
            failInspect(jobID: jobID, error: error)
            return false
        }
        job = self.job(jobID) ?? job

        var base: URL
        if let destinationOverride {
            base = destinationOverride
        } else if Prefs.destinationMode == .ask {
            guard let picked = chooseFolder(prompt: "选择解压位置") else { return false }
            base = picked
        } else {
            base = Prefs.baseDestination(for: job.url)
        }

        let destination = Prefs.createSubfolder
            ? ExtractionPlanner.destinationFolder(base: base, archiveURL: job.url, createSubfolder: true)
            : base
        let existedBefore = FileManager.default.fileExists(atPath: destination.path)
        do {
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        } catch {
            updateJob(jobID) { $0.state = .failed; $0.errorMessage = error.localizedDescription }
            showBanner(title: "无法创建目标文件夹", detail: error.localizedDescription, style: .error)
            return false
        }

        if let capacity = try? destination.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        ).volumeAvailableCapacityForImportantUsage,
           capacity > 0,
           summaryData.totalSize > capacity {
            updateJob(jobID) { $0.state = .failed; $0.errorMessage = "磁盘空间不足" }
            showBanner(
                title: "磁盘空间不足",
                detail: "需要 \(HumanFormat.bytes(summaryData.totalSize))，可用 \(HumanFormat.bytes(capacity))",
                style: .error
            )
            cleanupEmptyDestination(destination, existedBefore: existedBefore)
            return false
        }

        let options = Prefs.extractionOptions(
            password: job.password,
            encoding: job.encoding,
            selection: selection
        )
        let request = ExtractionRequest(
            archiveURL: job.url,
            destination: destination,
            entries: summaryData.entries,
            options: options
        )
        let progress = ExtractionProgress()
        activeProgress = progress
        activeJobID = jobID
        updateJob(jobID) { updated in
            updated.state = .extracting
            updated.fraction = 0
            updated.bytesDone = 0
            updated.bytesTotal = 0
            updated.filesDone = 0
            updated.filesTotal = 0
            updated.speed = 0
            updated.eta = nil
            updated.destination = destination
            updated.errorMessage = nil
            updated.startedAt = Date()
            updated.skippedCount = 0
        }
        startProgressPolling(jobID: jobID)

        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try ArchiveExtractor.extract(request, progress: progress)
            }.value
            stopProgressPolling()
            updateJob(jobID) { updated in
                updated.state = .done
                updated.fraction = 1
                updated.bytesDone = result.bytesWritten
                updated.bytesTotal = max(result.bytesWritten, updated.bytesTotal)
                updated.filesDone = result.filesWritten
                updated.finishedAt = Date()
                updated.skippedCount = result.skipped
                updated.destination = result.destination
                updated.speed = 0
                updated.eta = nil
            }
            let detail = "\(result.filesWritten) 个文件 · \(HumanFormat.bytes(result.bytesWritten))"
            showBanner(title: "解压完成：\(job.name)", detail: detail, style: .success)
            if Prefs.revealInFinder {
                NSWorkspace.shared.activateFileViewerSelecting([result.destination])
            }
            if Prefs.deleteArchive {
                try? FileManager.default.trashItem(at: job.url, resultingItemURL: nil)
            }
            return true
        } catch {
            stopProgressPolling()
            let description = error.localizedDescription
            if let archiveError = error as? ArchiveError {
                switch archiveError {
                case .cancelled:
                    updateJob(jobID) { updated in
                        updated.state = .cancelled
                        updated.fraction = 0
                        updated.speed = 0
                        updated.eta = nil
                    }
                    showBanner(title: "已取消解压", detail: job.name, style: .info)
                    cleanupEmptyDestination(destination, existedBefore: existedBefore)
                    return false
                case .passwordRequired, .wrongPassword:
                    updateJob(jobID) { updated in
                        updated.state = .ready
                        updated.fraction = 0
                        updated.speed = 0
                        updated.eta = nil
                    }
                    cleanupEmptyDestination(destination, existedBefore: existedBefore)
                    passwordPrompt = PasswordPrompt(
                        jobID: jobID,
                        archiveName: job.name,
                        retry: .extract(destination: destinationOverride, selection: selection),
                        message: archiveError == .wrongPassword ? "密码不正确，请重试" : nil
                    )
                    return false
                default:
                    break
                }
            }
            updateJob(jobID) { updated in
                updated.state = .failed
                updated.errorMessage = description
                updated.speed = 0
                updated.eta = nil
            }
            showBanner(title: "解压失败：\(job.name)", detail: description, style: .error)
            return false
        }
    }

    private func cleanupEmptyDestination(_ url: URL, existedBefore: Bool) {
        guard !existedBefore else { return }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        if contents.isEmpty {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func submitPassword(_ password: String, remember: Bool) {
        guard let prompt = passwordPrompt else { return }
        passwordPrompt = nil
        guard let job = job(prompt.jobID) else { return }
        updateJob(prompt.jobID) { $0.password = password }
        if remember {
            PasswordStore.save(password, for: job.url)
        }
        switch prompt.retry {
        case .inspect:
            summaryCache[prompt.jobID] = nil
            loadDetail(jobID: prompt.jobID, force: true)
        case .extract(let destination, let selection):
            extract(jobID: prompt.jobID, destination: destination, selection: selection)
        }
    }

    func dismissPasswordPrompt() {
        passwordPrompt = nil
    }

    // MARK: - Progress

    private func startProgressPolling(jobID: UUID?) {
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard let self, let progress = self.activeProgress else { break }
                let snapshot = progress.snapshot()
                if let jobID {
                    self.updateJob(jobID) { job in
                        job.fraction = snapshot.fraction
                        job.bytesDone = snapshot.writtenBytes
                        job.bytesTotal = snapshot.totalBytes
                        job.filesDone = snapshot.filesDone
                        job.filesTotal = snapshot.totalFiles
                        job.speed = snapshot.speed
                        job.eta = snapshot.estimatedRemaining
                    }
                } else {
                    self.compressionFraction = snapshot.fraction
                    self.compressionStatus = snapshot.currentPath
                }
            }
        }
    }

    private func stopProgressPolling() {
        progressTask?.cancel()
        progressTask = nil
        activeProgress = nil
        activeJobID = nil
    }

    var activeJob: ArchiveJob? { job(activeJobID) }

    // MARK: - Compression

    func openCompressionSheet(items: [URL]) {
        guard !items.isEmpty else { return }
        let first = items[0]
        let baseName: String
        if items.count == 1 {
            baseName = first.deletingPathExtension().lastPathComponent
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmm"
            baseName = "归档-\(formatter.string(from: Date()))"
        }
        compressionDraft = CompressionDraft(
            items: items,
            fileName: baseName.isEmpty ? "归档" : baseName,
            format: Prefs.compressionFormat,
            level: Prefs.compressionLevel,
            destination: Prefs.baseDestination(for: first)
        )
        compressionError = nil
        compressionFraction = 0
    }

    func chooseCompressionItems() {
        let panel = NSOpenPanel()
        panel.title = "选择要压缩的文件或文件夹"
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "选择"
        guard panel.runModal() == .OK else { return }
        openCompressionSheet(items: panel.urls)
    }

    func startCompression() {
        guard let draft = compressionDraft, !isCompressing else { return }
        guard activeJobID == nil else {
            compressionError = "请等待当前解压任务完成"
            return
        }
        var name = draft.fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        name = name.replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: CharacterSet(charactersIn: ". "))
        let extensionSuffix = "." + draft.format.fileExtension
        if name.lowercased().hasSuffix(extensionSuffix) {
            name = String(name.dropLast(extensionSuffix.count))
        }
        guard !name.isEmpty else {
            compressionError = "请输入有效的压缩包名称"
            return
        }
        compressionError = nil
        isCompressing = true
        compressionFraction = 0

        var destination = draft.destination.appendingPathComponent("\(name).\(draft.format.fileExtension)")
        var counter = 2
        while FileManager.default.fileExists(atPath: destination.path) {
            destination = draft.destination.appendingPathComponent("\(name) (\(counter)).\(draft.format.fileExtension)")
            counter += 1
        }

        let progress = ExtractionProgress()
        activeProgress = progress
        activeJobID = nil
        startProgressPolling(jobID: nil)
        let options = CompressionOptions(
            format: draft.format,
            level: draft.level,
            includeHiddenFiles: true,
            skipDSStore: Prefs.skipDSStore,
            password: draft.password.isEmpty ? nil : draft.password
        )
        let items = draft.items

        Task {
            do {
                let result = try await Task.detached(priority: .userInitiated) {
                    try ArchiveWriter.create(items: items, destination: destination, options: options, progress: progress)
                }.value
                stopProgressPolling()
                isCompressing = false
                compressionFraction = 1
                compressionDraft = nil
                showBanner(
                    title: "压缩完成",
                    detail: "\(result.filesAdded) 个条目 · \(HumanFormat.bytes(result.outputBytes))",
                    style: .success
                )
                if Prefs.revealInFinder {
                    NSWorkspace.shared.activateFileViewerSelecting([result.destination])
                }
                add(urls: [result.destination])
            } catch {
                stopProgressPolling()
                isCompressing = false
                compressionError = error.localizedDescription
            }
        }
    }

    func cancelCompression() {
        activeProgress?.cancel()
    }

    func dismissCompression() {
        guard !isCompressing else { return }
        compressionDraft = nil
        compressionError = nil
    }

    // MARK: - Panels & helpers

    func chooseArchives() {
        let panel = NSOpenPanel()
        panel.title = "选择压缩包"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.prompt = "打开"
        if panel.runModal() == .OK {
            add(urls: panel.urls)
        }
    }

    private func chooseFolder(prompt: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = prompt
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择"
        return panel.runModal() == .OK ? panel.url : nil
    }

    func chooseExtractionFolder(for jobID: UUID) {
        guard let folder = chooseFolder(prompt: "选择解压位置") else { return }
        extract(jobID: jobID, destination: folder)
    }

    func reveal(jobID: UUID) {
        guard let job = job(jobID) else { return }
        if let destination = job.destination, FileManager.default.fileExists(atPath: destination.path) {
            NSWorkspace.shared.activateFileViewerSelecting([destination])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([job.url])
        }
    }

    func revealArchive(jobID: UUID) {
        guard let job = job(jobID) else { return }
        NSWorkspace.shared.activateFileViewerSelecting([job.url])
    }

    func openArchive(_ url: URL) {
        add(urls: [url])
    }

    func showBanner(title: String, detail: String?, style: BannerMessage.Style) {
        let message = BannerMessage(title: title, detail: detail, style: style)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
            banner = message
        }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard let self, self.banner?.id == message.id else { return }
            withAnimation(.easeOut(duration: 0.25)) { self.banner = nil }
        }
    }

    var pendingCount: Int {
        jobs.filter { $0.state == .waiting || $0.state == .ready || $0.state == .failed }.count
    }

    var finishedCount: Int {
        jobs.filter { $0.state == .done }.count
    }

    var totalQueueBytes: Int64 {
        jobs.reduce(0) { $0 + $1.size }
    }
}
