import SwiftUI

/// 布局计算器协议 - 统一两种布局计算器的接口
protocol LayoutCalculatorProtocol {
    func getFixedGridRows(for group: DirectoryGroup, availableWidth: CGFloat, hasReceivedGeometry: Bool) -> [FixedGridRow]
    func calculateEffectiveWidth(availableWidth: CGFloat) -> CGFloat
    func clearCache()
}