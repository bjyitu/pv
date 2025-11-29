import SwiftUI

class LayoutCalculatorJus: LayoutCalculatorProtocol {
    
    // 布局约束常量
    private enum LayoutConstraints {
        static let minRowHeight: CGFloat = 80
        static let maxRowHeight: CGFloat = 300
        static let minRowHeightRange: CGFloat = 240
        static let maxRowHeightRange: CGFloat = 300
        static let maxImagePerRowNumberTryAgain: Int = 8
        static let maxImagePerRowNumberTryFirst: Int = 10
    }
    
    struct SmartRow {
        let images: [ImageItem]
        let targetHeight: CGFloat
        let actualSizes: [CGSize]
        let totalWidth: CGFloat
        
        var imageCount: Int { images.count }
    }
    

    
    
    func createSmartRows(from images: [ImageItem], availableWidth: CGFloat, thumbnailSize: CGFloat) -> [SmartRow] {
        var rows: [SmartRow] = []
        let spacing: CGFloat = 10
        
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
    
    private func findOptimalRow(images: [ImageItem], availableWidth: CGFloat, baseHeight: CGFloat, spacing: CGFloat) -> SmartRow {
        guard !images.isEmpty else { return SmartRow(images: [], targetHeight: baseHeight, actualSizes: [], totalWidth: 0) }
        
        var bestRow: SmartRow? = nil
        var bestFillRate: CGFloat = 0
        
        let heightRange = stride(from: max(LayoutConstraints.minRowHeightRange, baseHeight * 0.8), through: min(LayoutConstraints.maxRowHeightRange, baseHeight * 1.2), by: 5)

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
            return bestRow
        }
        
        let maxImagesPerRow = min(images.count, LayoutConstraints.maxImagePerRowNumberTryAgain)
        var bestFallbackRow: SmartRow? = nil
        var bestFallbackFillRate: CGFloat = 0
        
        for imageCount in stride(from: maxImagesPerRow, through: 1, by: -1) {
            let testImages = Array(images.prefix(imageCount))
            let testRow = createJustifiedRow(images: testImages, availableWidth: availableWidth, targetHeight: baseHeight, spacing: spacing)
            
            let fillRate = testRow.totalWidth / availableWidth
            
            if fillRate >= 0.75 && fillRate <= 1.0 {
                return testRow
            }
            
            if fillRate > bestFallbackFillRate {
                bestFallbackRow = testRow
                bestFallbackFillRate = fillRate
            }
        }
        
        if let bestFallbackRow = bestFallbackRow {
            return bestFallbackRow
        }
        
        return createJustifiedRow(images: [images[0]], availableWidth: availableWidth, targetHeight: baseHeight, spacing: spacing)
    }
    

    
    private func createJustifiedRow(images: [ImageItem], availableWidth: CGFloat, targetHeight: CGFloat, spacing: CGFloat) -> SmartRow {
        guard !images.isEmpty else {
            return SmartRow(images: [], targetHeight: targetHeight, actualSizes: [], totalWidth: 0)
        }
        
        let aspectRatios = images.map { $0.size.width / $0.size.height }
        let totalAspectRatio = aspectRatios.reduce(0, +)
        
        let availableWidthForImages = availableWidth - spacing * CGFloat(images.count - 1)
        let idealHeight = availableWidthForImages / totalAspectRatio
        
        let finalHeight = max(LayoutConstraints.minRowHeight, min(LayoutConstraints.maxRowHeight, idealHeight))
        
        let actualSizes = aspectRatios.map { aspectRatio in
            CGSize(width: finalHeight * aspectRatio, height: finalHeight)
        }
        
        let totalWidth = actualSizes.reduce(0) { $0 + $1.width } + spacing * CGFloat(images.count - 1)
        
        if totalWidth > availableWidth {
            let scale = availableWidth / totalWidth
            let scaledHeight = finalHeight * scale
            
            if scaledHeight >= LayoutConstraints.minRowHeight {
                let scaledSizes = actualSizes.map { size in
                    CGSize(width: size.width * scale, height: scaledHeight)
                }
                return SmartRow(
                    images: images,
                    targetHeight: scaledHeight,
                    actualSizes: scaledSizes,
                    totalWidth: availableWidth
                )
            }
        }
        
        return SmartRow(
            images: images,
            targetHeight: finalHeight,
            actualSizes: actualSizes,
            totalWidth: totalWidth
        )
    }
    
    // 将 SmartRow 转换为 FixedGridRow
    private func smartRowToFixedGridRow(_ smartRow: SmartRow) -> FixedGridRow {
        guard !smartRow.images.isEmpty else {
            return FixedGridRow(images: [], imageSizes: [], totalWidth: 0)
        }
        
        return FixedGridRow(
            images: smartRow.images,
            imageSizes: smartRow.actualSizes, // 传递每张图片的实际尺寸
            totalWidth: smartRow.totalWidth
        )
    }
    
    // 兼容 ListView 的接口方法
    func getFixedGridRows(for group: DirectoryGroup, availableWidth: CGFloat, hasReceivedGeometry: Bool) -> [FixedGridRow] {
        guard hasReceivedGeometry else { return [] }
        
        let effectiveWidth = calculateEffectiveWidth(availableWidth: availableWidth)
        let smartRows = createSmartRows(from: group.images, availableWidth: effectiveWidth, thumbnailSize: 200)
        
        return smartRows.map { smartRowToFixedGridRow($0) }
    }
    
    // 计算有效宽度（扣除左右边距）
    func calculateEffectiveWidth(availableWidth: CGFloat) -> CGFloat {
        return availableWidth - (ListViewConstants.horizontalPadding * 2)
    }
    
    // 清除缓存（兼容接口）
    func clearCache() {
        // 智能布局算法不需要缓存，保持接口兼容
    }
}