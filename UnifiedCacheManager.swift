import Foundation
import AppKit
import SwiftUI

/// UnifiedCacheManager常量定义
struct UnifiedCacheManagerConstants {
    /// 缓存配置相关常量
    struct CacheConfig {
        /// 最大缓存项目数量
        static let maxCacheSize: Int = 200
        /// 最大内存使用量（字节）- 2000MB
        static let maxMemoryUsage: Int = 2000 * 1024 * 1024
        /// 单图视图缓存最大数量
        static let singleViewMaxCacheSize: Int = 20
        /// 单图视图缓存最大内存使用量（字节）- 200MB
        static let singleViewMaxMemoryUsage: Int = 200 * 1024 * 1024
        
        /// 自动清理阈值 - 当缓存项超过此数量时触发清理
        static let autoCleanupThreshold: Int = 200
        /// 每次清理的缓存项数量
        static let cleanupBatchSize: Int = 100
    }
    
    /// 队列相关常量
    struct Queues {
        /// 缓存队列标识符
        static let cacheQueueIdentifier = "com.pv.cache"
        /// 单图视图缓存队列标识符
        static let singleViewCacheQueueIdentifier = "com.pv.singleview.cache"
    }
    
    /// 图像处理相关常量
    struct ImageProcessing {
        /// 缩略图选项配置
        static let thumbnailOptions: [String: Any] = [
            kCGImageSourceCreateThumbnailWithTransform as String: true,
            kCGImageSourceCreateThumbnailFromImageAlways as String: true
        ]
        
        /// 图像属性键
        struct PropertyKeys {
            /// 像素宽度属性键
            static let pixelWidth = kCGImagePropertyPixelWidth as String
            /// 像素高度属性键
            static let pixelHeight = kCGImagePropertyPixelHeight as String
            /// 缩略图最大像素尺寸属性键
            static let thumbnailMaxPixelSize = kCGImageSourceThumbnailMaxPixelSize as String
        }
    }
    
    /// 单图视图缓存相关常量
    struct SingleViewCache {
        /// 窗口大小缓存策略
        static let windowSizeBasedCache = true
        /// 缓存质量设置
        static let cacheQuality: CGFloat = 0.9
        /// 预加载图片数量
        static let preloadCount: Int = 3
    }
}

/// 单图视图专用缓存管理器
class SingleViewCacheManager {
    static let shared = SingleViewCacheManager()
    
    private let singleViewImageCache = NSCache<NSString, NSImage>()
    private let cacheQueue = DispatchQueue(label: UnifiedCacheManagerConstants.Queues.singleViewCacheQueueIdentifier, attributes: .concurrent)
    private var currentWindowSize: CGSize = .zero
    private var cachedWindowSize: CGSize = .zero
    
    private init() {
        singleViewImageCache.countLimit = UnifiedCacheManagerConstants.CacheConfig.singleViewMaxCacheSize
        singleViewImageCache.totalCostLimit = UnifiedCacheManagerConstants.CacheConfig.singleViewMaxMemoryUsage
    }
    
    // MARK: - 窗口大小管理
    
    func updateWindowSize(_ size: CGSize) {
        cacheQueue.async(flags: .barrier) { [weak self] in
            self?.currentWindowSize = size
            
            // 如果窗口大小变化超过阈值，清理缓存
            if let cachedSize = self?.cachedWindowSize {
                let widthDiff = abs(size.width - cachedSize.width)
                let heightDiff = abs(size.height - cachedSize.height)
                
                // 如果窗口大小变化超过10%，清理缓存避免缓存污染
                if widthDiff > cachedSize.width * 0.1 || heightDiff > cachedSize.height * 0.1 {
                    self?.clearSingleViewCache()
                    self?.cachedWindowSize = size
                }
            } else {
                self?.cachedWindowSize = size
            }
        }
    }
    
    // MARK: - 缓存键生成
    
    func generateSingleViewCacheKey(for imageItem: ImageItem, windowSize: CGSize) -> String {
        let sizeKey = "\(Int(windowSize.width))x\(Int(windowSize.height))"
        return "singleview_\(imageItem.url.absoluteString)_\(sizeKey)"
    }
    
    // MARK: - 缓存操作
    
    func getCachedSingleViewImage(for imageItem: ImageItem) -> NSImage? {
        let key = generateSingleViewCacheKey(for: imageItem, windowSize: currentWindowSize) as NSString
        return singleViewImageCache.object(forKey: key)
    }
    
    func setCachedSingleViewImage(_ image: NSImage, for imageItem: ImageItem) {
        let key = generateSingleViewCacheKey(for: imageItem, windowSize: currentWindowSize) as NSString
        singleViewImageCache.setObject(image, forKey: key)
    }
    
    // MARK: - 图片加载
    
    func loadSingleViewImage(for imageItem: ImageItem, completion: @escaping (NSImage?) -> Void) {
        // 首先检查缓存
        if let cached = getCachedSingleViewImage(for: imageItem) {
            DispatchQueue.main.async {
                completion(cached)
            }
            return
        }
        
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            let imageSource = CGImageSourceCreateWithURL(imageItem.url as CFURL, nil)
            guard let imageSource = imageSource else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            // 使用窗口大小作为目标尺寸
            let targetSize = self.currentWindowSize
            
            // 计算适合窗口的图片尺寸，保持宽高比
            let aspectRatio = imageItem.size.width / imageItem.size.height
            let windowAspectRatio = targetSize.width / targetSize.height
            
            let finalSize: CGSize
            if aspectRatio > windowAspectRatio {
                // 图片更宽，以宽度为基准
                finalSize = CGSize(width: targetSize.width, height: targetSize.width / aspectRatio)
            } else {
                // 图片更高，以高度为基准
                finalSize = CGSize(width: targetSize.height * aspectRatio, height: targetSize.height)
            }
            
            // 创建高质量缩略图选项
            var options = UnifiedCacheManagerConstants.ImageProcessing.thumbnailOptions
            options[UnifiedCacheManagerConstants.ImageProcessing.PropertyKeys.thumbnailMaxPixelSize] = max(finalSize.width, finalSize.height)
            
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            let nsImage = NSImage(cgImage: cgImage, size: finalSize)
            
            DispatchQueue.main.async { [weak self] in
                self?.setCachedSingleViewImage(nsImage, for: imageItem)
                completion(nsImage)
            }
        }
    }
    
    // MARK: - 预加载管理
    
    func preloadImages(for imageItems: [ImageItem], around index: Int) {
        let preloadCount = UnifiedCacheManagerConstants.SingleViewCache.preloadCount
        let startIndex = max(0, index - preloadCount)
        let endIndex = min(imageItems.count - 1, index + preloadCount)
        
        for i in startIndex...endIndex where i != index {
            let imageItem = imageItems[i]
            
            // 异步预加载
            cacheQueue.async { [weak self] in
                self?.loadSingleViewImage(for: imageItem) { _ in
                    // 预加载完成，不需要处理结果
                }
            }
        }
    }
    
    // MARK: - 缓存清理
    
    func clearSingleViewCache() {
        singleViewImageCache.removeAllObjects()
    }
    
    func clearAllCaches() {
        clearSingleViewCache()
    }
}

class UnifiedCacheManager: ObservableObject {
    static let shared = UnifiedCacheManager()
    
    private let thumbnailCache = NSCache<NSString, NSImage>()
    
    private let cacheQueue = DispatchQueue(label: UnifiedCacheManagerConstants.Queues.cacheQueueIdentifier, attributes: .concurrent)
    
    // 单图视图缓存管理器
    let singleViewCacheManager = SingleViewCacheManager.shared
    
    // 缓存访问追踪 - 用于LRU清理
    private var cacheAccessOrder: [String] = []
    private let accessOrderQueue = DispatchQueue(label: "com.pv.cache.access", attributes: .concurrent)
    private var currentCacheCount: Int = 0
    
    private init() {
        thumbnailCache.countLimit = UnifiedCacheManagerConstants.CacheConfig.maxCacheSize
        thumbnailCache.totalCostLimit = UnifiedCacheManagerConstants.CacheConfig.maxMemoryUsage
    }
    
    // MARK: - 缓存键生成
    
    func generateCacheKey(for imageItem: ImageItem, size: CGSize) -> String {
        return "\(imageItem.url.absoluteString)_\(size.width)x\(size.height)"
    }
    
    
    // MARK: - 缩略图缓存操作
    
    func getCachedThumbnail(for imageItem: ImageItem, size: CGSize) -> NSImage? {
        let key = generateCacheKey(for: imageItem, size: size) as NSString
        let result = thumbnailCache.object(forKey: key)
        
        // 如果缓存命中，更新访问顺序
        if result != nil {
            updateCacheAccessOrder(key: key as String)
        }
        
        return result
    }
    
    func setCachedThumbnail(_ image: NSImage, for imageItem: ImageItem, size: CGSize) {
        let key = generateCacheKey(for: imageItem, size: size) as NSString
        thumbnailCache.setObject(image, forKey: key)
        
        // 更新访问顺序并检查是否需要清理
        updateCacheAccessOrder(key: key as String)
        checkAndPerformAutoCleanup()
    }
    
    func loadThumbnail(for imageItem: ImageItem, size: CGSize, completion: @escaping (NSImage?) -> Void) {
        
        if let cached = getCachedThumbnail(for: imageItem, size: size) {
            DispatchQueue.main.async {
                completion(cached)
            }
            return
        }
        
        cacheQueue.async { [self] in
            let imageSource = CGImageSourceCreateWithURL(imageItem.url as CFURL, nil)
            guard let imageSource = imageSource else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any],
                  let pixelWidth = imageProperties[UnifiedCacheManagerConstants.ImageProcessing.PropertyKeys.pixelWidth] as? CGFloat,
                  let pixelHeight = imageProperties[UnifiedCacheManagerConstants.ImageProcessing.PropertyKeys.pixelHeight] as? CGFloat else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            let aspectRatio = pixelWidth / pixelHeight
            let thumbnailSize: CGSize
            if aspectRatio > 1 {
                thumbnailSize = CGSize(width: size.width, height: size.width / aspectRatio)
            } else {
                thumbnailSize = CGSize(width: size.height * aspectRatio, height: size.height)
            }
            
            var options = UnifiedCacheManagerConstants.ImageProcessing.thumbnailOptions
            options[UnifiedCacheManagerConstants.ImageProcessing.PropertyKeys.thumbnailMaxPixelSize] = max(thumbnailSize.width, thumbnailSize.height)
            
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
                DispatchQueue.main.async {
                    completion(nil)
                }
                return
            }
            
            let nsImage = NSImage(cgImage: cgImage, size: .zero)
            
            DispatchQueue.main.async { [self] in
                setCachedThumbnail(nsImage, for: imageItem, size: size)
                completion(nsImage)
            }
        }
    }
    
    // MARK: - 缓存访问追踪和自动清理
    
    /// 更新缓存访问顺序（LRU算法）
    private func updateCacheAccessOrder(key: String) {
        accessOrderQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // 如果key已存在，先移除旧的
            if let existingIndex = self.cacheAccessOrder.firstIndex(of: key) {
                self.cacheAccessOrder.remove(at: existingIndex)
            }
            
            // 添加到队列末尾（最新访问）
            self.cacheAccessOrder.append(key)
            
            // 更新当前缓存数量
            self.currentCacheCount = self.cacheAccessOrder.count
        }
    }
    
    /// 检查并执行自动清理
    private func checkAndPerformAutoCleanup() {
        accessOrderQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            // 检查是否需要清理
            if self.cacheAccessOrder.count > UnifiedCacheManagerConstants.CacheConfig.autoCleanupThreshold {
                self.performAutoCleanup()
            }
        }
    }
    
    /// 执行自动清理 - 清理最早的缓存项
    private func performAutoCleanup() {
        let cleanupCount = min(UnifiedCacheManagerConstants.CacheConfig.cleanupBatchSize, 
                              self.cacheAccessOrder.count / 2)
        
        guard cleanupCount > 0 else { return }
        
        // 获取要清理的key（最早的访问项）
        let keysToRemove = Array(self.cacheAccessOrder.prefix(cleanupCount))
        
        // 从缓存中移除
        for key in keysToRemove {
            self.thumbnailCache.removeObject(forKey: key as NSString)
        }
        
        // 从访问顺序中移除
        self.cacheAccessOrder.removeFirst(cleanupCount)
        
        // 更新当前缓存计数
        self.currentCacheCount = self.cacheAccessOrder.count
        
        print("缓存自动清理完成：移除了 \(keysToRemove.count) 个最早缓存项，剩余 \(self.cacheAccessOrder.count) 个")
    }
    
    // MARK: - 缓存清理
    
    func clearThumbnailCache() {
        accessOrderQueue.async(flags: .barrier) { [weak self] in
            self?.cacheAccessOrder.removeAll()
            self?.currentCacheCount = 0
        }
        thumbnailCache.removeAllObjects()
    }
    
    func clearAllCaches() {
        clearThumbnailCache()
        singleViewCacheManager.clearAllCaches()
    }
}