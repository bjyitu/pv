import SwiftUI

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
    
    private func createFixedGridRows(from images: [ImageItem], availableWidth: CGFloat) -> [FixedGridRow] {
        guard !images.isEmpty else { return [] }
        
        // 布局配置
        let imagesPerRow = 6  // 每行6个缩图
        let spacing: CGFloat = 10  // 图片间距
        let horizontalPadding: CGFloat = 6  // 水平内边距
        
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
        
        for (index, row) in rows.enumerated() {
            print("第\(index + 1)行: \(row.images.count)张图片")
        }
        print("=== ListView 固定网格布局结束 ===")
        
        return rows
    }
    
    /// 计算图片的平均宽高比
    private func calculateAverageAspectRatio(images: [ImageItem]) -> CGFloat {
        guard !images.isEmpty else { return 1.0 } // 默认宽高比
        
        let totalAspectRatio = images.reduce(0.0) { result, image in
            return result + (image.size.width / image.size.height)
        }
        
        return totalAspectRatio / CGFloat(images.count)
    }
    
    private func getFixedGridRows(for group: DirectoryGroup) -> [FixedGridRow] {
        guard hasReceivedGeometry else { return [] }
        
        return createFixedGridRows(from: group.images, availableWidth: availableWidth)
    }

    var body: some View {
        if viewModel.isLoading {
            loadingStateView
        } else if let errorMessage = viewModel.errorMessage {
            errorStateView(errorMessage)
        } else if viewModel.directoryGroups.isEmpty {
            emptyStateView
        } else {
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
                                            viewModel.loadMoreImages()
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
                                            .onAppear {
                                                // 当加载指示器出现在视图中时触发加载更多
                                                if viewModel.canLoadMore && !viewModel.isLoadingMore {
                                                    print("加载指示器出现在视图中，触发自动加载更多")
                                                    viewModel.loadMoreImages()
                                                }
                                            }
                                            .onChange(of: geometry.frame(in: .global).minY) { minY in
                                                // 检测指示器是否进入可见区域
                                                let screenHeight = NSScreen.main?.visibleFrame.height ?? 0
                                                if minY < screenHeight && minY > -geometry.size.height {
                                                    if viewModel.canLoadMore && !viewModel.isLoadingMore {
                                                        print("加载指示器进入可见区域，触发自动加载更多")
                                                        viewModel.loadMoreImages()
                                                    }
                                                }
                                            }
                                    }
                                )
                                .onAppear {
                                    // 延迟检测，确保指示器完全渲染
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        if viewModel.canLoadMore && !viewModel.isLoadingMore {
                                            print("加载指示器渲染完成，触发自动加载更多")
                                            viewModel.loadMoreImages()
                                        }
                                    }
                                }
                                .onChange(of: viewModel.canLoadMore) { canLoadMore in
                                    // 当canLoadMore状态改变时，检查是否需要自动加载
                                    if canLoadMore && !viewModel.isLoadingMore {
                                        // 立即尝试加载一次
                                        viewModel.loadMoreImages()
                                        
                                        // 延迟再次检查，确保加载触发
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            if viewModel.canLoadMore && !viewModel.isLoadingMore {
                                                viewModel.loadMoreImages()
                                            }
                                        }
                                    }
                                }
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
                .onChange(of: geometry.size.width) { newWidth in
                    // 添加这行检查
                    guard !viewModel.isSingleViewMode else { return }

                    availableWidth = newWidth
                    hasReceivedGeometry = true
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
            print("开始滚动到索引 \(index)")
            proxy.scrollTo(targetImage.id, anchor: .center)
        }
        
        // 0.1秒后重试一次（防止目标项未渲染）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                print("重试滚动到索引 \(index)")
                proxy.scrollTo(targetImage.id, anchor: .center)
            }
        }
        
        // 0.5秒后清理滚动状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            print("清理滚动状态 \(index)")
            UnifiedWindowManager.shared.shouldScrollToIndex = nil
        }
    }
    
    private func getGlobalIndex(for image: ImageItem, in group: DirectoryGroup) -> Int {
        return viewModel.images.firstIndex { $0.id == image.id } ?? 0
    }
    
    private func selectDirectory() {
        viewModel.selectDirectory()
    }
    
    @State private var isPressed = false
    
    private var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
                .brightness(isPressed ? -0.2 : 0) // 点击时变暗
            
            Text("点击选择目录")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text("支持 JPG、PNG、GIF 等常见图片格式")
                .font(.caption)
                .foregroundColor(Color.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle()) // 使整个区域可点击
        .scaleEffect(isPressed ? 0.95 : 1.0) // 点击时轻微缩小
        .animation(.easeInOut(duration: 0.1), value: isPressed) // 添加动画
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.05)) {
                    isPressed = false
                }
                selectDirectory()
            }
        }
    }
    
    private var loadingStateView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("正在加载图片...")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func errorStateView(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            
            Text("加载失败")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("重新选择目录") {
                viewModel.currentDirectory = nil
                viewModel.errorMessage = nil
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
}

struct SmartImageThumbnailView: View {
    let imageItem: ImageItem
    let size: CGSize
    let isSelected: Bool
    let onTap: () -> Void
    let onRightClick: () -> Void
    let onDoubleClick: () -> Void
    let viewModel: ImageBrowserViewModel // 添加ViewModel引用
    
    @State private var thumbnail: NSImage?
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                imageView(thumbnail)
            } else if isLoading {
                loadingView
            } else {
                placeholderView
            }
        }
        .onAppear {
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
            .cornerRadius(4)
            .overlay(selectedBorder)
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isSelected)
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
        RoundedRectangle(cornerRadius: 4)
            .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
    }
    
    @ViewBuilder
    private var hoverEffect: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color.black.opacity(0.05))
            .opacity(isSelected ? 1.0 : 0.0)
    }
    
    @ViewBuilder
    private var loadingView: some View {
        ProgressView()
            .frame(width: size.width, height: size.height)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)
    }
    
    @ViewBuilder
    private var placeholderView: some View {
        Image(systemName: "photo")
            .font(.system(size: min(size.width, size.height) * 0.3))
            .foregroundColor(.gray)
            .frame(width: size.width, height: size.height)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(4)
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
        viewModel.loadThumbnail(for: imageItem, size: size) { thumbnail in
            self.thumbnail = thumbnail
            self.isLoading = false
        }
    }
}

#Preview {
    ListView(viewModel: ImageBrowserViewModel())
}