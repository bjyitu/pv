import SwiftUI

class LayoutCalculatorJus: LayoutCalculatorProtocol {
    
    // 新的细粒度缓存结构
    private struct LayoutCacheKey: Hashable {
        let imageCount: Int
        let availableWidth: Int // 使用整数避免浮点精度问题
        let targetHeight: Int
        let spacing: Int
        
        init(imageCount: Int, availableWidth: CGFloat, targetHeight: CGFloat, spacing: CGFloat) {
            self.imageCount = imageCount
            self.availableWidth = Int(availableWidth * 10) // 保留1位小数精度
            self.targetHeight = Int(targetHeight)
            self.spacing = Int(spacing * 10) // 保留1位小数精度
        }
    }
    
    private struct LayoutCacheValue {
        let row: FixedGridRow
        let fillRate: CGFloat
        let timestamp: Date
    }
    
    // 新的缓存存储 - 细粒度缓存
    private var rowCache: [LayoutCacheKey: LayoutCacheValue] = [:]
    private var lruKeys: [LayoutCacheKey] = [] // LRU 列表
    private let maxCacheSize = 1000 // 限制布局缓存数量
    
    // 布局约束常量
    private enum LayoutConstraints {
        static let minRowHeight: CGFloat = 120 //80
        static let maxRowHeight: CGFloat = 300
        static let minRowHeightRange: CGFloat = 240
        static let maxRowHeightRange: CGFloat = 300
        //尝试第二次最多8张图,如果第一次没有合适的高度,则尝试第二次,减少这个可以减少搜索范围降低计算量
        static let maxImagePerRowNumberTryAgain: Int = 8
        //尝试第一次最多10张图,减少这个可以减少搜索范围降低计算量
        static let maxImagePerRowNumberTryFirst: Int = 10
        //从5改为10,减少计算次数
        static let heightRangeStep: CGFloat = 10
    }
    
    // 新增缓存管理方法
    private func getCachedRow(key: LayoutCacheKey) -> FixedGridRow? {
        guard let cached = rowCache[key] else { return nil }
        
        // 更新LRU顺序
        if let index = lruKeys.firstIndex(of: key) {
            lruKeys.remove(at: index)
        }
        lruKeys.append(key)
        
        return cached.row
    }
    
    private func cacheRow(key: LayoutCacheKey, row: FixedGridRow, fillRate: CGFloat) {
        // 清理过期缓存
        if rowCache.count >= maxCacheSize {
            if let oldestKey = lruKeys.first {
                rowCache.removeValue(forKey: oldestKey)
                lruKeys.removeFirst()
            }
        }
        
        rowCache[key] = LayoutCacheValue(row: row, fillRate: fillRate, timestamp: Date())
        lruKeys.append(key)
    }
    
    func createSmartRows(from images: [ImageItem], availableWidth: CGFloat, thumbnailSize: CGFloat) -> [FixedGridRow] {
        var rows: [FixedGridRow] = []
        let spacing = AppConstants.ListView.spacing
        
        var imageIndex = 0
        while imageIndex < images.count {
            let optimalRow = findOptimalRow(
                images: Array(images[imageIndex...]),
                availableWidth: availableWidth,
                baseHeight: thumbnailSize,
                spacing: spacing
            )
            
            if !optimalRow.images.isEmpty {
                rows.append(optimalRow)
                imageIndex += optimalRow.images.count
            } else {
                let fallbackRow = createJustifiedRow(
                    images: [images[imageIndex]],
                    availableWidth: availableWidth,
                    targetHeight: thumbnailSize,
                    spacing: spacing
                )
                rows.append(fallbackRow)
                imageIndex += 1
            }
        }
        
        return rows
    }
    
    private func findOptimalRow(images: [ImageItem], availableWidth: CGFloat, baseHeight: CGFloat, spacing: CGFloat) -> FixedGridRow {
        guard !images.isEmpty else { return FixedGridRow(images: [], imageSizes: [], totalWidth: 0) }
        
        // 检查缓存
        let cacheKey = LayoutCacheKey(imageCount: images.count, availableWidth: availableWidth, targetHeight: baseHeight, spacing: spacing)
        if let cachedRow = getCachedRow(key: cacheKey) {
            return cachedRow
        }
        
        var bestRow: FixedGridRow? = nil
        var bestFillRate: CGFloat = 0
        
        let heightRange = stride(from: max(LayoutConstraints.minRowHeightRange, baseHeight * 0.8), through: min(LayoutConstraints.maxRowHeightRange, baseHeight * 1.2), by: LayoutConstraints.heightRangeStep)

        for targetHeight in heightRange {
            for imageCount in 1...min(images.count, LayoutConstraints.maxImagePerRowNumberTryFirst) {
                let testImages = Array(images.prefix(imageCount))
                let testRow = createJustifiedRow(images: testImages, availableWidth: availableWidth, targetHeight: targetHeight, spacing: spacing)
                
                let fillRate = testRow.totalWidth / availableWidth
                
                if fillRate >= 0.85 && fillRate <= 1.0 {
                    if fillRate > bestFillRate {
                        bestRow = testRow
                        bestFillRate = fillRate
                    }
                }
            }
        }
        
        if let bestRow = bestRow {
            // 缓存最优结果
            cacheRow(key: cacheKey, row: bestRow, fillRate: bestFillRate)
            return bestRow
        }
        
        let maxImagesPerRow = min(images.count, LayoutConstraints.maxImagePerRowNumberTryAgain)
        var bestFallbackRow: FixedGridRow? = nil
        var bestFallbackFillRate: CGFloat = 0
        
        for imageCount in stride(from: maxImagesPerRow, through: 1, by: -1) {
            let testImages = Array(images.prefix(imageCount))
            let testRow = createJustifiedRow(images: testImages, availableWidth: availableWidth, targetHeight: baseHeight, spacing: spacing)
            
            let fillRate = testRow.totalWidth / availableWidth
            
            if fillRate >= 0.75 && fillRate <= 1.0 {
                // 缓存回退结果
                cacheRow(key: cacheKey, row: testRow, fillRate: fillRate)
                return testRow
            }
            
            if fillRate > bestFallbackFillRate {
                bestFallbackRow = testRow
                bestFallbackFillRate = fillRate
            }
        }
        
        let resultRow: FixedGridRow
        if let bestFallbackRow = bestFallbackRow {
            resultRow = bestFallbackRow
        } else {
            resultRow = createJustifiedRow(images: [images[0]], availableWidth: availableWidth, targetHeight: baseHeight, spacing: spacing)
        }
        
        // 缓存最终结果
        cacheRow(key: cacheKey, row: resultRow, fillRate: bestFallbackFillRate)
        return resultRow
    }
    

    
    private func createJustifiedRow(images: [ImageItem], availableWidth: CGFloat, targetHeight: CGFloat, spacing: CGFloat) -> FixedGridRow {
        guard !images.isEmpty else {
            return FixedGridRow(images: [], imageSizes: [], totalWidth: 0)
        }
        
        let aspectRatios = images.map { $0.size.width / $0.size.height }
        let totalAspectRatio = aspectRatios.reduce(0, +)
        
        let availableWidthForImages = availableWidth - spacing * CGFloat(images.count - 1)
        let idealHeight = availableWidthForImages / totalAspectRatio
        
        let finalHeight = max(LayoutConstraints.minRowHeight, min(LayoutConstraints.maxRowHeight, idealHeight))
        
        let imageSizes = aspectRatios.map { aspectRatio in
            CGSize(width: finalHeight * aspectRatio, height: finalHeight)
        }
        
        let totalWidth = imageSizes.reduce(0) { $0 + $1.width } + spacing * CGFloat(images.count - 1)
        
        if totalWidth > availableWidth {
            let scale = availableWidth / totalWidth
            let scaledHeight = finalHeight * scale
            
            if scaledHeight >= LayoutConstraints.minRowHeight {
                let scaledSizes = imageSizes.map { size in
                    CGSize(width: size.width * scale, height: scaledHeight)
                }
                return FixedGridRow(
                    images: images,
                    imageSizes: scaledSizes,
                    totalWidth: availableWidth
                )
            }
        }
        
        return FixedGridRow(
            images: images,
            imageSizes: imageSizes,
            totalWidth: totalWidth
        )
    }
    
    // 兼容 ListView 的接口方法 - 使用新的细粒度缓存
    func getFixedGridRows(for group: DirectoryGroup, availableWidth: CGFloat, hasReceivedGeometry: Bool) -> [FixedGridRow] {
        guard hasReceivedGeometry else { return [] }
        
        let effectiveWidth = calculateEffectiveWidth(availableWidth: availableWidth)
        let rows = createSmartRows(from: group.images, availableWidth: effectiveWidth, thumbnailSize: 200)
        
        return rows
    }
    
    // 计算有效宽度（扣除左右边距）
    func calculateEffectiveWidth(availableWidth: CGFloat) -> CGFloat {
        return availableWidth - (AppConstants.ListView.horizontalPadding * 2)
    }
    
    // 清除缓存（兼容接口）- 更新为新的缓存结构
    func clearCache() {
        rowCache.removeAll()
        lruKeys.removeAll()
    }
}