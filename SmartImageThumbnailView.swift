import SwiftUI

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
    }
    
    @ViewBuilder
    private func imageView(_ thumbnail: NSImage) -> some View {
        Image(nsImage: thumbnail)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: size.width, height: size.height)
            .clipped()
            .cornerRadius(ListViewConstants.cornerRadius)
            .overlay(hoverEffect)
            .overlay(selectedBorder)
            // .animation(.easeInOut(duration: ListViewConstants.selectionAnimationDuration), value: isSelected)
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
            .strokeBorder(isSelected ? Color.white : Color.clear, lineWidth: ListViewConstants.selectedBorderWidth)
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
        // thumbnail = nil
        
        viewModel.loadThumbnail(for: imageItem, size: size) { thumbnail in
            self.thumbnail = thumbnail
        }
    }
}