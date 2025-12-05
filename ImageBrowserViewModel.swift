import SwiftUI
import Foundation
import Combine

/// 图片浏览器视图模型常量定义
struct ImageBrowserViewModelConstants {
    /// 默认自动播放间隔时间（秒）
    static let defaultAutoPlayInterval: TimeInterval = 3.0
    
    /// 默认缩略图大小（像素）
    static let defaultThumbnailSize: CGFloat = 200
 
    /// 视图切换延迟时间（秒），用于确保焦点正确设置
    static let viewSwitchDelay: TimeInterval = 0.2
    
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
    // MARK: - 数据管理器
    let dataManager = UnifiedDataManager.shared
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 发布属性（视图状态管理）
    
    @Published var isSingleViewMode = false
    @Published var isReturningFromSingleView = false  // 新增：从单页返回状态标记
    @Published var currentImageIndex = 0
    @Published var isAutoPlaying = false
    @Published var autoPlayInterval: TimeInterval = ImageBrowserViewModelConstants.defaultAutoPlayInterval
    @Published var showProgressBar = false
    
    @Published var selectedImages: Set<UUID> = []
    @Published var lastSelectedIndex: Int = 0
    
    @Published var manualThumbnailSize: CGFloat = ImageBrowserViewModelConstants.defaultThumbnailSize
    
    // 随机排序状态管理
    @Published var isRandomOrderEnabled: Bool = false
    private var originalImageOrder: [ImageItem] = []
    
    // 布局切换状态管理
    @Published var isSmartLayoutEnabled: Bool = true // 默认使用智能布局
    
    @Published var isFirstTimeInSingleView = true
    
    // 新增：统一管理列表视图状态，避免视图重建时状态丢失
    @Published var listViewState = ListViewState()
    
    private var autoPlayTimer: Timer?
    
    // MARK: - 初始化
    
    init() {
        // 监听数据管理器的变化并转发给视图
        dataManager.objectWillChange
            .sink { [weak self] () in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 数据相关属性（通过数据管理器代理）
    
    /// 当前显示的图片列表
    var images: [ImageItem] {
        dataManager.images
    }
    
    /// 按目录分组的图片
    var directoryGroups: [DirectoryGroup] {
        dataManager.directoryGroups
    }
    
    /// 当前目录
    var currentDirectory: URL? {
        dataManager.currentDirectory
    }
    
    /// 加载状态
    var isLoading: Bool {
        dataManager.isLoading
    }
    
    /// 错误消息
    var errorMessage: String? {
        dataManager.errorMessage
    }
    
    /// 分页状态：是否可以加载更多
    var canLoadMore: Bool {
        dataManager.canLoadMore
    }
    
    /// 分页状态：是否正在加载更多
    var isLoadingMore: Bool {
        dataManager.isLoadingMore
    }
        
    // MARK: - 计算属性（数据相关，通过数据管理器代理）
    
    /// 目录中实际图片总数
    var totalImagesInDirectory: Int {
        return dataManager.totalImagesInDirectory
    }
    
    /// 检查是否有内容显示
    var hasContent: Bool {
        return dataManager.hasContent
    }
    
    func toggleViewMode() {
        // 在切换视图模式前，保存当前滚动位置到全局管理器
        if !isSingleViewMode {
            // 即将进入单页视图，保存列表滚动位置
            UnifiedWindowManager.shared.updateListScrollOffset(listViewState.currentScrollOffset)
            print("ViewModel: 进入单页前保存滚动位置: \(listViewState.currentScrollOffset)")
        }
        
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
            
            // 从单页返回时恢复之前保存的滚动位置
            let savedOffset = UnifiedWindowManager.shared.currentListScrollOffset
            listViewState.currentScrollOffset = savedOffset
            print("ViewModel: 从单页返回，恢复滚动位置: \(savedOffset)")
            
            DispatchQueue.main.asyncAfter(deadline: .now() + ImageBrowserViewModelConstants.viewSwitchDelay) {
                NotificationCenter.default.post(name: AppConstants.Notifications.setFocusToListView, object: nil)
                // 延迟清除返回标记，确保在滚动完成期间不会误触发加载
                // 使用与滚动清理相同的延迟时间，确保滚动操作完成后再清除标记
                DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.ListView.scrollCleanup) {
                    self.isReturningFromSingleView = false
                }
            }
        }
        
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    

    
    private func updateSelectionFromSingleView() {
        guard images.indices.contains(currentImageIndex) else { 
            return 
        }
        
        let currentImage = images[currentImageIndex]
        let currentImageId = currentImage.id
        
        selectedImages = [currentImageId]
        lastSelectedIndex = currentImageIndex
        
        // 直接调用滚动请求，移除冗余的重试机制
        UnifiedWindowManager.shared.handleReturnFromSingleViewWithIndex(currentImageIndex)
    }
    

    
    private func updateWindowTitle(for index: Int) {
        guard images.indices.contains(index) else { return }
        let currentImage = images[index]
        UnifiedWindowManager.shared.updateTitle(for: currentImage, index: index, total: totalImagesInDirectory)
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
        
        updateWindowTitle(for: index)
    }
    
    func nextImage() {
        guard !images.isEmpty else { return }
        let newIndex = (currentImageIndex + 1) % images.count
        currentImageIndex = newIndex
        
        if isSingleViewMode {
            updateWindowTitle(for: newIndex)
        }
    }
    
    func previousImage() {
        guard !images.isEmpty else { return }
        let newIndex = (currentImageIndex - 1 + images.count) % images.count
        currentImageIndex = newIndex
        
        if isSingleViewMode {
            updateWindowTitle(for: newIndex)
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
    
    func clearSelection() {
        selectedImages.removeAll()
    }
    
    // 加载更多图片

    
    func navigateSelection(direction: Direction) {
        guard !images.isEmpty else { return }
        
        let currentIndex = lastSelectedIndex
        var newIndex = currentIndex
        
        switch direction {
        case .right:  // 向右：增加索引
            newIndex = min(images.count - 1, currentIndex + 1)
        case .left:   // 向左：减少索引
            newIndex = max(0, currentIndex - 1)
        case .up, .down:
            // 垂直导航暂不实现
            return
        }
        
        selectedImages.removeAll()
        selectedImages.insert(images[newIndex].id)
        lastSelectedIndex = newIndex
        
        UnifiedWindowManager.shared.scrollToImage(at: newIndex)
    }
    

    
    @MainActor
    func deleteImage(at index: Int) {
        guard images.indices.contains(index) else { return }
        let image = images[index]
        
        // 删除确认对话框
        let alert = NSAlert()
        alert.messageText = "确认删除"
        alert.informativeText = "确定要删除这张图片吗？此操作会将图片移到废纸篓。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        
        if alert.runModal() == .alertFirstButtonReturn {
            // 使用UnifiedDataManager处理删除操作
            dataManager.deleteImage(at: index)
            
            // 更新窗口标题栏中的总数信息
            if isSingleViewMode && !images.isEmpty {
                updateWindowTitle(for: lastSelectedIndex)
            }
            
            // 修复选择逻辑：删除后正确更新选择状态
            selectedImages.remove(image.id)
            
            // 如果删除的是当前选中的图片，需要重新设置选择
            if lastSelectedIndex == index {
                // 如果还有剩余图片，选择删除位置附近的图片
                if !images.isEmpty {
                    let newIndex = min(index, images.count - 1)
                    if newIndex >= 0 {
                        selectedImages.insert(images[newIndex].id)
                        lastSelectedIndex = newIndex
                        
                        // 通知窗口管理器滚动到新位置
                        UnifiedWindowManager.shared.scrollToImage(at: newIndex)
                    }
                } else {
                    // 没有剩余图片，清空选择
                    selectedImages.removeAll()
                    lastSelectedIndex = 0
                }
            } else if lastSelectedIndex > index {
                // 如果删除的图片在lastSelectedIndex之前，需要调整lastSelectedIndex
                lastSelectedIndex = max(0, lastSelectedIndex - 1)
            }
        }
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
    
    // 布局切换方法
    func toggleLayout() {
        isSmartLayoutEnabled.toggle()
        
        // 通知布局已更改，触发界面更新
        objectWillChange.send()
    }
    
    // 处理键盘按键事件
    func handleKeyPress(_ character: String) {
        switch character {
        case "-":  // 减号键 - 缩小缩略图
            manualThumbnailSize = max(50, manualThumbnailSize - 20)
        case "=":  // 等号键 - 放大缩略图
            manualThumbnailSize = min(400, manualThumbnailSize + 20)
        default:
            break
        }
        
        // 通知缩略图大小已更改，触发界面更新
        objectWillChange.send()
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
