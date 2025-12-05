import SwiftUI

@main
struct PVApp: App {
    @StateObject private var windowManager = UnifiedWindowManager.shared
    @StateObject private var viewModel = ImageBrowserViewModel()
    
    // MARK: - AppDelegate适配器（最小化改动）
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // 内部AppDelegate类，避免创建新文件
    class AppDelegate: NSObject, NSApplicationDelegate {
        func application(_ application: NSApplication, open urls: [URL]) {
            // 延迟处理，确保应用完全启动
            DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Delays.appLaunch) {
                // 通过通知中心转发文件打开请求
                NotificationCenter.default.post(
                    name: AppConstants.Notifications.fileOpenRequest,
                    object: urls
                )
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            StartView(viewModel: viewModel)
                .environmentObject(windowManager)
                .onAppear {
                    windowManager.initializeWindow()
                    handleLaunchArguments()
                    setupFileOpenNotification()
                }
        }
        .windowStyle(DefaultWindowStyle())
        // 防止文件打开时创建新窗口
        .handlesExternalEvents(matching: [])
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .newItem) {
                Button("打开...") {
                    NotificationCenter.default.post(name: AppConstants.Notifications.selectDirectory, object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
    
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
    }
    
    // MARK: - 启动参数处理
    func handleLaunchArguments() {
        let arguments = CommandLine.arguments
        guard arguments.count > 1 else { return }
        
        // 跳过第一个参数（应用路径），处理后续参数
        for argument in arguments.dropFirst() {
            if argument.hasPrefix("file://") || !argument.hasPrefix("-") {
                let fileURL = createURL(from: argument)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.Delays.initialFileProcessing) {
                    self.handleFileOpen(fileURL)
                }
                break // 只处理第一个文件参数
            }
        }
    }
    
    // MARK: - URL处理工具方法
    func createURL(from argument: String) -> URL {
        if argument.hasPrefix("file://") {
            return URL(string: argument)!
        } else {
            return URL(fileURLWithPath: argument)
        }
    }
    
    // MARK: - 文件打开处理
    private func handleFileOpen(_ fileURL: URL) {
        guard let fileType = getFileType(fileURL) else {
            return
        }
        
        switch fileType {
        case .directory:
            // 打开目录
            viewModel.dataManager.loadImages(from: fileURL)
        case .file:
            // 打开单个图片文件
            let directoryURL = fileURL.deletingLastPathComponent()
            viewModel.dataManager.loadImages(from: directoryURL)
            
            // 使用优化的定位方法
            locateAndSelectImage(fileURL, attempt: 0)
        }
    }
    
    // MARK: - 文件类型判断
    func getFileType(_ url: URL) -> FileType? {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
            return nil
        }
        
        return isDirectory.boolValue ? .directory : .file
    }
    
    // MARK: - 文件类型枚举
    enum FileType {
        case directory
        case file
    }
    
    // MARK: - 图片定位和选择（优化版）
    private func locateAndSelectImage(_ fileURL: URL, attempt: Int) {
        guard attempt < AppConstants.Pagination.maxRetryAttempts else { return }
        
        let delay = calculateDelay(for: attempt)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if let index = self.viewModel.images.firstIndex(where: { $0.url == fileURL }) {
                self.viewModel.selectImage(at: index)
            } else {
                // 在第二次尝试时触发完整目录扫描
                if attempt == 1 {
                    self.viewModel.dataManager.ensureFullDirectoryContent()
                }
                
                // 递归调用进行下一次尝试
                self.locateAndSelectImage(fileURL, attempt: attempt + 1)
            }
        }
    }
    
    // MARK: - 延迟计算
    func calculateDelay(for attempt: Int) -> Double {
        switch attempt {
        case 0:
            return 0 // 立即尝试
        case 1:
            return AppConstants.Delays.retryAfterPartialLoad
        case 2:
            return AppConstants.Delays.retryAfterFullScan
        default:
            return 0
        }
    }
    
    // MARK: - 文件打开通知处理
    private func setupFileOpenNotification() {
        NotificationCenter.default.addObserver(
            forName: AppConstants.Notifications.fileOpenRequest,
            object: nil,
            queue: .main
        ) { notification in
            guard let urls = notification.object as? [URL] else { return }
            
            // 使用现有的文件处理逻辑
            for url in urls {
                self.handleFileOpen(url)
            }
        }
    }
}