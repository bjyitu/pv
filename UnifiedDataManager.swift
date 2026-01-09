import SwiftUI
import Foundation

/// 统一数据管理器 - 负责图片数据加载、文件操作和数据管理
@MainActor
class UnifiedDataManager: ObservableObject {
    
    // MARK: - 发布属性
    
    /// 当前显示的图片列表
    @Published var images: [ImageItem] = []
    
    /// 按目录分组的图片
    @Published var directoryGroups: [DirectoryGroup] = []
    
    /// 当前目录
    @Published var currentDirectory: URL?
    
    /// 加载状态
    @Published var isLoading: Bool = false
    
    /// 错误消息
    @Published var errorMessage: String?
    
    /// 分页状态：是否可以加载更多
    @Published var canLoadMore = false
    
    /// 分页状态：是否正在加载更多
    @Published var isLoadingMore = false
    
    // MARK: - 私有属性
    
    /// 所有扫描到的图片（用于分页）
    private var allScannedImages: [ImageItem] = []
    
    /// 当前页码
    private var currentPage = 0
    
    /// 支持的图片文件扩展名
    private let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp"]
    
    /// 分页配置
    private struct PaginationConfig {
        // 环境变量优先，便于测试
        static let initialLoadCount: Int = {
            ProcessInfo.processInfo.environment[AppConstants.Pagination.initialLoadCountEnvironmentVariable].flatMap(Int.init) ?? AppConstants.Pagination.defaultInitialLoadCount
        }()
        
        static let pageSize: Int = AppConstants.Pagination.pageSize
        
        // 与CacheManager协调，确保不超过缓存限制
        static var effectiveInitialLoadCount: Int {
            return min(initialLoadCount, UnifiedCacheManagerConstants.CacheConfig.maxCacheSize / 2)
        }
    }
    
    /// 最大初始加载图片数量
    private let maxInitialImages = PaginationConfig.effectiveInitialLoadCount
    
    // MARK: - 计算属性
    
    /// 目录中实际图片总数
    var totalImagesInDirectory: Int {
        return allScannedImages.count
    }
    
    /// 检查是否有内容显示
    var hasContent: Bool {
        return !images.isEmpty && !isLoading
    }
    
    // MARK: - 初始化
    
    static let shared = UnifiedDataManager()
    
    private init() {}
    
    // MARK: - 目录加载和扫描
    
    /// 从指定目录加载图片
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
            
            // 按文件名排序，确保顺序一致（支持数字排序）
            let sortedContents = (contents as NSArray).sortedArray(using: [NSSortDescriptor(key: "lastPathComponent", ascending: true, selector: #selector(NSString.localizedStandardCompare))]) as! [URL]
            
            var directories: [URL] = []
            var imageFiles: [URL] = []
            
            for url in sortedContents {
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
            
            // 随机排序所有扫描到的图片
            // let randomizedImages = randomizeImageOrder(allImages)
            
            // 保存所有扫描到的图片
            // allScannedImages = randomizedImages
            
            // 不随机排序
            allScannedImages = allImages
            
            // 只显示初始数量的图片
            let initialImages = Array(allScannedImages.prefix(maxInitialImages))
            
            // 更新显示状态
            self.images = initialImages
            self.directoryGroups = [DirectoryGroup(name: directory.lastPathComponent, images: initialImages)]
            
            // 检查是否可以加载更多
            canLoadMore = allScannedImages.count > initialImages.count
            
            UnifiedCacheManager.shared.clearAllCaches()
            
            self.isLoading = false
            
            if self.images.isEmpty {
                self.errorMessage = AppConstants.ErrorMessages.emptyDirectory
            }
            
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = String(format: AppConstants.ErrorMessages.directoryLoadFailed, error.localizedDescription)
            }
        }
    }
    
    /// 完整扫描目录，不限制数量
    private func scanDirectoryRecursivelyComplete(_ directory: URL) -> [ImageItem] {
        var images: [ImageItem] = []
        
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [])
            
            // 按文件名排序，确保顺序一致（支持数字排序）
            let sortedContents = (contents as NSArray).sortedArray(using: [NSSortDescriptor(key: "lastPathComponent", ascending: true, selector: #selector(NSString.localizedStandardCompare))]) as! [URL]
            
            for url in sortedContents {
                let resourceValues = try url.resourceValues(forKeys: [.isDirectoryKey])
                if resourceValues.isDirectory == true {
                    let subImages = scanDirectoryRecursivelyComplete(url)
                    images.append(contentsOf: subImages)
                } else if isImageFile(url) {
                    images.append(ImageItem(url: url, directoryName: directory.lastPathComponent))
                }
            }
        } catch {
            // 忽略扫描错误，继续处理其他目录
        }
        
        return images
    }
    
    /// 检查是否为支持的图片文件
    private func isImageFile(_ url: URL) -> Bool {
        let fileExtension = url.pathExtension.lowercased()
        return imageExtensions.contains(fileExtension)
    }
    
    // MARK: - 随机排序
    
    /// 高效随机排序算法
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
    
    // MARK: - 分页加载
    
    /// 加载更多图片
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
    
    /// 确保显示完整目录内容
    func ensureFullDirectoryContent() {
        // 如果当前显示的不是完整目录内容，重新加载完整内容
        if images.count < allScannedImages.count {
            images = allScannedImages
            
            // 更新目录组以显示完整内容
            if let directory = currentDirectory {
                directoryGroups = [DirectoryGroup(name: directory.lastPathComponent, images: allScannedImages)]
            }
        }
    }
    
    // MARK: - 文件操作
    
    /// 删除指定索引的图片
    @MainActor
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
            
            // 更新allScannedImages数组，确保总数正确
            allScannedImages.removeAll { $0.id == image.id }
            
        } catch {
            // 处理删除失败的情况
            print("删除图片失败: \(error)")
        }
    }
    
    /// 在Finder中显示指定图片
    func revealInFinder(at index: Int) {
        // 确保在主线程执行
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            guard self.images.indices.contains(index) else {
                return
            }
            let image = self.images[index]
            
            // 使用activateFileViewerSelecting方法（更现代的方法）
            NSWorkspace.shared.activateFileViewerSelecting([image.url])
        }
    }
    
    /// 选择目录或图片文件
    func selectDirectory() {
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
                }
            }
        }
    }
    
    // MARK: - 数据查询
    
    /// 根据ID查找图片索引
    func indexOfImage(with id: UUID) -> Int? {
        return images.firstIndex { $0.id == id }
    }
    
    /// 根据URL查找图片索引
    func indexOfImage(with url: URL) -> Int? {
        return images.firstIndex { $0.url == url }
    }
    
    /// 获取指定索引的图片
    func image(at index: Int) -> ImageItem? {
        guard images.indices.contains(index) else { return nil }
        return images[index]
    }
    
    // MARK: - 数据清理
    
    /// 清空所有数据
    func clearAllData() {
        images = []
        directoryGroups = []
        currentDirectory = nil
        allScannedImages = []
        currentPage = 0
        canLoadMore = false
        isLoadingMore = false
        isLoading = false
        errorMessage = nil
        
        UnifiedCacheManager.shared.clearAllCaches()
    }
}