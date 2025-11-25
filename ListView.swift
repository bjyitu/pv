import SwiftUI

// 样式常量
struct ListViewConstants {
    /// 每行显示的图片数量，影响网格布局的列数
    static let imagesPerRow = 6
    
    /// 图片之间的间距（水平和垂直方向相同）
    static let spacing: CGFloat = 10
    
    /// 列表视图的水平内边距，用于左右两侧的留白
    static let horizontalPadding: CGFloat = 6
    
    /// 图片缩略图的圆角半径，影响视觉风格
    static let cornerRadius: CGFloat = 4
    
    /// 选中图片时的边框宽度，用于突出显示选中状态
    static let selectedBorderWidth: CGFloat = 2
    
    /// 缩略图缓存的最大数量，平衡内存使用和性能
    static let maxCacheSize = 5
    
    /// 计算平均宽高比时采样的最大图片数量，避免性能问题
    static let maxAspectRatioSampleSize = 100
    
    /// 滚动重试延迟时间（秒），用于处理目标项未渲染的情况
    static let scrollRetryDelay: TimeInterval = 0.1
    
    /// 滚动状态清理延迟时间（秒），滚动完成后清理相关状态
    static let scrollCleanupDelay: TimeInterval = 0.5
    
    /// 窗口大小变化检测阈值（像素），避免微小变化触发重布局
    static let resizeDetectionThreshold: CGFloat = 10
    
    /// 窗口调整结束检测延迟时间（秒），用于判断窗口拉伸是否完成
    static let resizeEndDelay: TimeInterval = 0.3
    
    /// 选中图片时的缩放比例，提供视觉反馈
    static let selectedScale: CGFloat = 1.02
    
    /// 选中动画持续时间（秒），用于缩放和边框动画
    static let selectionAnimationDuration: TimeInterval = 0.15
    
    /// 占位符图标的缩放比例，相对于缩略图尺寸
    static let placeholderIconScale: CGFloat = 0.3
    
    /// 悬停效果的不透明度，用于鼠标悬停时的视觉反馈
    static let hoverOpacity: CGFloat = 0.05
    
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

struct ListView: View {
    @ObservedObject var viewModel: ImageBrowserViewModel
    @State private var availableWidth: CGFloat = 0
    @State private var hasReceivedGeometry = false
    @State private var windowResizeTask: DispatchWorkItem? = nil
    @State private var isWindowResizing = false
    @State private var lastWindowSize: CGSize = .zero
    @State private var resizeEndTimer: Timer? = nil
    
    // 布局缓存优化
    @State private var layoutCache: [String: [FixedGridRow]] = [:]
    @State private var lastLayoutWidth: CGFloat = 0
    @State private var lastImageCount: Int = 0
    
    private func createFixedGridRows(from images: [ImageItem], availableWidth: CGFloat) -> [FixedGridRow] {
        guard !images.isEmpty else { return [] }
        
        // 使用常量配置布局
        let imagesPerRow = ListViewConstants.imagesPerRow
        let spacing = ListViewConstants.spacing
        let horizontalPadding = ListViewConstants.horizontalPadding
        
        // 计算可用宽度（减去水平内边距）
        let effectiveWidth = availableWidth - horizontalPadding * 2
        
        // 计算每个图片的宽度（考虑间距）
        let totalSpacing = spacing * CGFloat(imagesPerRow - 1)
        let imageWidth = (effectiveWidth - totalSpacing) / CGFloat(imagesPerRow)
        
        // 计算图片高度（保持宽高比，使用平均宽高比）
        let avgAspectRatio = calculateAverageAspectRatio(images: images)
        let imageHeight = imageWidth / avgAspectRatio
        
        let imageSize = CGSize(width: imageWidth, height: imageHeight)
        
        var rows: [FixedGridRow] = []
        var currentRowImages: [ImageItem] = []
        
        for image in images {
            currentRowImages.append(image)
            
            // 当达到每行图片数量或处理到最后一张图片时
            if currentRowImages.count == imagesPerRow {
                let row = FixedGridRow(
                    images: currentRowImages,
                    imageSize: imageSize,
                    totalWidth: effectiveWidth
                )
                rows.append(row)
                currentRowImages = []
            }
        }
        
        // 处理最后一行（可能不足6个图片）
        if !currentRowImages.isEmpty {
            // 对于最后一行，重新计算宽度以保持等宽
            let lastRowImageCount = currentRowImages.count
            let lastRowTotalSpacing = spacing * CGFloat(lastRowImageCount - 1)
            let lastRowImageWidth = (effectiveWidth - lastRowTotalSpacing) / CGFloat(lastRowImageCount)
            let lastRowImageHeight = lastRowImageWidth / avgAspectRatio
            
            let lastRowImageSize = CGSize(width: lastRowImageWidth, height: lastRowImageHeight)
            
            let row = FixedGridRow(
                images: currentRowImages,
                imageSize: lastRowImageSize,
                totalWidth: effectiveWidth
            )
            rows.append(row)
        }
        
        print("=== ListView 固定网格布局 ===")
        print("总行数: \(rows.count)")
        print("可用宽度: \(availableWidth)")
        print("有效宽度: \(effectiveWidth)")
        print("图片尺寸: \(imageSize)")
        print("每行图片数: \(imagesPerRow)")
        
        return rows
    }
    
    /// 计算图片的平均宽高比（优化版本）
    private func calculateAverageAspectRatio(images: [ImageItem]) -> CGFloat {
        guard !images.isEmpty else { return 1.0 } // 默认宽高比
        
        // 优化：对于大量图片，使用采样计算而不是全部计算
        let maxSampleSize = ListViewConstants.maxAspectRatioSampleSize
        
        if images.count <= maxSampleSize {
            // 图片数量较少，直接计算
            let totalAspectRatio = images.reduce(0.0) { result, image in
                return result + (image.size.width / image.size.height)
            }
            return totalAspectRatio / CGFloat(images.count)
        } else {
            // 图片数量较多，使用采样计算
            let step = images.count / maxSampleSize
            var totalAspectRatio: CGFloat = 0.0
            var sampleCount = 0
            
            for i in stride(from: 0, to: images.count, by: step) {
                let image = images[i]
                totalAspectRatio += (image.size.width / image.size.height)
                sampleCount += 1
                
                if sampleCount >= maxSampleSize {
                    break
                }
            }
            
            return totalAspectRatio / CGFloat(sampleCount)
        }
    }
    
    private func getFixedGridRows(for group: DirectoryGroup) -> [FixedGridRow] {
        guard hasReceivedGeometry else { return [] }
        
        // 布局缓存优化：只有在宽度或图片数量变化时才重新计算
        let cacheKey = "\(group.id)-\(availableWidth)"
        let currentImageCount = group.images.count
        
        // 检查是否需要重新计算布局
        if let cachedRows = layoutCache[cacheKey], 
           lastLayoutWidth == availableWidth && 
           lastImageCount == currentImageCount {
            return cachedRows
        }
        
        // 重新计算布局
        let rows = createFixedGridRows(from: group.images, availableWidth: availableWidth)
        
        // 更新缓存
        layoutCache[cacheKey] = rows
        lastLayoutWidth = availableWidth
        lastImageCount = currentImageCount
        
        // 清理过期的缓存（只保留最近几个）
        if layoutCache.count > ListViewConstants.maxCacheSize {
            let keysToRemove = Array(layoutCache.keys).prefix(layoutCache.count - ListViewConstants.maxCacheSize)
            for key in keysToRemove {
                layoutCache.removeValue(forKey: key)
            }
        }
        
        return rows
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
                            VStack {
                                if viewModel.isLoadingMore {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Button(action: {
                                        // 只有在窗口未调整时才触发加载更多
                                        if !isWindowResizing {
                                            viewModel.loadMoreImages()
                                        }
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
                            .id("load-more-indicator") // 为加载指示器添加ID
                            .background(
                                GeometryReader { geometry in
                                    Color.clear
                                        .onChange(of: geometry.frame(in: .global).minY) { minY in
                                            // 检测指示器是否进入可见区域（主要触发机制）
                                            // 只有在窗口未调整时才触发加载更多
                                            if !isWindowResizing {
                                                let screenHeight = NSScreen.main?.visibleFrame.height ?? 0
                                                if minY < screenHeight && minY > -geometry.size.height {
                                                    if viewModel.canLoadMore && !viewModel.isLoadingMore {
                                                        print("加载指示器进入可见区域，触发自动加载更多")
                                                        viewModel.loadMoreImages()
                                                    }
                                                }
                                            }
                                        }
                                }
                            )
                        }
                    }
                    .padding(.leading, 6)  // 左侧间距
                    .onReceive(NotificationCenter.default.publisher(for: UnifiedWindowManager.Notification.scrollToImage)) { notification in
                        if let userInfo = notification.userInfo,
                           let index = userInfo["index"] as? Int {
                            UnifiedWindowManager.shared.handleScrollToIndex(index)
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
                }
            }
            .onAppear {
                if !hasReceivedGeometry {
                    availableWidth = geometry.size.width
                    hasReceivedGeometry = true
                }
            }
            .onChange(of: geometry.size) { newSize in
                // 添加这行检查
                guard !viewModel.isSingleViewMode else { return }

                // 检测窗口大小是否发生显著变化（避免微小变化触发重算）
                let widthChangedSignificantly = abs(newSize.width - lastWindowSize.width) > ListViewConstants.resizeDetectionThreshold
                let heightChangedSignificantly = abs(newSize.height - lastWindowSize.height) > ListViewConstants.resizeDetectionThreshold
                
                if widthChangedSignificantly || heightChangedSignificantly {
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
        LazyVStack(alignment: .leading, spacing: 10) {
            let fixedGridRows = getFixedGridRows(for: group)
            
            if !hasReceivedGeometry {
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
        .id("\(group.id)-\(viewModel.manualThumbnailSize)") // 使用缩略图尺寸作为ID的一部分
    }
    
    private func performPhasedScroll(to index: Int, proxy: ScrollViewProxy) {
        guard index >= 0 && index < viewModel.images.count else { 
            return 
        }
        
        let targetImage = viewModel.images[index]
        
        // 简化重试机制：立即滚动一次，0.1秒后重试一次
        withAnimation {
            proxy.scrollTo(targetImage.id, anchor: .center)
        }       
        // 0.1秒后重试一次（防止目标项未渲染）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                proxy.scrollTo(targetImage.id, anchor: .center)
            }
        }
        
        // 0.5秒后清理滚动状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UnifiedWindowManager.shared.shouldScrollToIndex = nil
        }
    }
    
    private func getGlobalIndex(for image: ImageItem, in group: DirectoryGroup) -> Int {
        return viewModel.images.firstIndex { $0.id == image.id } ?? 0
    }
    
    private func selectDirectory() {
        viewModel.selectDirectory()
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
        // 窗口大小发生显著变化，标记为正在调整
        isWindowResizing = true
        
        // 立即更新布局宽度，确保界面实时响应
        availableWidth = newSize.width
        hasReceivedGeometry = true
        
        // 取消之前的结束检测计时器
        resizeEndTimer?.invalidate()
        
        // 设置新的结束检测计时器（无变化视为调整结束）
        resizeEndTimer = Timer.scheduledTimer(withTimeInterval: ListViewConstants.resizeEndDelay, repeats: false) { _ in
            // 窗口调整结束，仅标记调整状态结束
            isWindowResizing = false
            print("窗口拉伸结束，可以触发加载操作")
        }
        
        lastWindowSize = newSize
    }
}

struct SmartImageThumbnailView: View {
    let imageItem: ImageItem
    let size: CGSize
    let isSelected: Bool
    let onTap: () -> Void
    let onRightClick: () -> Void
    let onDoubleClick: () -> Void
    let viewModel: ImageBrowserViewModel // 添加ViewModel引用
    
    // 优化：使用ViewModel统一管理缩略图状态，避免重复的状态管理
    @State private var thumbnail: NSImage?
    
    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                imageView(thumbnail)
            } else {
                // 统一使用placeholder视图，避免重复的加载状态管理
                placeholderView
            }
        }
        .onAppear {
            loadThumbnail()
        }
        .onChange(of: imageItem.id) { _ in
            // 当图片项发生变化时重新加载缩略图
            loadThumbnail()
        }
    }
    
    @ViewBuilder
    private func imageView(_ thumbnail: NSImage) -> some View {
        Image(nsImage: thumbnail)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .clipped()
            .cornerRadius(ListViewConstants.cornerRadius)
            .overlay(selectedBorder)
            .scaleEffect(isSelected ? ListViewConstants.selectedScale : 1.0)
            .animation(.easeInOut(duration: ListViewConstants.selectionAnimationDuration), value: isSelected)
            .gesture(
                TapGesture()
                    .onEnded { _ in
                        onTap()
                        if NSApp.currentEvent?.clickCount == 2 {
                            onDoubleClick()
                        }
                    }
            )
            .contextMenu {
                contextMenuContent
            }
            .onDrag {
                // 拖拽功能：提供文件URL
                NSItemProvider(item: imageItem.url as NSURL, typeIdentifier: "public.file-url")
            }
    }
    
    @ViewBuilder
    private var selectedBorder: some View {
        RoundedRectangle(cornerRadius: ListViewConstants.cornerRadius)
            .stroke(isSelected ? Color.white : Color.clear, lineWidth: ListViewConstants.selectedBorderWidth)
    }
    
    @ViewBuilder
    private var hoverEffect: some View {
        RoundedRectangle(cornerRadius: ListViewConstants.cornerRadius)
            .fill(Color.black.opacity(ListViewConstants.hoverOpacity))
            .opacity(isSelected ? 1.0 : 0.0)
    }
    
    @ViewBuilder
    private var placeholderView: some View {
        Image(systemName: "photo")
            .font(.system(size: min(size.width, size.height) * ListViewConstants.placeholderIconScale))
            .foregroundColor(.gray)
            .frame(width: size.width, height: size.height)
            .background(Color.gray.opacity(ListViewConstants.placeholderBackgroundOpacity))
            .cornerRadius(ListViewConstants.cornerRadius)
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        Button("在 Finder 中显示") {
            NSWorkspace.shared.selectFile(imageItem.url.path, inFileViewerRootedAtPath: "")
        }
        Button("删除") {
            // 使用DispatchQueue.main.async来确保在主线程执行
            DispatchQueue.main.async {
                deleteImageWithConfirmation()
            }
        }
    }
    
    @MainActor
    private func deleteImageWithConfirmation() {
        // 获取当前图片在数组中的索引
        guard let index = viewModel.images.firstIndex(where: { $0.id == imageItem.id }) else { return }
        
        // 删除确认对话框
        let alert = NSAlert()
        alert.messageText = "确认删除"
        alert.informativeText = "确定要删除这张图片吗？此操作会将图片移到废纸篓。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        
        if alert.runModal() == .alertFirstButtonReturn {
            viewModel.deleteImage(at: index)
        }
    }
    
    @MainActor
    private func loadThumbnail() {
        // 重置缩略图状态，避免显示旧的缩略图
        thumbnail = nil
        
        viewModel.loadThumbnail(for: imageItem, size: size) { thumbnail in
            self.thumbnail = thumbnail
        }
    }
}

#Preview {
    ListView(viewModel: ImageBrowserViewModel())
}
