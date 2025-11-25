import Foundation
import AppKit
import SwiftUI

/// UnifiedCacheManager常量定义
struct UnifiedCacheManagerConstants {
    /// 缓存配置相关常量
    struct CacheConfig {
        /// 最大缓存项目数量
        static let maxCacheSize: Int = 2000
        /// 最大内存使用量（字节）- 8000MB
        static let maxMemoryUsage: Int = 8000 * 1024 * 1024
    }
    
    /// 队列相关常量
    struct Queues {
        /// 缓存队列标识符
        static let cacheQueueIdentifier = "com.pv.cache"
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
}

class UnifiedCacheManager: ObservableObject {
    static let shared = UnifiedCacheManager()
    
    static let maxCacheSize = UnifiedCacheManagerConstants.CacheConfig.maxCacheSize
    static let maxMemoryUsage = UnifiedCacheManagerConstants.CacheConfig.maxMemoryUsage // 8000MB
    
    private let thumbnailCache = NSCache<NSString, NSImage>()
    
    private var recordedListWindowSizes: [String: CGSize] = [:]
    
    private let cacheQueue = DispatchQueue(label: UnifiedCacheManagerConstants.Queues.cacheQueueIdentifier, attributes: .concurrent)
    
    private init() {
        thumbnailCache.countLimit = UnifiedCacheManager.maxCacheSize
        thumbnailCache.totalCostLimit = UnifiedCacheManager.maxMemoryUsage
    }
    
    func generateCacheKey(for imageItem: ImageItem, size: CGSize) -> String {
        return "\(imageItem.url.absoluteString)_\(size.width)x\(size.height)"
    }
    
    func shouldCleanupCache(currentCount: Int, currentMemoryUsage: Int) -> Bool {

        return currentCount > UnifiedCacheManager.maxCacheSize || currentMemoryUsage > UnifiedCacheManager.maxMemoryUsage
    }
    
    func getCachedThumbnail(for imageItem: ImageItem, size: CGSize) -> NSImage? {
        let key = generateCacheKey(for: imageItem, size: size) as NSString
        return thumbnailCache.object(forKey: key)
    }
    
    func setCachedThumbnail(_ image: NSImage, for imageItem: ImageItem, size: CGSize) {
        let key = generateCacheKey(for: imageItem, size: size) as NSString
        thumbnailCache.setObject(image, forKey: key)
    }
    
    func loadThumbnail(for imageItem: ImageItem, size: CGSize, completion: @escaping (NSImage?) -> Void) {
        let _ = generateCacheKey(for: imageItem, size: size)
        
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
    
    func clearThumbnailCache() {
        thumbnailCache.removeAllObjects()
    }
    
    func setRecordedListWindowSize(for groupId: String, size: CGSize) {
        cacheQueue.async(flags: .barrier) { [self] in
            self.recordedListWindowSizes[groupId] = size
        }
    }
    
    func getRecordedListWindowSize(for groupId: String) -> CGSize? {
        return cacheQueue.sync {
            return recordedListWindowSizes[groupId]
        }
    }
    
    func clearRecordedListWindowSize(for groupId: String) {
        cacheQueue.async(flags: .barrier) { [self] in
            self.recordedListWindowSizes.removeValue(forKey: groupId)
        }
    }
    
    func clearWindowSizeCache() {
        cacheQueue.async(flags: .barrier) { [self] in
            self.recordedListWindowSizes.removeAll()
        }
    }
    
    func clearAllCaches() {
        clearThumbnailCache()
        clearWindowSizeCache()
    }
}
