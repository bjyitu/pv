import SwiftUI

/// 布局计算器 - 封装所有与布局相关的计算逻辑
class LayoutCalculator: LayoutCalculatorProtocol {
    // 布局缓存
    private var layoutCache: [String: [FixedGridRow]] = [:]
    
    /// 创建固定网格行
    func createFixedGridRows(from images: [ImageItem], availableWidth: CGFloat) -> [FixedGridRow] {
        var rows: [FixedGridRow] = []
        let targetImagesPerRow = ListViewConstants.imagesPerRow
        let effectiveWidth = calculateEffectiveWidth(availableWidth: availableWidth)
        
        // 计算每行应该包含的图片数量和尺寸
        var currentRowImages: [ImageItem] = []
        
        for image in images {
            currentRowImages.append(image)
            
            if currentRowImages.count == targetImagesPerRow {
                let imageSize = calculateImageSize(for: currentRowImages.count, availableWidth: availableWidth, from: images)
                // 为每张图片创建相同的尺寸数组
                let imageSizes = Array(repeating: imageSize, count: currentRowImages.count)
                rows.append(FixedGridRow(
                    images: currentRowImages,
                    imageSizes: imageSizes,
                    totalWidth: effectiveWidth
                ))
                currentRowImages = []
            }
        }
        
        // 添加最后一行（如果有剩余图片）
        if !currentRowImages.isEmpty {
            let imageSize = calculateImageSize(for: currentRowImages.count, availableWidth: availableWidth, from: images)
            // 为每张图片创建相同的尺寸数组
            let imageSizes = Array(repeating: imageSize, count: currentRowImages.count)
            rows.append(FixedGridRow(
                images: currentRowImages,
                imageSizes: imageSizes,
                totalWidth: effectiveWidth
            ))
        }
        
        return rows
    }
    
    /// 计算有效宽度（扣除左右边距）
    func calculateEffectiveWidth(availableWidth: CGFloat) -> CGFloat {
        return availableWidth - (ListViewConstants.horizontalPadding * 2)
    }
    
    /// 计算图片尺寸
    func calculateImageSize(for imagesCount: Int, availableWidth: CGFloat, from images: [ImageItem]) -> CGSize {
        let effectiveWidth = calculateEffectiveWidth(availableWidth: availableWidth)
        
        // 始终按照每行6张图片的标准来计算尺寸，确保布局一致性
        let standardImagesPerRow = ListViewConstants.imagesPerRow
        let totalSpacing = CGFloat(standardImagesPerRow - 1) * ListViewConstants.spacing
        let availableImageWidth = (effectiveWidth - totalSpacing) / CGFloat(standardImagesPerRow)
        
        // 采样前六张图片计算平均宽高比
        let sampleSize = min(images.count, 6) // 最多采样前六张
        var totalAspectRatio: CGFloat = 0.0
        
        for i in 0..<sampleSize {
            let image = images[i]
            totalAspectRatio += (image.size.width / image.size.height)
        }
        
        let averageAspectRatio = sampleSize > 0 ? totalAspectRatio / CGFloat(sampleSize) : 1.0
        
        // 使用平均宽高比确定图片尺寸
        return CGSize(width: availableImageWidth, height: availableImageWidth / averageAspectRatio)
    }
    
    /// 计算平均宽高比
    func calculateAverageAspectRatio(images: [ImageItem]) -> CGFloat {
        guard !images.isEmpty else { return 1.0 }
        
        // 限制样本数量，避免性能问题
        let sampleSize = min(images.count, ListViewConstants.maxAspectRatioSampleSize)
        var totalAspectRatio: CGFloat = 0.0
        
        for i in 0..<sampleSize {
            let image = images[i]
            totalAspectRatio += (image.size.width / image.size.height)
        }
        
        return totalAspectRatio / CGFloat(sampleSize)
    }
    
    /// 获取固定网格行（带缓存）
    func getFixedGridRows(for group: DirectoryGroup, availableWidth: CGFloat, hasReceivedGeometry: Bool) -> [FixedGridRow] {
        guard hasReceivedGeometry else { return [] }
        
        // 使用固定缓存键：布局结构固定，只缩放图片尺寸
        let cacheKey = "fixed_grid_layout"
        
        // 检查缓存是否存在
        if let cachedRows = layoutCache[cacheKey] {
            // 使用缓存的布局结构，只更新图片尺寸
            return cachedRows.map { cachedRow in
                let newImageSize = calculateImageSize(for: cachedRow.images.count, availableWidth: availableWidth, from: group.images)
                // 为每张图片创建相同的尺寸数组
                let newImageSizes = Array(repeating: newImageSize, count: cachedRow.images.count)
                
                return FixedGridRow(
                    images: cachedRow.images,
                    imageSizes: newImageSizes,
                    totalWidth: calculateEffectiveWidth(availableWidth: availableWidth)
                )
            }
        }
        
        // 第一次调用：创建固定布局结构
        let rows = createFixedGridRows(from: group.images, availableWidth: availableWidth)
        
        // 更新缓存
        layoutCache[cacheKey] = rows
        
        // 清理过期的缓存（只保留最近几个）
        if layoutCache.count > ListViewConstants.maxCacheSize {
            let keysToRemove = Array(layoutCache.keys).prefix(layoutCache.count - ListViewConstants.maxCacheSize)
            for key in keysToRemove {
                layoutCache.removeValue(forKey: key)
            }
        }
        
        return rows
    }
    
    /// 清除布局缓存
    func clearCache() {
        layoutCache.removeAll()
    }
}
