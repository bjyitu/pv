import SwiftUI
import AppKit

/// 滚动选项配置，用于控制滚动行为
struct ScrollOptions: OptionSet {
    let rawValue: Int
    
    static let `default` = ScrollOptions([])
    static let force = ScrollOptions(rawValue: 1 << 0)  // 强制滚动，清除现有滚动状态
    static let delayed = ScrollOptions(rawValue: 1 << 1) // 延迟滚动
    
    static let immediate: ScrollOptions = [] // 立即滚动（默认）
    static let forceDelayed: ScrollOptions = [.force, .delayed] // 强制延迟滚动
}

/// 统一窗口管理器常量定义
struct UnifiedWindowManagerConstants {
    /// 窗口初始化延迟时间（秒），用于确保窗口正确配置
    static let windowInitializationDelay: TimeInterval = 0.05
    
    /// 最小窗口宽度（像素）
    static let minWindowWidth: CGFloat = 400
    
    /// 最小窗口高度（像素）
    static let minWindowHeight: CGFloat = 300
    
    /// 最大屏幕使用比例（0.0-1.0），控制窗口占屏幕的最大比例
    static let maxScreenUsageRatio: CGFloat = 0.95
    
    /// 默认窗口宽度（像素）
    static let defaultWindowWidth: CGFloat = 1200
    
    /// 默认窗口高度（像素）
    static let defaultWindowHeight: CGFloat = 800
    
    /// 滚动历史最大记录数量
    static let maxScrollHistoryCount: Int = 500
    
    /// 强制滚动延迟时间（秒），用于避免滚动冲突
    static let forceScrollDelay: TimeInterval = 0.1
    
    /// 滚动状态清理延迟时间（秒），用于管理滚动状态
    static let scrollStateCleanupDelay: TimeInterval = 0.5
    
    /// 窗口关闭延迟时间（秒），用于确保应用正确退出
    static let windowCloseDelay: TimeInterval = 0.1
    
    /// 默认窗口标题
    static let defaultWindowTitle: String = "图片浏览器"
    
    /// 窗口边距配置结构体
    struct WindowMargins {
        // /// 超宽图片（宽高比 > 2.0）的边距配置
        // static let ultraWide: (horizontal: CGFloat, vertical: CGFloat) = (40, 60)
        
        // /// 宽图片（宽高比 > 1.5）的边距配置
        // static let wide: (horizontal: CGFloat, vertical: CGFloat) = (30, 50)
        
        // /// 窄图片（宽高比 < 0.8）的边距配置
        // static let narrow: (horizontal: CGFloat, vertical: CGFloat) = (50, 30)
        
        // /// 超窄图片（宽高比 < 0.5）的边距配置
        // static let ultraNarrow: (horizontal: CGFloat, vertical: CGFloat) = (60, 40)
        
        // /// 正常图片（宽高比 0.8-1.5）的边距配置
        static let normal: (horizontal: CGFloat, vertical: CGFloat) = (40, 40)
    }
    
    /// 窗口配置相关常量
    struct WindowConfiguration {
        /// 默认屏幕使用比例，用于计算默认窗口大小
        static let defaultScreenUsageRatio: CGFloat = 0.8
    }
}

@MainActor
class UnifiedWindowManager: ObservableObject {
    static let shared = UnifiedWindowManager()
    
    @Published var currentTitle: String = UnifiedWindowManagerConstants.defaultWindowTitle
    @Published var currentImageSize: CGSize?
    @Published var previousWindowFrame: NSRect?

    private var currentGroupId: String?
    
    // 窗口尺寸缓存
    @MainActor private var recordedListWindowSizes: [String: CGSize] = [:]
    
    private init() {
        setupNotificationObservers()
    }
    
    
    func initializeWindow() {
        DispatchQueue.main.asyncAfter(deadline: .now() + UnifiedWindowManagerConstants.windowInitializationDelay) { [weak self] in
            self?.configureWindow()
        }
    }
    
    private func configureWindow() {
        guard let window = getCurrentWindow() else { return }
        
        window.title = currentTitle
        window.isReleasedWhenClosed = false
        window.delegate = WindowDelegate.shared
        
        window.titlebarAppearsTransparent = true
        
        if let contentView = window.contentView {
            contentView.wantsLayer = true
            contentView.layer?.backgroundColor = NSColor.clear.cgColor
        }
    }
    
    
    private func getMainScreen() -> NSScreen? {
        return NSScreen.main
    }
    
    func getCurrentWindow() -> NSWindow? {
        return NSApp.keyWindow ?? NSApp.windows.first
    }
    
    
    func updateTitle(for image: ImageItem? = nil, index: Int? = nil, total: Int? = nil) {
        if let image = image, let index = index, let total = total {
            currentTitle = "\(index + 1)/\(total) - \(image.fileName)"
        } else {
            currentTitle = "图片浏览器"
        }
        
        updateWindowTitle()
    }
    
    func updateTitleForDirectory(_ directoryURL: URL) {
        currentTitle = "图片浏览器 - \(directoryURL.lastPathComponent)"
        updateWindowTitle()
    }
    
    private func updateWindowTitle() {
        if let window = self.getCurrentWindow() {
            window.title = self.currentTitle
        }
    }
    
    
    func calculateOptimalWindowSize(for imageSize: CGSize, screen: NSScreen) -> NSRect {
        let aspectRatio = imageSize.width / imageSize.height
        let margins = UnifiedWindowManagerConstants.WindowMargins.normal
        
        // 使用辅助函数计算最大可用尺寸
        let maxUsableSize = calculateMaxUsableSize(in: screen, margins: margins)
        
        // 使用辅助函数计算基于宽高比的窗口尺寸
        let windowSize = calculateWindowSizeForAspectRatio(aspectRatio, maxSize: maxUsableSize)
        
        // 应用最小窗口尺寸限制
        let finalSize = CGSize(
            width: max(windowSize.width + margins.horizontal, UnifiedWindowManagerConstants.minWindowWidth),
            height: max(windowSize.height + margins.vertical, UnifiedWindowManagerConstants.minWindowHeight)
        )
        
        // 使用辅助函数计算中心位置
        return calculateCenteredFrame(for: finalSize, in: screen)
    }
    
    func calculateDefaultWindowSize(for screen: NSScreen) -> NSRect {
        let screenSize = screen.visibleFrame.size
        let defaultWidth: CGFloat = UnifiedWindowManagerConstants.defaultWindowWidth
        let defaultHeight: CGFloat = UnifiedWindowManagerConstants.defaultWindowHeight
        
        let targetWidth = min(defaultWidth, screenSize.width * UnifiedWindowManagerConstants.WindowConfiguration.defaultScreenUsageRatio)
        let targetHeight = min(defaultHeight, screenSize.height * UnifiedWindowManagerConstants.WindowConfiguration.defaultScreenUsageRatio)
        
        let targetSize = CGSize(width: targetWidth, height: targetHeight)
        
        // 使用辅助函数计算中心位置
        return calculateCenteredFrame(for: targetSize, in: screen)
    }
    
    
    // MARK: - 统一的窗口设置接口
    
    /// 设置窗口框架
    /// - Parameters:
    ///   - frame: 目标窗口框架
    ///   - animated: 是否启用动画
    func setWindowFrame(_ frame: NSRect, animated: Bool = false) {
        guard let window = getCurrentWindow() else { return }
        window.setFrame(frame, display: true, animate: animated)
    }
    
    /// 设置窗口大小（保持当前位置）
    /// - Parameters:
    ///   - size: 目标窗口大小
    ///   - animated: 是否启用动画
    func setWindowSize(_ size: CGSize, animated: Bool = false) {
        guard let window = getCurrentWindow() else { return }
        let currentFrame = window.frame
        let targetFrame = NSRect(origin: currentFrame.origin, size: size)
        setWindowFrame(targetFrame, animated: animated)
    }
    
    /// 设置窗口大小并居中显示
    /// - Parameters:
    ///   - size: 目标窗口大小
    ///   - animated: 是否启用动画
    func setWindowSizeCentered(_ size: CGSize, animated: Bool = false) {
        guard let screen = getMainScreen() else { return }
        let targetFrame = calculateCenteredFrame(for: size, in: screen)
        setWindowFrame(targetFrame, animated: animated)
    }
    
    /// 设置默认窗口大小并居中显示
    /// - Parameters:
    ///   - animated: 是否启用动画
    func setToDefaultSize(animated: Bool = false) {
        guard let screen = getMainScreen() else { return }
        let defaultFrame = calculateDefaultWindowSize(for: screen)
        setWindowFrame(defaultFrame, animated: animated)
    }
    
    /// 根据图片尺寸调整窗口大小
    /// - Parameters:
    ///   - imageSize: 图片尺寸
    ///   - animated: 是否启用动画
    ///   - shouldCenter: 是否居中显示
    func adjustWindowForImage(_ imageSize: CGSize, animated: Bool = false, shouldCenter: Bool = true) {
        guard let screen = getMainScreen() else { return }
        guard let window = getCurrentWindow() else { return }
        
        let targetFrame = calculateOptimalWindowSize(for: imageSize, screen: screen)
        
        let finalFrame: NSRect
        if shouldCenter {
            finalFrame = targetFrame
        } else {
            let currentFrame = window.frame
            finalFrame = NSRect(origin: currentFrame.origin, size: targetFrame.size)
        }
        
        setWindowFrame(finalFrame, animated: animated)
        currentImageSize = imageSize
    }
    
    // 计算窗口在屏幕中心的位置
    private func calculateCenteredFrame(for size: CGSize, in screen: NSScreen) -> NSRect {
        let screenSize = screen.visibleFrame.size
        let targetX = (screenSize.width - size.width) / 2 + screen.visibleFrame.origin.x
        let targetY = (screenSize.height - size.height) / 2 + screen.visibleFrame.origin.y
        
        return NSRect(origin: NSPoint(x: targetX, y: targetY), size: size)
    }
    
    // 计算最大可用尺寸（考虑屏幕使用比例和边距）
    private func calculateMaxUsableSize(in screen: NSScreen, margins: (horizontal: CGFloat, vertical: CGFloat)) -> CGSize {
        let screenSize = screen.visibleFrame.size
        let maxUsableWidth = screenSize.width * UnifiedWindowManagerConstants.maxScreenUsageRatio - margins.horizontal
        let maxUsableHeight = screenSize.height * UnifiedWindowManagerConstants.maxScreenUsageRatio - margins.vertical
        
        return CGSize(width: maxUsableWidth, height: maxUsableHeight)
    }
    
    // 计算基于宽高比的窗口尺寸
    private func calculateWindowSizeForAspectRatio(_ aspectRatio: CGFloat, maxSize: CGSize) -> CGSize {
        let widthBasedHeight = maxSize.width / aspectRatio
        let widthBasedSize = CGSize(width: maxSize.width, height: widthBasedHeight)
        
        let heightBasedWidth = maxSize.height * aspectRatio
        let heightBasedSize = CGSize(width: heightBasedWidth, height: maxSize.height)
        
        if widthBasedSize.height <= maxSize.height {
            return widthBasedSize
        } else if heightBasedSize.width <= maxSize.width {
            return heightBasedSize
        } else {
            // 如果两种方式都不合适，使用缩放因子
            let widthRatio = maxSize.width / (maxSize.width * aspectRatio)
            let heightRatio = maxSize.height / (maxSize.height / aspectRatio)
            let scaleFactor = min(widthRatio, heightRatio)
            
            return CGSize(
                width: maxSize.width * aspectRatio * scaleFactor,
                height: maxSize.height / aspectRatio * scaleFactor
            )
        }
    }
    
    
    func recordListWindowSize(groupId: String? = nil) {
        let groupId = groupId ?? currentGroupId
        
        guard let groupId = groupId else {
            return
        }
        
        guard let window = getCurrentWindow() else {
            return
        }
        
        let currentSize = CGSize(width: window.frame.width, height: window.frame.height)
        
        setRecordedListWindowSize(for: groupId, size: currentSize)
    }
    
    func restoreListWindowSize(groupId: String? = nil) {
        let groupId = groupId ?? currentGroupId
        guard let groupId = groupId else { return }
        
        if let cachedSize = getRecordedListWindowSize(for: groupId) {
            setWindowSizeCentered(cachedSize)
        }
    }
    
    func saveCurrentWindowFrame() {
        guard let window = getCurrentWindow() else { return }
        previousWindowFrame = window.frame
    }
    
    func restorePreviousWindowFrame() {
        guard let previousFrame = previousWindowFrame else { return }
        setWindowFrame(previousFrame, animated: false)
    }
    
    
    @Published var shouldScrollToIndex: Int?
    @Published var currentScrollPosition: Int? = nil
    private var isScrollingInProgress = false  // 新增：滚动状态标记
    @Published var scrollHistory: [Int] = []
    
    static private let sharedAppSettings = AppSettings()
    
    var scrollSpeedValue: Double { 
        Self.sharedAppSettings.scrollSpeed
    }
    var autoScrollEnabledValue: Bool { 
        Self.sharedAppSettings.autoScrollEnabled
    }
    var showScrollIndicatorValue: Bool { 
        Self.sharedAppSettings.showScrollIndicator
    }
    var scrollAnimationDurationValue: Double { 
        Self.sharedAppSettings.scrollAnimationDuration
    }
    var enableKeyboardNavigationValue: Bool { 
        Self.sharedAppSettings.enableKeyboardNavigation
    }
    var scrollSensitivityValue: Double { 
        Self.sharedAppSettings.scrollSensitivity
    }
    
    var adjustedScrollDuration: Double {
        Self.sharedAppSettings.scrollAnimationDuration / Self.sharedAppSettings.scrollSpeed
    }
    
    func adjustedScrollOffset(_ baseOffset: CGFloat) -> CGFloat {
        baseOffset * Self.sharedAppSettings.scrollSensitivity
    }
    
    // 统一的滚动方法，通过参数控制行为
    func scrollToImage(at index: Int, 
                      options: ScrollOptions = .default) {
        
        // 检查是否需要强制滚动（清除现有滚动状态）
        if options.contains(.force) {
            shouldScrollToIndex = nil
        }
        
        // 检查是否允许滚动（没有进行中的滚动请求）
        guard options.contains(.force) || shouldScrollToIndex == nil else {
            return
        }
        
        // 设置滚动状态
        shouldScrollToIndex = index
        currentScrollPosition = index
        addToScrollHistory(index)
        
        // 处理延迟滚动
        if options.contains(.delayed) {
            let delay = options.contains(.force) ? 
                UnifiedWindowManagerConstants.forceScrollDelay : 0.1
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.objectWillChange.send()
            }
        }
    }
    
    func verifyScrollExecution(at index: Int) -> Bool {
        return shouldScrollToIndex == nil
    }
    
    func addToScrollHistory(_ index: Int) {
        if scrollHistory.last != index {
            scrollHistory.append(index)
            
            if scrollHistory.count > UnifiedWindowManagerConstants.maxScrollHistoryCount {
                scrollHistory.removeFirst()
            }
        }
    }
    
    func getPreviousScrollPosition() -> Int? {
        guard scrollHistory.count >= 2 else { return nil }
        return scrollHistory[scrollHistory.count - 2]
    }
    
    func clearScrollHistory() {
        scrollHistory.removeAll()
        currentScrollPosition = nil
    }
    
    func handleSelectionChange(_ selectedImages: Set<UUID>, images: [ImageItem]) {
        if shouldScrollToIndex == nil,  // 只有在没有显式滚动请求时才处理
           let firstSelectedId = selectedImages.first,
           let index = images.firstIndex(where: { $0.id == firstSelectedId }) {
            shouldScrollToIndex = index
        }
    }
    
    func hasPendingScrollRequest() -> Bool {
        return shouldScrollToIndex != nil
    }
    
    func handleReturnFromSingleViewWithIndex(_ index: Int) {
        // 防止重复的程序化滚动请求，但不影响用户手动滚动
        guard !isScrollingInProgress else { return }
        
        // 添加检查：如果已经有相同的滚动请求在进行中，则不再重复设置
        if shouldScrollToIndex == index {
            return
        }
        
        isScrollingInProgress = true
        shouldScrollToIndex = index
        currentScrollPosition = index
        
        // 统一管理所有状态的清理 - 延迟后同时清理两个状态
        DispatchQueue.main.asyncAfter(deadline: .now() + UnifiedWindowManagerConstants.scrollStateCleanupDelay) { [weak self] in
            self?.isScrollingInProgress = false
            self?.shouldScrollToIndex = nil
        }
    }
    
    // 新增：专门处理用户手动滚动的方法
    func handleUserScrollRequest() {
        // 用户手动滚动时，清除程序化滚动状态
        isScrollingInProgress = false
        shouldScrollToIndex = nil
    }
    
    
    func updateCurrentImageSize(_ size: CGSize?) {
        currentImageSize = size
    }
    
    func setCurrentGroupId(_ groupId: String) {
        self.currentGroupId = groupId
    }
    
    // MARK: - 窗口尺寸缓存管理
    
    /// 设置记录的列表窗口尺寸
    /// - Parameters:
    ///   - groupId: 分组标识符
    ///   - size: 窗口尺寸
    func setRecordedListWindowSize(for groupId: String, size: CGSize) {
        Task { @MainActor in
            recordedListWindowSizes[groupId] = size
        }
    }
    
    /// 获取记录的列表窗口尺寸
    /// - Parameter groupId: 分组标识符
    /// - Returns: 窗口尺寸，如果不存在则返回nil
    func getRecordedListWindowSize(for groupId: String) -> CGSize? {
        return recordedListWindowSizes[groupId]
    }
    
    /// 清除指定分组的窗口尺寸缓存
    /// - Parameter groupId: 分组标识符
    func clearRecordedListWindowSize(for groupId: String) {
        Task { @MainActor in
            recordedListWindowSizes.removeValue(forKey: groupId)
        }
    }
    
    /// 清除所有窗口尺寸缓存
    func clearWindowSizeCache() {
        Task { @MainActor in
            recordedListWindowSizes.removeAll()
        }
    }
    
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAdjustWindowNotification(_:)),
            name: UnifiedWindowManager.Notification.adjustWindowForImage,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRestoreWindowNotification(_:)),
            name: UnifiedWindowManager.Notification.restorePreviousWindow,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSetDefaultSizeNotification(_:)),
            name: UnifiedWindowManager.Notification.setDefaultWindowSize,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRequestCurrentWindowSize(_:)),
            name: UnifiedWindowManager.Notification.requestCurrentWindowSize,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScrollToImageNotification(_:)),
            name: UnifiedWindowManager.Notification.scrollToImage,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForceScrollToImageNotification(_:)),
            name: UnifiedWindowManager.Notification.forceScrollToImage,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleClearScrollHistoryNotification(_:)),
            name: UnifiedWindowManager.Notification.clearScrollHistory,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleListWindowSizeRecorded(_:)),
            name: UnifiedWindowManager.Notification.listWindowSizeRecorded,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSelectDirectoryNotification(_:)),
            name: UnifiedWindowManager.Notification.selectDirectory,
            object: nil
        )
    }
    
    @objc private func handleAdjustWindowNotification(_ notification: Foundation.Notification) {
        guard let imageSize = notification.object as? CGSize else { return }
        adjustWindowForImage(imageSize)
    }
    
    @objc private func handleRestoreWindowNotification(_ notification: Foundation.Notification) {
        restorePreviousWindowFrame()
    }
    
    @objc private func handleSetDefaultSizeNotification(_ notification: Foundation.Notification) {
        setToDefaultSize()
    }
    
    @objc private func handleRequestCurrentWindowSize(_ notification: Foundation.Notification) {
        guard let window = getCurrentWindow() else { return }
        let windowSize = CGSize(width: window.frame.width, height: window.frame.height)
        
        if let callback = notification.userInfo?["callback"] as? String {
            switch callback {
            case "recordListWindowSize":
                NotificationCenter.default.post(
                    name: UnifiedWindowManager.Notification.listWindowSizeRecorded,
                    object: nil,
                    userInfo: ["size": windowSize]
                )
            default:
                break
            }
        } else {
            NotificationCenter.default.post(
                name: UnifiedWindowManager.Notification.windowSizeProvided,
                object: windowSize
            )
        }
    }
    
    @objc private func handleScrollToImageNotification(_ notification: Foundation.Notification) {
        guard let index = notification.object as? Int else { return }
        scrollToImage(at: index, options: .immediate)
    }
    
    @objc private func handleForceScrollToImageNotification(_ notification: Foundation.Notification) {
        guard let index = notification.object as? Int else { return }
        scrollToImage(at: index, options: .forceDelayed)
    }
    
    @objc private func handleClearScrollHistoryNotification(_ notification: Foundation.Notification) {
        clearScrollHistory()
    }
    
    @objc private func handleListWindowSizeRecorded(_ notification: Foundation.Notification) {
        if let groupId = notification.object as? String {
            currentGroupId = groupId
        }
    }
    
    @objc private func handleSelectDirectoryNotification(_ notification: Foundation.Notification) {
        if let directoryURL = notification.object as? URL {
            updateTitleForDirectory(directoryURL)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

enum ScrollPosition {
    case top
    case center
    case bottom
}

extension UnifiedWindowManager {
    struct Notification {
        static let adjustWindowForImage = Foundation.Notification.Name("adjustWindowForImage")
        static let restorePreviousWindow = Foundation.Notification.Name("restorePreviousWindow")
        static let setDefaultWindowSize = Foundation.Notification.Name("setDefaultWindowSize")
        static let requestCurrentWindowSize = Foundation.Notification.Name("requestCurrentWindowSize")
        static let windowSizeProvided = Foundation.Notification.Name("windowSizeProvided")
        static let listWindowSizeRecorded = Foundation.Notification.Name("listWindowSizeRecorded")
        static let selectDirectory = Foundation.Notification.Name("selectDirectory")
        
        static let scrollToImage = Foundation.Notification.Name("scrollToImage")
        static let forceScrollToImage = Foundation.Notification.Name("forceScrollToImage")
        static let clearScrollHistory = Foundation.Notification.Name("clearScrollHistory")
    }
}

class WindowDelegate: NSObject, NSWindowDelegate {
    static let shared = WindowDelegate()
    
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        return true
    }
    
    func windowWillClose(_ notification: Notification) {
        // 对于 SwiftUI WindowGroup，需要特殊处理
        DispatchQueue.main.asyncAfter(deadline: .now() + UnifiedWindowManagerConstants.windowCloseDelay) {
            // 检查所有窗口，包括可能隐藏的窗口
            let allWindows = NSApplication.shared.windows
            let visibleWindows = allWindows.filter { $0.isVisible }
            
            if visibleWindows.isEmpty {
                // 如果没有可见窗口，退出应用
                NSApplication.shared.terminate(nil)
            } else {
                // 如果有隐藏窗口，也检查是否需要退出
                // SwiftUI 可能会创建隐藏窗口用于管理
                let hasMainWindows = allWindows.contains { window in
                    window.isVisible && window.canBecomeMain
                }
                
                if !hasMainWindows {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }
}