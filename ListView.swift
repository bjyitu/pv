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

struct ListView: View {
    @ObservedObject var viewModel: ImageBrowserViewModel
    
    // 布局计算器 - 使用存储属性避免重复创建实例
    private let layoutCalculatorJus = LayoutCalculatorOpt()
    private let layoutCalculatorStandard = LayoutCalculator()
    
    init(viewModel: ImageBrowserViewModel) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        // print("ListView initialized with layout calculators - Smart Layout: \(viewModel.isSmartLayoutEnabled ? "Enabled" : "Disabled")")
    }
    
    private var layoutCalculator: LayoutCalculatorProtocol {
        return viewModel.isSmartLayoutEnabled ? layoutCalculatorJus : layoutCalculatorStandard
    }
        
    private func getFixedGridRows(for group: DirectoryGroup) -> [FixedGridRow] {
        let rows = layoutCalculator.getFixedGridRows(
            for: group,
            availableWidth: viewModel.listViewState.availableWidth,
            hasReceivedGeometry: viewModel.listViewState.hasReceivedGeometry
        )
        
        return rows
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
                                canLoad: { !viewModel.listViewState.isWindowResizing && !viewModel.isSingleViewMode && !viewModel.isReturningFromSingleView }
                            )
                            .id("load-more-indicator")
                        }
                    }
                    .drawingGroup()
                    .background(
                        GeometryReader { scrollGeometry in
                            Color.clear
                                .onChange(of: scrollGeometry.frame(in: .global).minY) { minY in
                                    //滚动时触发
                                    // handleScrollPositionChange(minY: minY, viewportHeight: geometry.size.height)
                                    UnifiedWindowManager.shared.updateListScrollOffset(max(0, -minY))
                                }
                        }
                    )
                }
                .padding(.horizontal, AppConstants.ListView.horizontalPadding)
                .onReceive(NotificationCenter.default.publisher(for: AppConstants.Notifications.preloadImageRegion)) { notification in
                    if let userInfo = notification.userInfo,
                       let index = userInfo["index"] as? Int {
                        // 在单页视图里切换图片时，预加载当前图片所在的区域
                        viewModel.preloadTargetRegion(for: index)
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
                        // 检查目标是否在当前可见范围内，如果不在则滚动到目标位置
                        checkAndScrollToTargetIfNeeded(index: index, proxy: proxy)
                    }
                }
                .onAppear {                    
                    if !viewModel.listViewState.hasReceivedGeometry {
                        viewModel.listViewState.availableWidth = geometry.size.width
                        viewModel.listViewState.viewportHeight = geometry.size.height
                        viewModel.listViewState.hasReceivedGeometry = true
                    }
                }
            }
            
            .onChange(of: geometry.size) { newSize in
                guard !viewModel.isSingleViewMode else { return }
                
                // 检测显著的窗口大小变化
                let widthChanged = abs(newSize.width - viewModel.listViewState.lastWindowSize.width) > AppConstants.Window.resizeDetectionThreshold
                let heightChanged = abs(newSize.height - viewModel.listViewState.lastWindowSize.height) > AppConstants.Window.resizeDetectionThreshold
                
                if widthChanged || heightChanged {
                    viewModel.handleWindowResizeStart(newSize: newSize)
                }
                
                // 更新视口高度
                viewModel.listViewState.viewportHeight = newSize.height
            }
            .onDisappear {
                viewModel.listViewState.windowResizeTask?.cancel()
                viewModel.listViewState.windowResizeTask = nil
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
            if !viewModel.listViewState.hasReceivedGeometry {
                HStack {
                    Spacer()
                }
            } else {
                let rows = fixedGridRows.enumerated().map { (index, row) in (index, row) }
                ForEach(rows, id: \.0) { rowIndex, fixedGridRow in
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(Array(fixedGridRow.images.enumerated()), id: \.element.id) { index, imageItem in
                            LayoutThumbView(
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
                            )
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
        viewModel.listViewState.scrollTask?.cancel()       
        // 先预加载目标区域
        viewModel.preloadTargetRegion(for: index)

        let targetImage = viewModel.images[index]
        // 执行目标定位到区域中间（统一使用0.5, 0.5定位）
        proxy.scrollTo(targetImage.id, anchor: UnitPoint(x: 0.5, y: 0.5))
    }
    
    // 处理滚动位置变化，检测需要预加载的区域
    private func handleScrollPositionChange(minY: CGFloat, viewportHeight: CGFloat) {
        // 在几何信息未稳定或窗口大小变化期间忽略几何变化
        guard viewModel.listViewState.hasReceivedGeometry && 
              !viewModel.listViewState.isWindowResizing else { 
            print("handleScrollPositionChange: 几何信息未稳定，忽略变化 (hasGeometry: \(viewModel.listViewState.hasReceivedGeometry), isResizing: \(viewModel.listViewState.isWindowResizing))")
            return 
        }
        
        // 在从单页返回状态变化期间，忽略几何变化
        if viewModel.isReturningFromSingleView {
            print("handleScrollPositionChange: 从单页返回期间，忽略几何变化，保持位置: \(viewModel.listViewState.currentScrollOffset)")
            return
        }

        let finalScrollOffset = max(0, -minY)
        // 更新滚动位置
        viewModel.listViewState.currentScrollOffset = finalScrollOffset
        UnifiedWindowManager.shared.updateListScrollOffset(finalScrollOffset)
        // print("列表视图模式， (滚动位置: \(finalScrollOffset))")
        // 预加载只在单页浏览模式下需要，用于提前加载目标区域

    }
    
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
    
    // 统一的窗口大小变化处理方法（已移动到ViewModel中）
    
    // 布局切换按钮
    private var layoutToggleButton: some View {
        LayoutToggleButton(
            isSmartLayout: viewModel.isSmartLayoutEnabled,
            action: {
                print("Layout Toggle: Switching from \(viewModel.isSmartLayoutEnabled ? "Smart" : "Standard") to \(!viewModel.isSmartLayoutEnabled ? "Smart" : "Standard") layout")
                viewModel.toggleLayout()
                print("Layout Toggle: Switched to \(!viewModel.isSmartLayoutEnabled ? "Smart" : "Standard") layout")
                
                // 布局切换时清除平均行高缓存
                viewModel.listViewState.cachedAverageRowHeight = nil
                print("Layout Toggle: 清除平均行高缓存")
            }
        )
    }
}

#Preview {
    ListView(viewModel: ImageBrowserViewModel())
}

// MARK: - LoadMoreIndicator
// 加载更多指示器组件，用于在滚动到底部时触发数据加载
struct LoadMoreIndicator: View {
    let isLoading: Bool
    let onLoadMore: () -> Void
    let canLoad: () -> Bool
    
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
                        // 避免在视图转换期间处理几何变化
                        if canLoad() && !isLoading && !hasTriggeredLoadMore {
                            let screenHeight = NSScreen.main?.visibleFrame.height ?? 0
                            // 改进触发条件：当 LoadMoreIndicator 进入屏幕可见区域时触发
                            if minY >= -geometry.size.height && minY < screenHeight + geometry.size.height {
                                print("LoadMoreIndicator: 触发加载更多，minY = \(minY), screenHeight = \(screenHeight)")
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
    
    // 获取当前可见范围内的图片索引范围（已移动到ViewModel中）
    private func getCurrentVisibleRange() -> ClosedRange<Int> {
        return viewModel.getCurrentVisibleRange(layoutCalculator: layoutCalculator)
    }
    

}

#Preview {
    LoadMoreIndicator(
        isLoading: false,
        onLoadMore: {},
        canLoad: { true }
    )
}