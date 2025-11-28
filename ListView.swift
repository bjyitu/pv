import SwiftUI
import UniformTypeIdentifiers

// 样式常量
struct ListViewConstants {
    /// 每行显示的图片数量，影响网格布局的列数
    static let imagesPerRow = 6
    
    /// 图片之间的间距（水平和垂直方向相同）
    static let spacing: CGFloat = 10
    
    /// 列表视图的水平内边距，用于左右两侧的留白
    static let horizontalPadding: CGFloat = 10
    
    /// 图片缩略图的圆角半径，影响视觉风格
    static let cornerRadius: CGFloat = 4
    
    /// 选中图片时的边框宽度，用于突出显示选中状态
    static let selectedBorderWidth: CGFloat = 2
    
    /// 缩略图缓存的最大数量，平衡内存使用和性能
    static let maxCacheSize = 5
    
    /// 宽高比采样的最大图片数量，避免计算过多图片影响性能
    static let maxAspectRatioSampleSize = 10
    
    /// 滚动重试延迟时间（秒），用于处理目标项未渲染的情况
    static let scrollRetryDelay: TimeInterval = 0.1
    
    /// 滚动状态清理延迟时间（秒），滚动完成后清理相关状态
    static let scrollCleanupDelay: TimeInterval = 0.5
    
    /// 窗口大小变化检测阈值（像素），避免微小变化触发重布局
    static let resizeDetectionThreshold: CGFloat = 5
    
    /// 窗口调整结束检测延迟时间（秒），用于判断窗口拉伸是否完成
    static let resizeEndDelay: TimeInterval = 0.3
    
    /// 选中图片时的缩放比例，提供视觉反馈
    static let selectedScale: CGFloat = 1.02
    
    /// 选中动画持续时间（秒），用于缩放和边框动画
    static let selectionAnimationDuration: TimeInterval = 0.05
    
    /// 占位符图标的缩放比例，相对于缩略图尺寸
    static let placeholderIconScale: CGFloat = 0.3
    
    /// 悬停效果的不透明度，用于鼠标悬停时的视觉反馈
    static let hoverOpacity: CGFloat = 0.5
    
    /// 占位符背景的不透明度，用于空状态显示
    static let placeholderBackgroundOpacity: CGFloat = 0.1
}

// 固定网格布局的行结构
struct FixedGridRow {
    let images: [ImageItem]
    let imageSize: CGSize
    let totalWidth: CGFloat
    
    var imageCount: Int { images.count }
}

/// ListView 的状态管理对象
class ListViewState: ObservableObject {
    @Published var availableWidth: CGFloat = 0
    @Published var hasReceivedGeometry: Bool = false
    @Published var isWindowResizing: Bool = false
    @Published var lastWindowSize: CGSize = .zero
    
    // 定时器和任务
    var windowResizeTask: DispatchWorkItem? = nil
    var resizeEndTimer: Timer? = nil
}

struct ListView: View {
    @ObservedObject var viewModel: ImageBrowserViewModel
    @StateObject private var viewState = ListViewState()
    
    // 布局计算器
    private let layoutCalculator = LayoutCalculator()
    
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
            ScrollView {
                ScrollViewReader { proxy in
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(viewModel.directoryGroups) { group in
                            directorySection(for: group, proxy: proxy)
                        }
                        
                        // 加载更多指示器
                        if viewModel.canLoadMore {
                            LoadMoreIndicator(
                                isLoading: viewModel.isLoadingMore,
                                onLoadMore: { viewModel.loadMoreImages() },
                                canLoad: !viewState.isWindowResizing && !viewModel.isSingleViewMode && !viewModel.isReturningFromSingleView
                            )
                            .id("load-more-indicator")
                        }
                    }

                    .onReceive(NotificationCenter.default.publisher(for: UnifiedWindowManager.Notification.scrollToImage)) { notification in
                        if let userInfo = notification.userInfo,
                           let index = userInfo["index"] as? Int {
                            UnifiedWindowManager.shared.scrollToImage(at: index, options: .delayed)
                        }
                    }
                    .onReceive(viewModel.$selectedImages) { selectedImages in
                        UnifiedWindowManager.shared.handleSelectionChange(selectedImages, images: viewModel.images)
                    }
                    .onReceive(UnifiedWindowManager.shared.$shouldScrollToIndex) { targetIndex in
                        if let index = targetIndex {
                            performPhasedScroll(to: index, proxy: proxy)
                        }
                    }
                    .onAppear {
                        viewModel.setScrollProxy(proxy)
                    }
                    .onDisappear {
                        viewModel.clearScrollProxy()
                    }
                    .drawingGroup()
                }
                .padding(.horizontal, ListViewConstants.horizontalPadding)
            }
            .onAppear {
                if !viewState.hasReceivedGeometry {
                    viewState.availableWidth = geometry.size.width
                    viewState.hasReceivedGeometry = true
                }
            }
            .onChange(of: geometry.size) { newSize in
                guard !viewModel.isSingleViewMode else { return }
                
                // 检测显著的窗口大小变化
                let widthChanged = abs(newSize.width - viewState.lastWindowSize.width) > ListViewConstants.resizeDetectionThreshold
                let heightChanged = abs(newSize.height - viewState.lastWindowSize.height) > ListViewConstants.resizeDetectionThreshold
                
                if widthChanged || heightChanged {
                    handleWindowResizeStart(newSize: newSize)
                }
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
                        ForEach(fixedGridRow.images, id: \ .id) { imageItem in
                            SmartImageThumbnailView(
                                imageItem: imageItem,
                                size: fixedGridRow.imageSize,
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
        
        let targetImage = viewModel.images[index]
        withAnimation {
            proxy.scrollTo(targetImage.id, anchor: .center)
        }
        
        // 清理滚动状态
        DispatchQueue.main.asyncAfter(deadline: .now() + ListViewConstants.scrollRetryDelay) {
            UnifiedWindowManager.shared.shouldScrollToIndex = nil
        }
    }
    
    
    private func handleImageClick(_ image: ImageItem) {
        guard let index = viewModel.images.firstIndex(where: { $0.id == image.id }) else { return }
        
        let withCommand = NSApp.currentEvent?.modifierFlags.contains(.command) == true
        let withShift = NSApp.currentEvent?.modifierFlags.contains(.shift) == true
        let isDoubleClick = NSApp.currentEvent?.clickCount == 2
        
        viewModel.toggleImageSelection(at: index, withShift: withShift, withCommand: withCommand)
        
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
        
        viewState.resizeEndTimer?.invalidate()
        viewState.resizeEndTimer = Timer.scheduledTimer(withTimeInterval: ListViewConstants.resizeEndDelay, repeats: false) { _ in
            viewState.isWindowResizing = false
            // 窗口调整结束，可以在此处添加额外的处理逻辑
        }
        
        viewState.lastWindowSize = newSize
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
                        if canLoad && !isLoading && !hasTriggeredLoadMore {
                            let screenHeight = NSScreen.main?.visibleFrame.height ?? 0

                            if minY >= -geometry.size.height && minY < screenHeight {
                                hasTriggeredLoadMore = true
                                onLoadMore()
                                // 加载完成后重置状态
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

#Preview {
    LoadMoreIndicator(
        isLoading: false,
        onLoadMore: {},
        canLoad: true
    )
}