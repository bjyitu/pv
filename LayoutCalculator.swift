import SwiftUI

/// 布局计算器 - 封装所有与布局相关的计算逻辑
class LayoutCalculator: LayoutCalculatorProtocol {
    
    /// 创建固定网格行
    func createFixedGridRows(from images: [ImageItem], availableWidth: CGFloat) -> [FixedGridRow] {
        var rows: [FixedGridRow] = []
        let targetImagesPerRow = AppConstants.ListView.imagesPerRow
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
        return availableWidth - (AppConstants.ListView.horizontalPadding * 2)
    }
    
    /// 计算图片尺寸
    func calculateImageSize(for imagesCount: Int, availableWidth: CGFloat, from images: [ImageItem]) -> CGSize {
        let effectiveWidth = calculateEffectiveWidth(availableWidth: availableWidth)
        
        // 始终按照每行6张图片的标准来计算尺寸，确保布局一致性
        let standardImagesPerRow = AppConstants.ListView.imagesPerRow
        let totalSpacing = CGFloat(standardImagesPerRow - 1) * AppConstants.ListView.spacing
        let availableImageWidth = (effectiveWidth - totalSpacing) / CGFloat(standardImagesPerRow)
        
        // 采样前六张图片计算平均宽高比
        let sampleSize = min(images.count, standardImagesPerRow) // 最多采样前七张
        var totalAspectRatio: CGFloat = 0.0
        
        for i in 0..<sampleSize {
            let image = images[i]
            totalAspectRatio += (image.size.width / image.size.height)
        }
        
        let averageAspectRatio = sampleSize > 0 ? totalAspectRatio / CGFloat(sampleSize) : 1.0
        
        // 使用平均宽高比确定图片尺寸
        return CGSize(width: availableImageWidth, height: availableImageWidth / averageAspectRatio)
    }
    
    /// 获取固定网格行
    func getFixedGridRows(for group: DirectoryGroup, availableWidth: CGFloat, hasReceivedGeometry: Bool) -> [FixedGridRow] {
        guard hasReceivedGeometry else { return [] }
        
        // 直接创建固定布局结构
        return createFixedGridRows(from: group.images, availableWidth: availableWidth)
    }
    

}