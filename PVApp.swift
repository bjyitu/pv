import SwiftUI

@main
struct PVApp: App {
    @StateObject private var windowManager = UnifiedWindowManager.shared
    @StateObject private var viewModel = ImageBrowserViewModel()
    
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
    
    private func handleLaunchArguments() {
        let arguments = CommandLine.arguments
        guard arguments.count > 1 else { return }
        
        // 跳过第一个参数（应用路径），处理后续参数
        for argument in arguments.dropFirst() {
            if argument.hasPrefix("file://") || !argument.hasPrefix("-") {
                // 处理文件路径
                let fileURL: URL
                if argument.hasPrefix("file://") {
                    fileURL = URL(string: argument)!
                } else {
                    fileURL = URL(fileURLWithPath: argument)
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.handleFileOpen(fileURL)
                }
                break // 只处理第一个文件参数
            }
        }
    }
    
    private func handleFileOpen(_ fileURL: URL) {
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        guard fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) else {
            return
        }
        
        if isDirectory.boolValue {
            // 打开目录
            viewModel.loadImages(from: fileURL)
        } else {
            // 打开单个图片文件 - 优化响应速度
            let directoryURL = fileURL.deletingLastPathComponent()
            viewModel.loadImages(from: directoryURL)
            
            // 立即尝试定位图片，减少等待时间
            DispatchQueue.main.async {
                if let index = self.viewModel.images.firstIndex(where: { $0.url == fileURL }) {
                    self.viewModel.selectImage(at: index)
                } else {
                    // 如果图片不在当前加载的列表中，等待完整扫描后重试
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        if let index = self.viewModel.images.firstIndex(where: { $0.url == fileURL }) {
                            self.viewModel.selectImage(at: index)
                        } else {
                            // 最终尝试：触发完整目录扫描
                            self.viewModel.ensureFullDirectoryContent()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                if let index = self.viewModel.images.firstIndex(where: { $0.url == fileURL }) {
                                    self.viewModel.selectImage(at: index)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
