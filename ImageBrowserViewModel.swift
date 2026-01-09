import SwiftUI
import Foundation
import Combine

/// 图片浏览器视图模型常量定义
struct ImageBrowserViewModelConstants {
    /// 默认自动播放间隔时间（秒）
    static let defaultAutoPlayInterval: TimeInterval = 5.0
    
    /// 默认缩略图大小（像素）
    static let defaultThumbnailSize: CGFloat = 200
 
    /// 视图切换延迟时间（秒），用于确保焦点正确设置
    static let viewSwitchDelay: TimeInterval = 0.2
    

    
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
    
    // MARK: - 列表视图状态管理
    @Published var listViewState = ListViewState()
    
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
    @Published var isSmartLayoutEnabled: Bool = false // 默认使用网格
    
    @Published var isFirstTimeInSingleView = true
    
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
        } else {
            // 设置从单页返回状态标记
            isReturningFromSingleView = true
            
            UnifiedWindowManager.shared.restoreListWindowSize(groupId: currentDirectory?.path)
            updateSelectionFromSingleView()
            UnifiedWindowManager.shared.updateTitle()
            
            // 从单页返回时恢复之前保存的滚动位置
            let savedOffset = UnifiedWindowManager.shared.currentListScrollOffset
            listViewState.currentScrollOffset = savedOffset
            print("ViewModel: 从单页返回，恢复滚动位置: \(savedOffset)")
            //viewSwitchDelay0.2秒后, 通知列表视图设置焦点,isReturningFromSingleView 设成false
            DispatchQueue.main.asyncAfter(deadline: .now() + ImageBrowserViewModelConstants.viewSwitchDelay) {
                NotificationCenter.default.post(name: AppConstants.Notifications.setFocusToListView, object: nil)
                self.isReturningFromSingleView = false
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
        case .right:  // 右箭头
            newIndex = max(0, currentIndex - 1)
        case .left:   // 左箭头
            newIndex = min(images.count - 1, currentIndex + 1)
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
            
            // 清除被删除图片的单图视图缓存
             UnifiedCacheManager.shared.singleViewCacheManager.clearSingleViewCache()
             
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
                         
                         // 更新单图视图缓存
                         if isSingleViewMode {
                             // 异步更新缓存，确保UI线程不被阻塞
                             DispatchQueue.main.async {
                                 // 通知SingleImageView更新缓存
                                 NotificationCenter.default.post(name: Notification.Name("UpdateSingleViewCache"), object: nil)
                             }
                         }
                     }
                 } else {
                     // 没有剩余图片，清空选择
                     selectedImages.removeAll()
                     lastSelectedIndex = 0
                 }
             } else if lastSelectedIndex > index {
                 // 如果删除的图片在lastSelectedIndex之前，需要调整lastSelectedIndex
                 lastSelectedIndex = max(0, lastSelectedIndex - 1)
                 
                 // 更新单图视图缓存
                 if isSingleViewMode {
                     // 异步更新缓存，确保UI线程不被阻塞
                     DispatchQueue.main.async {
                         // 通知SingleImageView更新缓存
                         NotificationCenter.default.post(name: Notification.Name("UpdateSingleViewCache"), object: nil)
                     }
                 }
             }
        }
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
    
    // MARK: - 预加载和滚动相关方法
    
    /// 预加载目标区域
    func preloadTargetRegion(for targetIndex: Int) {
        guard targetIndex >= 0 && targetIndex < images.count else { return }
        
        // 根据目标位置智能调整预加载区域大小
        let regionSize = calculateOptimalRegionSize(for: targetIndex)
        let regionStart = max(0, targetIndex - regionSize)
        let regionEnd = min(images.count - 1, targetIndex + regionSize)
        
        // 标记该区域为预加载
        let regionKey = "region_\(regionStart)_\(regionEnd)"
        listViewState.preloadedRegions.insert(regionKey)
        
        // 触发数据加载（如果需要）
        checkAndLoadMoreData(for: regionEnd)
    }
    
    /// 计算最优的预加载区域大小
    private func calculateOptimalRegionSize(for targetIndex: Int) -> Int {
        guard images.count > 0 else { return 10 }
        
        let totalItems = images.count
        let relativePosition = CGFloat(targetIndex) / CGFloat(totalItems)
        
        // 根据目标位置调整区域大小
        if relativePosition < 0.1 || relativePosition > 0.9 {
            // 靠近边界时使用较小的区域头部或尾部10%的位置加载数量
            return 8
        } else if relativePosition < 0.2 || relativePosition > 0.8 {
            // 靠近边界但不在最边缘时使用中等区域
            return 12
        } else {
            // 中间区域使用较大的预加载区域
            return 15
        }
    }
    
    /// 检查并加载更多数据
    private func checkAndLoadMoreData(for regionEnd: Int) {
        if regionEnd >= images.count - 5 && canLoadMore && !isLoadingMore {
            // 如果预加载区域接近数据末尾，触发加载更多
            dataManager.loadMoreImages()
        }
    }
    
    /// 统一的窗口大小变化处理方法
    func handleWindowResizeStart(newSize: CGSize) {
        listViewState.isWindowResizing = true
        listViewState.availableWidth = newSize.width
        listViewState.hasReceivedGeometry = true
        
        // 使用 windowResizeTask 替代 Timer
        listViewState.windowResizeTask?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            self?.listViewState.isWindowResizing = false
            print("Window Resize: Resize completed")
        }
        listViewState.windowResizeTask = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.ListView.resizeEndDelay, execute: workItem)
        listViewState.lastWindowSize = newSize
    }
    
    /// 计算平均行高（用于预加载区域和可见范围计算）
    func computeAverageRowHeight(layoutCalculator: LayoutCalculatorProtocol) -> CGFloat {
        guard !directoryGroups.isEmpty else { return 150.0 }
        
        // 使用第一个组的前100行
        if let firstGroup = directoryGroups.first {
            let rows = layoutCalculator.getFixedGridRows(
                for: firstGroup,
                availableWidth: listViewState.availableWidth,
                hasReceivedGeometry: listViewState.hasReceivedGeometry
            )
            
            var sampleHeights: [CGFloat] = []
            for row in rows.prefix(100) { // 采样前100行
                if !row.imageSizes.isEmpty {
                    sampleHeights.append(row.imageSizes[0].height)
                }
            }
            
            if !sampleHeights.isEmpty {
                let averageHeight = sampleHeights.reduce(0, +) / CGFloat(sampleHeights.count)
                // print("ImageBrowserViewModel: 使用第一个组的前100行计算平均行高: \(averageHeight) (基于 \(sampleHeights.count) 行)")
                return averageHeight
            }
        }
        
        // 最后的回退值
        print("ImageBrowserViewModel: 使用默认平均行高: 150.0")
        return 150.0
    }
    
    // 动态计算平均行高 - 优化版本
    func calculateAverageRowHeight(layoutCalculator: LayoutCalculatorProtocol) -> CGFloat {
        // 1. 首先检查是否有缓存的平均行高可用
        // if let cachedAverageHeight = listViewState.cachedAverageRowHeight {
        //     return cachedAverageHeight
        // }
        
        // 2. 如果没有缓存，计算并缓存结果
        let averageHeight = computeAverageRowHeight(layoutCalculator: layoutCalculator)
        listViewState.cachedAverageRowHeight = averageHeight
        print("ImageBrowserViewModel: 计算平均行高: \(averageHeight)")
        return averageHeight
    }
    
    // 获取当前可见范围内的图片索引范围
    func getCurrentVisibleRange(layoutCalculator: LayoutCalculatorProtocol) -> ClosedRange<Int> {
        guard listViewState.viewportHeight > 0 else { return 0...0 }
        
        // 估算当前可见区域的起始和结束索引
        let scrollOffset = listViewState.currentScrollOffset
        
        // 修复滚动位置计算：scrollOffset 应该是正值，表示向下滚动的距离
        let visibleStartY = max(0, scrollOffset) // 确保不会出现负值
        let visibleEndY = visibleStartY + listViewState.viewportHeight
        
        // 动态计算平均行高，替代固定估算值
        let averageRowHeight = calculateAverageRowHeight(layoutCalculator: layoutCalculator)
        
        let startIndex = max(0, Int(visibleStartY / averageRowHeight))
        let endIndex = min(images.count - 1, Int(visibleEndY / averageRowHeight))
        
        return startIndex...endIndex
    }
}

enum Direction {
    case up, down, left, right
}

struct ImageItem: Identifiable {
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

// MARK: - ListViewState
/// ListView 的状态管理对象
class ListViewState: ObservableObject {
    @Published var availableWidth: CGFloat = 0
    @Published var hasReceivedGeometry: Bool = false
    @Published var isWindowResizing: Bool = false
    @Published var lastWindowSize: CGSize = .zero
    
    // 预加载和区域定位相关状态
    @Published var currentScrollOffset: CGFloat = 0
    @Published var viewportHeight: CGFloat = 0
    @Published var preloadedRegions: Set<String> = []
    
    // 缓存的平均行高，避免频繁重新计算
    var cachedAverageRowHeight: CGFloat? = nil
    
    // 滚动位置跟踪
    
    // 定时器和任务, 用于处理窗口大小变化
    var windowResizeTask: DispatchWorkItem? = nil
    var scrollTask: DispatchWorkItem? = nil
}
