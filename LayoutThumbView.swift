import SwiftUI

struct LayoutThumbView: View {
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
        thumbnailContainer
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
            .cornerRadius(AppConstants.ListView.cornerRadius)
    }
    
    @ViewBuilder
    private var thumbnailContainer: some View {
        ZStack {
            if let thumbnail = thumbnail {
                imageView(thumbnail)
            } else {
                placeholderView
            }
        }
        .frame(width: size.width, height: size.height)
        .overlay(coverEffect)
        .overlay(selectedBorder)
        .contentShape(Rectangle()) // 确保整个区域都可点击
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
        RoundedRectangle(cornerRadius: AppConstants.ListView.cornerRadius)
                .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: AppConstants.ListView.selectedBorderWidth)
    }
    
    @ViewBuilder
    private var coverEffect: some View {
        RoundedRectangle(cornerRadius: AppConstants.ListView.cornerRadius)
            .fill(Color.black.opacity(0.5))
            .opacity(isSelected ? 1.0 : 0.0)
            .animation(.linear(duration: 0.1), value: isSelected)

    }
    
    @ViewBuilder
    private var placeholderView: some View {
        Image(systemName: "photo")
            .font(.system(size: min(size.width, size.height) * AppConstants.ListView.placeholderIconScale))
            .foregroundColor(.gray)
            .frame(width: size.width, height: size.height)
            .background(Color.gray.opacity(AppConstants.ListView.placeholderBackgroundOpacity))
            .cornerRadius(AppConstants.ListView.cornerRadius)
    }
    
    @ViewBuilder
    private var contextMenuContent: some View {
        Button("在 Finder 中显示") {
            // 使用DispatchQueue.main.async来确保在主线程执行
            DispatchQueue.main.async {
                // 获取当前图片在数组中的索引
                guard let index = viewModel.images.firstIndex(where: { $0.id == imageItem.id }) else { return }
                viewModel.dataManager.revealInFinder(at: index)
            }
        }
        Button("删除") {
            // 使用DispatchQueue.main.async来确保在主线程执行
            DispatchQueue.main.async {
                // 获取当前图片在数组中的索引
                guard let index = viewModel.images.firstIndex(where: { $0.id == imageItem.id }) else { return }
                viewModel.deleteImage(at: index)
            }
        }
    }
    
    @MainActor
    private func loadThumbnail() {
        // 重置缩略图状态，避免显示旧的缩略图
        // thumbnail = nil
        
        viewModel.loadThumbnail(for: imageItem, size: size) { thumbnail in
            self.thumbnail = thumbnail
        }
    }
}