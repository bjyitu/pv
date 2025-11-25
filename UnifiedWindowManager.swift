import SwiftUI
import AppKit

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
        /// 超宽图片（宽高比 > 2.0）的边距配置
        static let ultraWide: (horizontal: CGFloat, vertical: CGFloat) = (40, 60)
        
        /// 宽图片（宽高比 > 1.5）的边距配置
        static let wide: (horizontal: CGFloat, vertical: CGFloat) = (30, 50)
        
        /// 窄图片（宽高比 < 0.8）的边距配置
        static let narrow: (horizontal: CGFloat, vertical: CGFloat) = (50, 30)
        
        /// 超窄图片（宽高比 < 0.5）的边距配置
        static let ultraNarrow: (horizontal: CGFloat, vertical: CGFloat) = (60, 40)
        
        /// 正常图片（宽高比 0.8-1.5）的边距配置
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
    
    private let minWindowWidth: CGFloat = UnifiedWindowManagerConstants.minWindowWidth
    private let minWindowHeight: CGFloat = UnifiedWindowManagerConstants.minWindowHeight
    private let maxScreenUsageRatio: CGFloat = UnifiedWindowManagerConstants.maxScreenUsageRatio
    
    private var currentGroupId: String?
    
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
        let screenSize = screen.visibleFrame.size
        let aspectRatio = imageSize.width / imageSize.height
        
        // 简化处理：根据宽高比设置不同的边距
        let margins: (horizontal: CGFloat, vertical: CGFloat)
        if aspectRatio > 2.0 {
            margins = UnifiedWindowManagerConstants.WindowMargins.ultraWide // 超宽图片
        } else if aspectRatio > 1.5 {
            margins = UnifiedWindowManagerConstants.WindowMargins.wide // 宽图片
        } else if aspectRatio < 0.5 {
            margins = UnifiedWindowManagerConstants.WindowMargins.ultraNarrow // 超窄图片
        } else if aspectRatio < 0.8 {
            margins = UnifiedWindowManagerConstants.WindowMargins.narrow // 窄图片
        } else {
            margins = UnifiedWindowManagerConstants.WindowMargins.normal // 正常图片
        }
        
        
        let maxUsableWidth = screenSize.width * maxScreenUsageRatio - margins.horizontal
        let maxUsableHeight = screenSize.height * maxScreenUsageRatio - margins.vertical
        
        let windowSize: CGSize
        
        let widthBasedHeight = maxUsableWidth / aspectRatio
        let widthBasedSize = CGSize(width: maxUsableWidth, height: widthBasedHeight)
        
        let heightBasedWidth = maxUsableHeight * aspectRatio
        let heightBasedSize = CGSize(width: heightBasedWidth, height: maxUsableHeight)
        
        if widthBasedSize.height <= maxUsableHeight {
            windowSize = widthBasedSize
        } else if heightBasedSize.width <= maxUsableWidth {
            windowSize = heightBasedSize
        } else {
            let widthRatio = maxUsableWidth / imageSize.width
            let heightRatio = maxUsableHeight / imageSize.height
            let scaleFactor = min(widthRatio, heightRatio)
            
            windowSize = CGSize(
                width: imageSize.width * scaleFactor,
                height: imageSize.height * scaleFactor
            )
        }
        
        let finalSize = CGSize(
            width: max(windowSize.width + margins.horizontal, minWindowWidth),
            height: max(windowSize.height + margins.vertical, minWindowHeight)
        )
        
        let targetX = (screenSize.width - finalSize.width) / 2 + screen.visibleFrame.origin.x
        let targetY = (screenSize.height - finalSize.height) / 2 + screen.visibleFrame.origin.y
        
        let result = NSRect(origin: NSPoint(x: targetX, y: targetY), size: finalSize)
        
        return result
    }
    
    func calculateDefaultWindowSize(for screen: NSScreen) -> NSRect {
        let screenSize = screen.visibleFrame.size
        let defaultWidth: CGFloat = UnifiedWindowManagerConstants.defaultWindowWidth
        let defaultHeight: CGFloat = UnifiedWindowManagerConstants.defaultWindowHeight
        
        let targetWidth = min(defaultWidth, screenSize.width * UnifiedWindowManagerConstants.WindowConfiguration.defaultScreenUsageRatio)
        let targetHeight = min(defaultHeight, screenSize.height * UnifiedWindowManagerConstants.WindowConfiguration.defaultScreenUsageRatio)
        
        let targetX = (screenSize.width - targetWidth) / 2 + screen.visibleFrame.origin.x
        let targetY = (screenSize.height - targetHeight) / 2 + screen.visibleFrame.origin.y
        
        return NSRect(
            origin: NSPoint(x: targetX, y: targetY),
            size: NSSize(width: targetWidth, height: targetHeight)
        )
    }
    
    
    func adjustWindowForImage(_ imageSize: CGSize, animated: Bool = false, shouldCenter: Bool = true) {
        guard let screen = getMainScreen() else { return }
        guard let window = getCurrentWindow() else { return }
        
        let targetFrame = calculateOptimalWindowSize(for: imageSize, screen: screen)
        
        let finalFrame: NSRect
        if shouldCenter {
            finalFrame = targetFrame
        } else {
            let currentFrame = window.frame
            finalFrame = NSRect(
                origin: currentFrame.origin,
                size: targetFrame.size
            )
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.0) { [weak window] in
            window?.setFrame(finalFrame, display: true, animate: false)  // 动画隔离测试：禁用窗口动画
        }
        
        currentImageSize = imageSize
    }
    
    func setToDefaultSize() {
        guard let screen = getMainScreen() else { return }
        let defaultFrame = calculateDefaultWindowSize(for: screen)
        setWindowFrame(defaultFrame)
    }
    
    func setWindowSize(_ size: CGSize) {
        guard let screen = getMainScreen() else { return }
        let screenFrame = screen.visibleFrame
        let targetFrame = NSRect(
            x: screenFrame.minX + (screenFrame.width - size.width) / 2,
            y: screenFrame.minY + (screenFrame.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        setWindowFrame(targetFrame)
    }
    
    // 统一的窗口框架设置方法，避免重复的窗口获取和设置逻辑
    private func setWindowFrame(_ frame: NSRect) {
        guard let window = getCurrentWindow() else { return }
        window.setFrame(frame, display: true, animate: false)  // 动画隔离测试：禁用窗口动画
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
        
        UnifiedCacheManager.shared.setRecordedListWindowSize(for: groupId, size: currentSize)
    }
    
    func restoreListWindowSize(groupId: String? = nil) {
        let groupId = groupId ?? currentGroupId
        guard let groupId = groupId else { return }
        
        if let cachedSize = UnifiedCacheManager.shared.getRecordedListWindowSize(for: groupId) {
            setWindowSize(cachedSize)
        }
    }
    
    func saveCurrentWindowFrame() {
        guard let window = getCurrentWindow() else { return }
        previousWindowFrame = window.frame
    }
    
    func restorePreviousWindowFrame() {
        guard let previousFrame = previousWindowFrame else { return }
        guard let window = getCurrentWindow() else { return }
        window.setFrame(previousFrame, display: true, animate: false)  // 动画隔离测试：禁用窗口动画
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
    
    func scrollToImage(at index: Int) {
        performScrollToImage(at: index)
    }
    
    func verifyScrollExecution(at index: Int) -> Bool {
        return shouldScrollToIndex == nil
    }
    
    func forceScrollToImage(at index: Int) {
        shouldScrollToIndex = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + UnifiedWindowManagerConstants.forceScrollDelay) { [weak self] in
            self?.performScrollToImage(at: index)
            self?.objectWillChange.send()
        }
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
    
    // 统一的滚动执行方法，避免重复的滚动状态设置逻辑
    func performScrollToImage(at index: Int, position: ScrollPosition = .center) {
        shouldScrollToIndex = index
        currentScrollPosition = index
        addToScrollHistory(index)
    }
    
    func handleScrollToIndex(_ targetIndex: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.performScrollToImage(at: targetIndex, position: .center)
        }
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
        scrollToImage(at: index)
    }
    
    @objc private func handleForceScrollToImageNotification(_ notification: Foundation.Notification) {
        guard let index = notification.object as? Int else { return }
        forceScrollToImage(at: index)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + UnifiedWindowManagerConstants.windowCloseDelay) {
            if NSApplication.shared.windows.isEmpty {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
