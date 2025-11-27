import SwiftUI
import Foundation

/// 图片浏览器视图模型常量定义
struct ImageBrowserViewModelConstants {
    /// 默认自动播放间隔时间（秒）
    static let defaultAutoPlayInterval: TimeInterval = 3.0
    
    /// 默认缩略图大小（像素）
    static let defaultThumbnailSize: CGFloat = 200
    
    /// 支持的图片文件扩展名
    static let supportedImageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp"]
    
    /// 视图切换延迟时间（秒），用于确保焦点正确设置
    static let viewSwitchDelay: TimeInterval = 0.2
    
    /// 键盘导航时上下方向移动的步长（图片数量）
    static let keyboardNavigationStep: Int = 4
    
    /// 分页配置常量
    struct Pagination {
        /// 默认初始加载图片数量
        static let defaultInitialLoadCount: Int = 100
        
        /// 分页加载的每页图片数量
        static let pageSize: Int = 50
        
        /// 环境变量名称，用于覆盖默认初始加载数量
        static let initialLoadCountEnvironmentVariable = "PV_INITIAL_LOAD_COUNT"
    }
    
    /// 错误消息常量
    struct ErrorMessages {
        /// 目录为空时的错误消息
        static let emptyDirectory = "该目录中没有找到支持的图片文件"
        
        /// 加载目录失败时的错误消息模板
        static let directoryLoadFailed = "无法加载目录: %@"
        
        /// 删除图片失败时的错误消息模板
        static let imageDeleteFailed = "删除图片失败: %@"
    }
    
    /// 日志消息常量
    struct LogMessages {
        /// 加载更多图片时的日志消息模板
        static let loadMoreImages = "加载了更多图片: 从 %d 到 %d, 总共 %d 张图片"
        
        /// 从单图返回时的日志消息模板
        static let returnFromSingleView = "从单图返回，加载完整文件夹内容: %d -> %d"
    }
}

@MainActor
class ImageBrowserViewModel: ObservableObject {
    @Published var images: [ImageItem] = []
    @Published var directoryGroups: [DirectoryGroup] = []
    @Published var currentDirectory: URL?
    @Published var isSingleViewMode = false
    @Published var isReturningFromSingleView = false  // 新增：从单页返回状态标记
    @Published var currentImageIndex = 0
    @Published var isAutoPlaying = false
    @Published var autoPlayInterval: TimeInterval = ImageBrowserViewModelConstants.defaultAutoPlayInterval
    @Published var showProgressBar = false
    
    @Published var errorMessage: String?
    @Published var isLoading: Bool = false
    
    @Published var selectedImages: Set<UUID> = []
    @Published var lastSelectedIndex: Int = 0
    
    @Published var manualThumbnailSize: CGFloat = ImageBrowserViewModelConstants.defaultThumbnailSize
    
    // 随机排序状态管理
    @Published var isRandomOrderEnabled: Bool = false
    private var originalImageOrder: [ImageItem] = []
    
    private var autoPlayTimer: Timer?
    
    private let imageExtensions = ImageBrowserViewModelConstants.supportedImageExtensions
    
    // 分页加载配置
    private struct PaginationConfig {
        // 环境变量优先，便于测试
        static let initialLoadCount: Int = {
            ProcessInfo.processInfo.environment[ImageBrowserViewModelConstants.Pagination.initialLoadCountEnvironmentVariable].flatMap(Int.init) ?? ImageBrowserViewModelConstants.Pagination.defaultInitialLoadCount
        }()
        static let pageSize: Int = ImageBrowserViewModelConstants.Pagination.pageSize
        
        // 与CacheManager协调，确保不超过缓存限制
        static var effectiveInitialLoadCount: Int {
            return min(initialLoadCount, UnifiedCacheManager.maxCacheSize / 2)
        }
    }
    
    private let maxInitialImages = PaginationConfig.effectiveInitialLoadCount
    
    @Published var isFirstTimeInSingleView = true
    
    // 分页状态管理
    @Published var canLoadMore = false
    @Published var isLoadingMore = false
    private var allScannedImages: [ImageItem] = []
    private var currentPage = 0
    
    // 目录中实际图片总数
    var totalImagesInDirectory: Int {
        return allScannedImages.count
    }
    
    // 检查是否有内容显示
    var hasContent: Bool {
        return !images.isEmpty && !isLoading
    }
    //加载默认目录
    func loadInitialDirectory() {
    }
    
    func loadImages(from directory: URL) {
        isLoading = true
        errorMessage = nil
        currentDirectory = directory
        
        // 重置分页状态
        allScannedImages = []
        currentPage = 0
        canLoadMore = false
        
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [])
            
            var directories: [URL] = []
            var imageFiles: [URL] = []
            
            for url in contents {
                let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == true {
                    directories.append(url)
                } else if isImageFile(url) {
                    imageFiles.append(url)
                }
            }
            
            // 完整扫描所有图片
            var allImages: [ImageItem] = []
            
            // 当前目录的图片
            allImages.append(contentsOf: imageFiles.map { ImageItem(url: $0, directoryName: directory.lastPathComponent) })
            
            // 子目录的图片（完整扫描）
            for dir in directories {
                let subImages = scanDirectoryRecursivelyComplete(dir)
                allImages.append(contentsOf: subImages)
            }
            
            // 保存原始顺序
            originalImageOrder = allImages
            
            // 启用随机排序
            isRandomOrderEnabled = true
            
            // 对图片列表进行随机排序
            allImages = randomizeImageOrder(allImages)
            
            // 保存所有扫描到的图片
            allScannedImages = allImages
            
            // 只显示初始数量的图片
            let initialImages = Array(allScannedImages.prefix(maxInitialImages))
            
            // 更新显示状态
            self.images = initialImages
            self.directoryGroups = [DirectoryGroup(name: directory.lastPathComponent, images: initialImages)]
            
            // 检查是否可以加载更多
            canLoadMore = allScannedImages.count > initialImages.count
            
            UnifiedCacheManager.shared.clearAllCaches()
            
            if !self.images.isEmpty && self.selectedImages.isEmpty {
                self.selectedImages.insert(self.images[0].id)
                self.lastSelectedIndex = 0
            }
            
            self.isLoading = false
            
            if self.images.isEmpty {
                self.errorMessage = ImageBrowserViewModelConstants.ErrorMessages.emptyDirectory
            }
            
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = String(format: ImageBrowserViewModelConstants.ErrorMessages.directoryLoadFailed, error.localizedDescription)
            }
        }
    }
    
    private func scanDirectoryRecursively(_ directory: URL) -> [ImageItem] {
        var images: [ImageItem] = []
        
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [])
            
            for url in contents {
                if images.count >= maxInitialImages {
                    break
                }
                
                let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == true {
                    let subImages = scanDirectoryRecursively(url)
                    let remainingCapacity = maxInitialImages - images.count
                    if remainingCapacity > 0 {
                        images.append(contentsOf: subImages.prefix(remainingCapacity))
                    }
                } else if isImageFile(url) {
                    images.append(ImageItem(url: url, directoryName: directory.lastPathComponent))
                }
            }
        } catch {
        }
        
        return images
    }
    
    // 完整扫描目录，不限制数量
    private func scanDirectoryRecursivelyComplete(_ directory: URL) -> [ImageItem] {
        var images: [ImageItem] = []
        
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [])
            
            for url in contents {
                let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == true {
                    let subImages = scanDirectoryRecursivelyComplete(url)
                    images.append(contentsOf: subImages)
                } else if isImageFile(url) {
                    images.append(ImageItem(url: url, directoryName: directory.lastPathComponent))
                }
            }
        } catch {
        }
        
        return images
    }
    
    // 高效随机排序算法
    private func randomizeImageOrder(_ images: [ImageItem]) -> [ImageItem] {
        guard images.count > 1 else { return images }
        
        var shuffled = images
        
        // 使用Fisher-Yates洗牌算法，时间复杂度O(n)
        for i in stride(from: shuffled.count - 1, through: 1, by: -1) {
            let j = Int.random(in: 0...i)
            shuffled.swapAt(i, j)
        }
        
        return shuffled
    }
    
    private func isImageFile(_ url: URL) -> Bool {
        let fileExtension = url.pathExtension.lowercased()
        return imageExtensions.contains(fileExtension)
    }
    
    func toggleViewMode() {
        isSingleViewMode.toggle()
        if isSingleViewMode {
            UnifiedWindowManager.shared.recordListWindowSize(groupId: currentDirectory?.path)
            isFirstTimeInSingleView = true
            isReturningFromSingleView = false  // 进入单页时清除返回标记
        } else {
            // 设置从单页返回状态标记
            isReturningFromSingleView = true
            
            UnifiedWindowManager.shared.restoreListWindowSize(groupId: currentDirectory?.path)
            updateSelectionFromSingleView()
            UnifiedWindowManager.shared.updateTitle()
            isFirstTimeInSingleView = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + ImageBrowserViewModelConstants.viewSwitchDelay) {
                NotificationCenter.default.post(name: NSNotification.Name("SetFocusToListView"), object: nil)
            }
            
            // 延迟清除返回标记，确保在窗口恢复期间不会误触发加载
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.isReturningFromSingleView = false
            }
        }
        
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func ensureFullDirectoryContent() {
        // 如果当前显示的不是完整目录内容，重新加载完整内容
        if images.count < allScannedImages.count {
            print(String(format: ImageBrowserViewModelConstants.LogMessages.returnFromSingleView, images.count, allScannedImages.count))
            images = allScannedImages
            
            // 更新目录组以显示完整内容
            if let directory = currentDirectory {
                directoryGroups = [DirectoryGroup(name: directory.lastPathComponent, images: allScannedImages)]
            }
        }
    }
    
    private func updateSelectionFromSingleView() {
        guard images.indices.contains(currentImageIndex) else { 
            return 
        }
        
        let currentImage = images[currentImageIndex]
        let currentImageId = currentImage.id
        
        UnifiedWindowManager.shared.addToScrollHistory(currentImageIndex)
        
        selectedImages = [currentImageId]
        lastSelectedIndex = currentImageIndex
        
        // 直接调用滚动请求，移除冗余的重试机制
        UnifiedWindowManager.shared.handleReturnFromSingleViewWithIndex(currentImageIndex)
    }
    
    func getPreviousScrollPosition() -> Int? {
        return UnifiedWindowManager.shared.getPreviousScrollPosition()
    }
    
    func clearScrollHistory() {
        UnifiedWindowManager.shared.clearScrollHistory()
    }
    
    var scrollSpeedValue: Double { 
        UnifiedWindowManager.shared.scrollSpeedValue
    }
    var autoScrollEnabledValue: Bool { 
        UnifiedWindowManager.shared.autoScrollEnabledValue
    }
    var showScrollIndicatorValue: Bool { 
        UnifiedWindowManager.shared.showScrollIndicatorValue
    }
    var scrollAnimationDurationValue: Double { 
        UnifiedWindowManager.shared.scrollAnimationDurationValue
    }
    var enableKeyboardNavigationValue: Bool { 
        UnifiedWindowManager.shared.enableKeyboardNavigationValue
    }
    var scrollSensitivityValue: Double { 
        UnifiedWindowManager.shared.scrollSensitivityValue
    }
    
    var adjustedScrollDuration: Double {
        UnifiedWindowManager.shared.adjustedScrollDuration
    }
    
    func adjustedScrollOffset(_ baseOffset: CGFloat) -> CGFloat {
        UnifiedWindowManager.shared.adjustedScrollOffset(baseOffset)
    }
    
    func scrollToImage(at index: Int, options: ScrollOptions = .immediate) {
        UnifiedWindowManager.shared.scrollToImage(at: index, options: options)
    }
    
    func verifyScrollExecution(at index: Int) -> Bool {
        UnifiedWindowManager.shared.verifyScrollExecution(at: index)
    }
    
    func selectImage(at index: Int) {
        
        stopAutoPlay()

        guard images.indices.contains(index) else { 
            return 
        }
        currentImageIndex = index
        isSingleViewMode = true
        isReturningFromSingleView = false  // 进入单页时清除返回标记
        
        UnifiedWindowManager.shared.recordListWindowSize(groupId: currentDirectory?.path)
        
        isFirstTimeInSingleView = true
        
        let currentImage = images[index]
        UnifiedWindowManager.shared.updateTitle(for: currentImage, index: index, total: allScannedImages.count)
    }
    
    func nextImage() {
        guard !images.isEmpty else { return }
        let newIndex = (currentImageIndex + 1) % images.count
        currentImageIndex = newIndex
        
        if isSingleViewMode {
            let currentImage = images[newIndex]
            UnifiedWindowManager.shared.updateTitle(for: currentImage, index: newIndex, total: allScannedImages.count)
        }
    }
    
    func previousImage() {
        guard !images.isEmpty else { return }
        let newIndex = (currentImageIndex - 1 + images.count) % images.count
        currentImageIndex = newIndex
        
        if isSingleViewMode {
            let currentImage = images[newIndex]
            UnifiedWindowManager.shared.updateTitle(for: currentImage, index: newIndex, total: allScannedImages.count)
        }
    }
    
    func startAutoPlay() {
        guard !images.isEmpty else { return }
        stopAutoPlay()
        showProgressBar = true
        
        let speed = autoPlayInterval
        autoPlayTimer = Timer.scheduledTimer(withTimeInterval: speed, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.nextImage()
            }
        }
        isAutoPlaying = true
    }
    
    func stopAutoPlay() {
        isAutoPlaying = false
        showProgressBar = false
        autoPlayTimer?.invalidate()
        autoPlayTimer = nil
    }
    
    func toggleAutoPlay() {
        if isAutoPlaying {
            stopAutoPlay()
        } else {
            startAutoPlay()
        }
    }
    
    func toggleImageSelection(at index: Int, withShift: Bool = false, withCommand: Bool = false) {
        guard images.indices.contains(index) else { return }
        let imageId = images[index].id
        
        if withCommand {
            if selectedImages.contains(imageId) {
                selectedImages.remove(imageId)
            } else {
                selectedImages.insert(imageId)
            }
        } else if withShift {
            let startIndex = min(lastSelectedIndex, index)
            let endIndex = max(lastSelectedIndex, index)
            
            for i in startIndex...endIndex {
                if images.indices.contains(i) {
                    selectedImages.insert(images[i].id)
                }
            }
        } else {
            selectedImages = [imageId]
        }
        
        lastSelectedIndex = index
    }
    
    func toggleImageSelectionWithoutScroll(at index: Int, withShift: Bool = false, withCommand: Bool = false) {
        guard images.indices.contains(index) else { return }
        let imageId = images[index].id
        
        if withCommand {
            if selectedImages.contains(imageId) {
                selectedImages.remove(imageId)
            } else {
                selectedImages.insert(imageId)
            }
        } else if withShift {
            let startIndex = min(lastSelectedIndex, index)
            let endIndex = max(lastSelectedIndex, index)
            
            for i in startIndex...endIndex {
                if images.indices.contains(i) {
                    selectedImages.insert(images[i].id)
                }
            }
        } else {
            selectedImages = [imageId]
        }
        
        lastSelectedIndex = index
    }
    
    func clearSelection() {
        selectedImages.removeAll()
    }
    
    // 加载更多图片
    func loadMoreImages() {
        guard canLoadMore && !isLoadingMore else { return }
        
        isLoadingMore = true
        
        // 计算下一页的起始位置
        let startIndex = images.count
        let endIndex = min(startIndex + PaginationConfig.pageSize, allScannedImages.count)
        
        guard startIndex < endIndex else {
            isLoadingMore = false
            canLoadMore = false
            return
        }
        
        // 添加下一页的图片
        let newImages = Array(allScannedImages[startIndex..<endIndex])
        images.append(contentsOf: newImages)
        
        // 更新目录分组（简化处理，将所有图片放在一个分组）
        directoryGroups = [DirectoryGroup(name: currentDirectory?.lastPathComponent ?? "", images: images)]
        
        // 更新分页状态
        currentPage += 1
        canLoadMore = endIndex < allScannedImages.count
        isLoadingMore = false
        
        print(String(format: ImageBrowserViewModelConstants.LogMessages.loadMoreImages, startIndex, endIndex-1, images.count))
    }
    
    private func getFirstSelectedIndex() -> Int {
        guard let firstSelectedId = selectedImages.first,
              let index = images.firstIndex(where: { $0.id == firstSelectedId }) else {
            return 0
        }
        return index
    }
    
    func navigateSelection(direction: Direction) {
        guard !images.isEmpty else { return }
        
        let currentIndex = lastSelectedIndex
        var newIndex = currentIndex
        
        switch direction {
        case .left:
            newIndex = min(images.count - 1, currentIndex + 1)
        case .right:
            newIndex = max(0, currentIndex - 1)
        case .up:
            newIndex = max(0, currentIndex - ImageBrowserViewModelConstants.keyboardNavigationStep)
        case .down:
            newIndex = min(images.count - 1, currentIndex + ImageBrowserViewModelConstants.keyboardNavigationStep)
        }
        
        selectedImages.removeAll()
        selectedImages.insert(images[newIndex].id)
        lastSelectedIndex = newIndex
        
        UnifiedWindowManager.shared.scrollToImage(at: newIndex)
    }
    
    func revealInFinder(at index: Int) {
        guard images.indices.contains(index) else { return }
        let image = images[index]
        NSWorkspace.shared.selectFile(image.url.path, inFileViewerRootedAtPath: image.url.deletingLastPathComponent().path)
    }
    
    func deleteSelectedImages() {
        guard !selectedImages.isEmpty else { return }
        
        let fileManager = FileManager.default
        var deletedCount = 0
        
        for imageId in selectedImages {
            if let image = images.first(where: { $0.id == imageId }) {
                do {
                    try fileManager.trashItem(at: image.url, resultingItemURL: nil)
                    deletedCount += 1
                } catch {
                    DispatchQueue.main.async {
                        self.errorMessage = String(format: ImageBrowserViewModelConstants.ErrorMessages.imageDeleteFailed, error.localizedDescription)
                    }
                    return
                }
            }
        }
        
        DispatchQueue.main.async {
            self.images.removeAll { self.selectedImages.contains($0.id) }
            self.selectedImages.removeAll()
            
            if deletedCount > 0 {
            }
        }
    }
    
    func deleteImage(at index: Int) {
        guard images.indices.contains(index) else { return }
        let image = images[index]
        
        do {
            try FileManager.default.trashItem(at: image.url, resultingItemURL: nil)
            
            var updatedGroups = directoryGroups
            for i in 0..<updatedGroups.count {
                updatedGroups[i].images.removeAll { $0.id == image.id }
            }
            
            updatedGroups.removeAll { $0.images.isEmpty }
            
            directoryGroups = updatedGroups
            images = updatedGroups.flatMap { $0.images }
            
            selectedImages.remove(image.id)
            
        } catch {
        }
    }
    
    
    private var scrollProxy: Any?
    
    func setScrollProxy(_ proxy: Any) {
        scrollProxy = proxy
    }
    
    func clearScrollProxy() {
        scrollProxy = nil
    }
    
    func handleScrollToIndex(_ targetIndex: Int) {
        UnifiedWindowManager.shared.scrollToImage(at: targetIndex, options: .delayed)
    }
    
    func handleSelectionChange(_ selectedImages: Set<UUID>) {
        UnifiedWindowManager.shared.handleSelectionChange(selectedImages, images: images)
    }
    
    deinit {
        autoPlayTimer?.invalidate()
        autoPlayTimer = nil
    }
       
    func selectDirectory() {
        // 清空当前选中的图片
        self.selectedImages.removeAll()
        
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [
            .jpeg, .png, .gif, .bmp, .tiff
        ]
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            // 检查选择的是文件还是目录
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue {
                    // 选择的是目录
                    loadImages(from: url)
                } else {
                    // 选择的是单个图片文件
                    let directoryURL = url.deletingLastPathComponent()
                    loadImages(from: directoryURL)
                    
                    // 查找图片在列表中的位置并自动显示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        if let index = self.images.firstIndex(where: { $0.url == url }) {
                            self.selectImage(at: index)
                        }
                    }
                }
            }
        }
    }
    
    
    let baseThumbnailSize: CGFloat = 200 // 基础缩略图尺寸（100%） - 改为公开属性，让ListView可以访问
    
    
    func loadThumbnail(for imageItem: ImageItem, size: CGSize, completion: @escaping (NSImage?) -> Void) {
        if let cachedThumbnail = UnifiedCacheManager.shared.getCachedThumbnail(for: imageItem, size: size) {
            completion(cachedThumbnail)
            return
        }
        
        UnifiedCacheManager.shared.loadThumbnail(for: imageItem, size: size) { thumbnail in
            DispatchQueue.main.async {
                completion(thumbnail)
            }
        }
    }
    
    var thumbnailSize: CGFloat {
        let minSize = baseThumbnailSize * 0.5  // 50% of base
        let maxSize = baseThumbnailSize * 2.0  // 200% of base
        return max(minSize, min(maxSize, manualThumbnailSize))
    }
    
    
    func handleKeyPress(_ key: String) {
        
        switch key {
        case "-":
            // 缩图大小基本是由listlayout决定,这个调整暂不处理
            // let newSize = manualThumbnailSize * 0.80
            // let minSize = baseThumbnailSize * 0.5
            
            // if newSize >= minSize {
            //     manualThumbnailSize = newSize
                
            //     // cacheManager.clearSmartRowCache()
                
            //     objectWillChange.send()
            // } else {
            // }
            break
        case "=":
            // 缩图大小基本是由listlayout决定,这个调整暂不处理
            // let newSize = manualThumbnailSize * 1.20
            // let maxSize = baseThumbnailSize * 2.0
            
            // if newSize <= maxSize {
            //     manualThumbnailSize = newSize
                
            //     // cacheManager.clearSmartRowCache()
                
            //     objectWillChange.send()
            // } else {
            // }
            break
        default:
            break
        }
        
    }
}

enum Direction {
    case up, down, left, right
}

struct ImageItem: Identifiable, Equatable {
    let id: UUID  // 使用UUID作为唯一标识
    let url: URL
    let directoryName: String
    let fileName: String
    let size: CGSize
    
    init(url: URL, directoryName: String) {
        self.url = url
        self.directoryName = directoryName
        self.fileName = url.lastPathComponent
        self.id = UUID()  // 生成唯一UUID
        
        if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
            let pixelWidth = properties[kCGImagePropertyPixelWidth as String] as? CGFloat ?? 0
            let pixelHeight = properties[kCGImagePropertyPixelHeight as String] as? CGFloat ?? 0
            self.size = CGSize(width: pixelWidth, height: pixelHeight)
        } else {
            self.size = CGSize.zero
        }
    }
    
    static func == (lhs: ImageItem, rhs: ImageItem) -> Bool {
        return lhs.id == rhs.id || lhs.url.path == rhs.url.path  // 同时比较UUID和文件路径
    }
}

struct DirectoryGroup: Identifiable {
    let id: String  // 使用目录路径作为ID，确保稳定性
    let name: String
    var images: [ImageItem]
    
    init(name: String, images: [ImageItem]) {
        self.name = name
        self.images = images
        self.id = name  // 使用目录名作为唯一标识
    }
}
