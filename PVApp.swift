import SwiftUI

@main
struct PVApp: App {
    @StateObject private var windowManager = UnifiedWindowManager.shared
    @StateObject private var viewModel = ImageBrowserViewModel()
    
    // MARK: - 启动配置常量
    private struct LaunchConfiguration {
        struct Delays {
            /// 初始文件处理延迟（秒）- 等待应用完全启动后再处理启动参数
            static let initialFileProcessing: Double = 0.5
            /// 部分加载后重试延迟（秒）- 在图片列表部分加载后尝试定位图片
            static let retryAfterPartialLoad: Double = 0.1
            /// 完整扫描后重试延迟（秒）- 在触发完整目录扫描后再次尝试定位图片
            static let retryAfterFullScan: Double = 0.1
        }
        
        /// 最大重试尝试次数 - 控制图片定位的重试逻辑
        static let maxRetryAttempts = 3
    }
    
    var body: some Scene {
        WindowGroup {
            StartView(viewModel: viewModel)
                .environmentObject(windowManager)
                .onAppear {
                    windowManager.initializeWindow()
                    handleLaunchArguments()
                }
        }
        .windowStyle(DefaultWindowStyle())
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .newItem) {
                Button("打开...") {
                    NotificationCenter.default.post(name: UnifiedWindowManager.Notification.selectDirectory, object: nil)
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
                
                DispatchQueue.main.asyncAfter(deadline: .now() + LaunchConfiguration.Delays.initialFileProcessing) {
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
            viewModel.loadImages(from: fileURL)
        case .file:
            // 打开单个图片文件
            let directoryURL = fileURL.deletingLastPathComponent()
            viewModel.loadImages(from: directoryURL)
            
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
        guard attempt < LaunchConfiguration.maxRetryAttempts else { return }
        
        let delay = calculateDelay(for: attempt)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if let index = self.viewModel.images.firstIndex(where: { $0.url == fileURL }) {
                self.viewModel.selectImage(at: index)
            } else {
                // 在第二次尝试时触发完整目录扫描
                if attempt == 1 {
                    self.viewModel.ensureFullDirectoryContent()
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
            return LaunchConfiguration.Delays.retryAfterPartialLoad
        case 2:
            return LaunchConfiguration.Delays.retryAfterFullScan
        default:
            return 0
        }
    }
}