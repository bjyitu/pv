import SwiftUI
import UniformTypeIdentifiers

// 固定网格布局的行结构
struct FixedGridRow {
    let images: [ImageItem]
    let imageSizes: [CGSize] // 改为数组，存储每张图片的个性化尺寸
    let totalWidth: CGFloat
    
    var imageCount: Int { images.count }
    
    // 兼容性属性，返回第一张图片的尺寸（用于向后兼容）
    var imageSize: CGSize {
        return imageSizes.first ?? .zero
    }
}

/// ListView 的状态管理对象
class ListViewState: ObservableObject {
    @Published var availableWidth: CGFloat = 0
    @Published var hasReceivedGeometry: Bool = false
    @Published var isWindowResizing: Bool = false
    @Published var lastWindowSize: CGSize = .zero
    
    // 预加载和区域定位相关状态
    @Published var currentScrollOffset: CGFloat = 0
    @Published var viewportHeight: CGFloat = 0
    @Published var preloadedRegions: Set<String> = []
    // @Published var isPositioningInProgress: Bool = false
    
    // 滚动位置跟踪
    
    // 定时器和任务, 用于处理窗口大小变化
    var windowResizeTask: DispatchWorkItem? = nil
    var scrollTask: DispatchWorkItem? = nil
}

struct ListView: View {
    @StateObject var viewModel: ImageBrowserViewModel
    
    // 修改：使用ViewModel统一管理的状态，避免视图重建时状态丢失
    @StateObject var viewState: ListViewState
    
    // 布局计算器 - 根据布局状态选择不同的计算器
    private var layoutCalculator: LayoutCalculatorProtocol {
        if viewModel.isSmartLayoutEnabled {
            return LayoutCalculatorJus()
        } else {
            return LayoutCalculator()
        }
    }
    
    // 注：布局计算逻辑已移至 LayoutCalculator 类
    
    private func getFixedGridRows(for group: DirectoryGroup) -> [FixedGridRow] {
        return layoutCalculator.getFixedGridRows(
            for: group,
            availableWidth: viewState.availableWidth,
            hasReceivedGeometry: viewState.hasReceivedGeometry
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.directoryGroups) { group in
                            directorySection(for: group, proxy: proxy)
                        }
                        
                        // 加载更多指示器
                        if viewModel.canLoadMore {
                            LoadMoreIndicator(
                                isLoading: viewModel.isLoadingMore,
                                onLoadMore: { viewModel.dataManager.loadMoreImages() },
                                canLoad: !viewState.isWindowResizing && !viewModel.isSingleViewMode && !viewModel.isReturningFromSingleView
                            )
                            .id("load-more-indicator")
                        }
                    }
                    .drawingGroup()
                    .background(
                        GeometryReader { scrollGeometry in
                            Color.clear
                                .onChange(of: scrollGeometry.frame(in: .global).minY) { minY in
                                    handleScrollPositionChange(minY: minY, viewportHeight: geometry.size.height)
                                }
                        }
                    )
                }
                .padding(.horizontal, AppConstants.ListView.horizontalPadding)
                .onReceive(NotificationCenter.default.publisher(for: AppConstants.Notifications.preloadImageRegion)) { notification in
                    if let userInfo = notification.userInfo,
                       let index = userInfo["index"] as? Int {
                        // 在单页视图里切换图片时，预加载当前图片所在的区域
                        preloadTargetRegion(for: index)
                        // 检查目标是否在当前可见范围内，如果不在则滚动到目标位置
                        checkAndScrollToTargetIfNeeded(index: index, proxy: proxy)
                    }
                }
                .onReceive(viewModel.$selectedImages) { selectedImages in
                    //在列表内选择图片时，更新 UnifiedWindowManager 的选中状态
                    UnifiedWindowManager.shared.handleSelectionChange(selectedImages, images: viewModel.images)
                }
                .onReceive(UnifiedWindowManager.shared.$shouldScrollToIndex) { targetIndex in
                    if let index = targetIndex {
                        print("ListView: 收到滚动请求到索引 \(index), isReturningFromSingleView=\(viewModel.isReturningFromSingleView)")
                        //从单页返回时调用的滚动
                        performPhasedScroll(to: index, proxy: proxy)
                    }
                }
                .onAppear {                    
                    if !viewState.hasReceivedGeometry {
                        viewState.availableWidth = geometry.size.width
                        viewState.viewportHeight = geometry.size.height
                        viewState.hasReceivedGeometry = true
                    }
                }
            }
            
            .onChange(of: geometry.size) { newSize in
                guard !viewModel.isSingleViewMode else { return }
                
                // 检测显著的窗口大小变化
                let widthChanged = abs(newSize.width - viewState.lastWindowSize.width) > AppConstants.Window.resizeDetectionThreshold
                let heightChanged = abs(newSize.height - viewState.lastWindowSize.height) > AppConstants.Window.resizeDetectionThreshold
                
                if widthChanged || heightChanged {
                    handleWindowResizeStart(newSize: newSize)
                }
                
                // 更新视口高度
                viewState.viewportHeight = newSize.height
            }
            .onDisappear {
                viewState.windowResizeTask?.cancel()
                viewState.windowResizeTask = nil
            }
        }
        .onAppear {
            if !viewModel.images.isEmpty && viewModel.selectedImages.isEmpty {
                viewModel.toggleImageSelection(at: 0)
            }
        }
        .background(
            UnifiedKeyboardListener(viewModel: viewModel, mode: .list)
        )
        .overlay(
            // 布局切换按钮 - 放在左下角
            VStack {
                Spacer()
                HStack {
                    layoutToggleButton
                        .padding(.leading, 20)
                        .padding(.bottom, 20)
                    Spacer()
                }
            }
        )
        
    }

    private func directorySection(for group: DirectoryGroup, proxy: ScrollViewProxy) -> some View {
        let fixedGridRows = getFixedGridRows(for: group)
        
        return Group {
            if !viewState.hasReceivedGeometry {
                HStack {
                    Spacer()
                }
            } else {
                ForEach(0..<fixedGridRows.count, id: \ .self) { rowIndex in
                    let fixedGridRow = fixedGridRows[rowIndex]
                    
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(Array(fixedGridRow.images.enumerated()), id: \.element.id) { index, imageItem in
                            EquatableView(content: LayoutThumbView(
                                imageItem: imageItem,
                                size: fixedGridRow.imageSizes[index], // 使用每张图片对应的个性化尺寸
                                isSelected: viewModel.selectedImages.contains(imageItem.id),
                                onTap: {
                                    handleImageClick(imageItem)
                                },
                                onRightClick: {
                                },
                                onDoubleClick: {
                                    if let index = viewModel.images.firstIndex(where: { $0.id == imageItem.id }) {
                                        viewModel.selectImage(at: index)
                                        viewModel.isSingleViewMode = true
                                    }
                                },
                                viewModel: viewModel
                            ))
                            .id(imageItem.id)
                        }
                        
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id("row-\(rowIndex)-\(group.id)")
                }
            }
        }
        .id("\(group.id)") // 只使用组ID作为标识，不再响应缩略图尺寸变化
    }
    
    private func performPhasedScroll(to index: Int, proxy: ScrollViewProxy) {
        guard index >= 0 && index < viewModel.images.count else { return }
        
        // 取消之前的滚动任务
        viewState.scrollTask?.cancel()
        
        // 先预加载目标区域
        preloadTargetRegion(for: index)
        
        // 🚀 立即执行滚动定位，依靠状态保护而非延时猜测
        let targetImage = viewModel.images[index]

        // 执行目标定位到区域中间（统一使用0.5, 0.5定位）
        proxy.scrollTo(targetImage.id, anchor: UnitPoint(x: 0.5, y: 0.5))
    }
    
    // 处理滚动位置变化，检测需要预加载的区域
    private func handleScrollPositionChange(minY: CGFloat, viewportHeight: CGFloat) {
        // 🔒 基础保护：在几何信息未稳定或窗口大小变化期间忽略几何变化
        guard viewState.hasReceivedGeometry && 
              !viewState.isWindowResizing else { 
            print("handleScrollPositionChange: 几何信息未稳定，忽略变化 (hasGeometry: \(viewState.hasReceivedGeometry), isResizing: \(viewState.isWindowResizing))")
            return 
        }
        
        // 🎯 关键修复：在从单页返回状态变化期间，忽略几何变化
        // 这是防止minY异常变化的根本原因
        if viewModel.isReturningFromSingleView {
            print("handleScrollPositionChange: 从单页返回期间，忽略几何变化，保持位置: \(viewState.currentScrollOffset)")
            return
        }
        
        // 计算滚动偏移量
        
        if abs(minY) < 100 {
            print("handleScrollPositionChange: abs.miny < 100: \(minY)")
            return
        }else{
            let finalScrollOffset = max(0, -minY)
            // 更新滚动位置
            viewState.currentScrollOffset = finalScrollOffset
            UnifiedWindowManager.shared.updateListScrollOffset(finalScrollOffset)
        } 
        
        // 检测当前视口区域
        let visibleRegionStart = viewState.currentScrollOffset
        let visibleRegionEnd = visibleRegionStart + viewportHeight
        
        // 预加载当前视口附近的区域
        preloadRegionsAroundVisibleArea(visibleRegionStart: visibleRegionStart, 
                                       visibleRegionEnd: visibleRegionEnd, 
                                       viewportHeight: viewportHeight)
    }
    
    // 预加载目标区域
    private func preloadTargetRegion(for targetIndex: Int) {
        guard targetIndex >= 0 && targetIndex < viewModel.images.count else { return }
        
        // 检查是否是从单页返回的情况
        let isReturningFromSingleView = viewModel.isReturningFromSingleView
        
        // 根据目标位置智能调整预加载区域大小
        let regionSize = calculateOptimalRegionSize(for: targetIndex)
        let regionStart = max(0, targetIndex - regionSize)
        let regionEnd = min(viewModel.images.count - 1, targetIndex + regionSize)
        
        // 标记该区域为预加载
        let regionKey = "region_\(regionStart)_\(regionEnd)"
        viewState.preloadedRegions.insert(regionKey)
        
        // 触发数据加载（如果需要）
        checkAndLoadMoreData(for: regionEnd)
        
        // 如果是从单页返回，增加额外的预加载区域
        if isReturningFromSingleView {
            // 预加载目标区域周围的额外区域，确保内容完全加载
            let extendedRegionSize = regionSize 
            let extendedRegionStart = max(0, targetIndex - extendedRegionSize)
            let extendedRegionEnd = min(viewModel.images.count - 1, targetIndex + extendedRegionSize)
            
            let extendedRegionKey = "region_\(extendedRegionStart)_\(extendedRegionEnd)"
            viewState.preloadedRegions.insert(extendedRegionKey)
            
            // 检测扩展区域是否需要加载更多数据
            checkAndLoadMoreData(for: extendedRegionEnd)
            
            print("预加载目标区域: \(regionStart) - \(regionEnd), 扩展区域: \(extendedRegionStart) - \(extendedRegionEnd), 目标索引: \(targetIndex), 从单页返回: \(isReturningFromSingleView)")
        } else {
            print("预加载目标区域: \(regionStart) - \(regionEnd), 目标索引: \(targetIndex)")
        }
    }
    
    // 计算最优的预加载区域大小
    private func calculateOptimalRegionSize(for targetIndex: Int) -> Int {
        guard viewModel.images.count > 0 else { return 10 }
        
        let totalItems = viewModel.images.count
        let relativePosition = CGFloat(targetIndex) / CGFloat(totalItems)
        
        // 根据目标位置调整区域大小
        if relativePosition < 0.1 || relativePosition > 0.9 {
            // 靠近边界时使用较小的区域
            return 8
        } else if relativePosition < 0.2 || relativePosition > 0.8 {
            // 靠近边界但不在最边缘时使用中等区域
            return 12
        } else {
            // 中间区域使用较大的预加载区域
            return 15
        }
    }
    
    // 预加载当前视口周围的区域
    private func preloadRegionsAroundVisibleArea(visibleRegionStart: CGFloat, 
                                               visibleRegionEnd: CGFloat, 
                                               viewportHeight: CGFloat) {
        // 计算预加载区域的阈值
        let preloadThreshold = viewportHeight * AppConstants.Scroll.preloadThresholdMultiplier
        let preloadEnd = visibleRegionEnd + preloadThreshold
        
        // 使用动态计算的行高来估算索引位置
        let averageRowHeight = calculateAverageRowHeight()
        let estimatedIndex = Int(preloadEnd / averageRowHeight)
        
        // 检测是否需要预加载更多数据
        checkAndLoadMoreData(for: estimatedIndex)
        
        // 如果需要滚动方向优化，可以在此处添加实际逻辑
    }
    
    // 检查并加载更多数据
    private func checkAndLoadMoreData(for regionEnd: Int) {
        if regionEnd >= viewModel.images.count - 5 && viewModel.canLoadMore && !viewModel.isLoadingMore {
            // 如果预加载区域接近数据末尾，触发加载更多
            viewModel.dataManager.loadMoreImages()
        }
    }
    
    // 移除滚动位置检测定时器相关代码
    // 预加载由以下时机触发：
    // 1. 滚动位置变化 (handleScrollPositionChange)
    // 2. 单页视图切换图片 (preloadTargetRegion)
    // 3. 从单页返回列表 (performPhasedScroll)
    // 4. 窗口大小变化 (handleWindowResizeStart)
    
    // 这些触发时机已经足够覆盖所有预加载需求，无需额外的定时器
    
    
    private func handleImageClick(_ image: ImageItem) {
        guard let index = viewModel.images.firstIndex(where: { $0.id == image.id }) else { return }
        
        let withCommand = NSApp.currentEvent?.modifierFlags.contains(.command) == true
        let withShift = NSApp.currentEvent?.modifierFlags.contains(.shift) == true
        let isDoubleClick = NSApp.currentEvent?.clickCount == 2
        
        // 检查是否已经选中了该图片
        let isAlreadySelected = viewModel.selectedImages.contains(image.id)
        
        // 只有在以下情况下才触发选中状态变化：
        // 1. 使用Command键进行多选
        // 2. 使用Shift键进行范围选择
        // 3. 当前图片未被选中
        // 4. 双击进入单页视图
        if withCommand || withShift || !isAlreadySelected {
            viewModel.toggleImageSelection(at: index, withShift: withShift, withCommand: withCommand)
        }        
        if isDoubleClick {
            viewModel.selectImage(at: index)
            viewModel.isSingleViewMode = true
        }
    }
    
    // 统一的窗口大小变化处理方法，避免重复的状态管理逻辑
    private func handleWindowResizeStart(newSize: CGSize) {
        viewState.isWindowResizing = true
        viewState.availableWidth = newSize.width
        viewState.hasReceivedGeometry = true
        
        // 使用 windowResizeTask 替代 Timer
        viewState.windowResizeTask?.cancel()
        
        let workItem = DispatchWorkItem { [weak viewState] in
            viewState?.isWindowResizing = false
        }
        viewState.windowResizeTask = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + AppConstants.ListView.resizeEndDelay, execute: workItem)
        viewState.lastWindowSize = newSize
    }
    
    // 布局切换按钮
    private var layoutToggleButton: some View {
        LayoutToggleButton(
            isSmartLayout: viewModel.isSmartLayoutEnabled,
            action: {
                viewModel.toggleLayout()
            }
        )
    }
}

#Preview {
    ListView(viewModel: ImageBrowserViewModel(), viewState: ListViewState())
}

// MARK: - LoadMoreIndicator
// 加载更多指示器组件，用于在滚动到底部时触发数据加载
struct LoadMoreIndicator: View {
    let isLoading: Bool
    let onLoadMore: () -> Void
    let canLoad: Bool
    
    // 防止重复触发的状态
    @State private var hasTriggeredLoadMore = false
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Button(action: {
                    onLoadMore()
                }) {
                    Image(systemName: "arrow.down.circle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onChange(of: geometry.frame(in: .global).minY) { minY in
                        // 🔒 添加保护：避免在视图转换期间处理几何变化
                        if canLoad && !isLoading && !hasTriggeredLoadMore {
                            let screenHeight = NSScreen.main?.visibleFrame.height ?? 0

                            if minY >= -geometry.size.height && minY < screenHeight {
                                print("LoadMoreIndicator: 触发加载更多，minY = \(minY)")
                                hasTriggeredLoadMore = true
                                onLoadMore()
                                // 加载完成后重置状态,防止重复加载
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    hasTriggeredLoadMore = false
                                }
                            }
                        }
                    }
            }
        )
    }
}

// MARK: - 目标位置检查与滚动
private extension ListView {
    // 检查目标是否在当前可见范围内，如果不在则滚动到目标位置
    func checkAndScrollToTargetIfNeeded(index: Int, proxy: ScrollViewProxy) {
        guard index >= 0 && index < viewModel.images.count else { return }
        
        // 获取当前可见区域的信息
        let visibleRange = getCurrentVisibleRange()
        let targetInVisibleRange = index >= visibleRange.lowerBound && index <= visibleRange.upperBound
        
        if !targetInVisibleRange {
            // 目标不在可见范围内，执行滚动定位
            print("ListView: 目标索引 \(index) 不在可见范围内，执行滚动定位")
            performPhasedScroll(to: index, proxy: proxy)
        } else {
            print("ListView: 目标索引 \(index) 已在可见范围内，无需滚动")
        }
    }
    
    // 获取当前可见范围内的图片索引范围
    private func getCurrentVisibleRange() -> ClosedRange<Int> {
        guard viewState.viewportHeight > 0 else { return 0...0 }
        
        // 估算当前可见区域的起始和结束索引
        let scrollOffset = viewState.currentScrollOffset
        
        // 修复滚动位置计算：scrollOffset 应该是正值，表示向下滚动的距离
        let visibleStartY = max(0, scrollOffset) // 确保不会出现负值
        let visibleEndY = visibleStartY + viewState.viewportHeight
        
        // 动态计算平均行高，替代固定估算值
        let averageRowHeight = calculateAverageRowHeight()
        print("ListView: 计算得到的平均行高为 \(averageRowHeight)")
        
        let startIndex = max(0, Int(visibleStartY / averageRowHeight))
        let endIndex = min(viewModel.images.count - 1, Int(visibleEndY / averageRowHeight))
        
        return startIndex...endIndex
    }
    
    // 动态计算平均行高
    private func calculateAverageRowHeight() -> CGFloat {
        guard !viewModel.directoryGroups.isEmpty else { return 150.0 } // 默认值
        
        // 获取当前布局计算器
        let currentCalculator = layoutCalculator
        
        // 采样前几个目录组来计算平均行高
        var totalRowHeight: CGFloat = 0
        var rowCount = 0
        
        for group in viewModel.directoryGroups.prefix(3) { // 采样前3个组
            let rows = currentCalculator.getFixedGridRows(
                for: group,
                availableWidth: viewState.availableWidth,
                hasReceivedGeometry: viewState.hasReceivedGeometry
            )
            
            for row in rows.prefix(5) { // 每个组采样前5行
                if !row.imageSizes.isEmpty {
                    // 使用第一张图片的高度作为行高估算
                    totalRowHeight += row.imageSizes[0].height
                    rowCount += 1
                }
            }
        }
        
        // 如果有实际数据，使用平均值；否则使用默认值
        return rowCount > 0 ? totalRowHeight / CGFloat(rowCount) : 150.0
    }
}

#Preview {
    LoadMoreIndicator(
        isLoading: false,
        onLoadMore: {},
        canLoad: true
    )
}