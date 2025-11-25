import SwiftUI

struct SingleImageView: View {
    @ObservedObject var viewModel: ImageBrowserViewModel
    @State private var scale: CGFloat = 1.1
    @State private var offset: CGSize = .zero
    @Environment(\.controlActiveState) private var controlActiveState

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            if let currentImage = currentImage {
                imageView(for: currentImage)
                    .scaleEffect(scale)
                    .offset(offset)
            } else {
                Text("没有图片")
                    .font(.title)
                    .foregroundColor(.white)
            }
            
            if viewModel.showProgressBar {
                VStack {
                    Spacer()
                    GeometryReader { geometry in
                        Rectangle()
                            .fill(Color.gray.opacity(0.8))
                            .frame(
                                width: geometry.size.width * CGFloat(viewModel.currentImageIndex + 1) / CGFloat(viewModel.totalImagesInDirectory),
                                height: 4
                            )
                            .animation(.linear, value: viewModel.currentImageIndex)
                    }
                    .frame(height: 4)
                }
            }
        }
        .overlay(
            UnifiedKeyboardListener(viewModel: viewModel, mode: .single)
        )
        .gesture(
            TapGesture()
                .onEnded { _ in
                    // 使用与ListView一致的NSApp.currentEvent检测方法
                    let isDoubleClick = NSApp.currentEvent?.clickCount == 2
                    
                    if isDoubleClick {
                        viewModel.stopAutoPlay()
                        
                        // 优化切换逻辑：确保从单图返回列表时显示完整目录内容
                        if viewModel.isSingleViewMode {
                            // 从单图切换到列表视图
                            viewModel.toggleViewMode()
                            
                            // 确保焦点正确设置到列表视图
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                NotificationCenter.default.post(name: NSNotification.Name("SetFocusToListView"), object: nil)
                            }
                        } else {
                            // 从列表切换到单图视图
                            viewModel.toggleViewMode()
                        }
                    }
                }
        )
        .onAppear {
            // DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                if let currentImage = self.currentImage {
                    UnifiedWindowManager.shared.adjustWindowForImage(currentImage.size, shouldCenter: true)
                    viewModel.isFirstTimeInSingleView = false
                }
            // }
            //实现窗口可拖
            // NSApp.windows.first?.isMovableByWindowBackground = true
            // 只在这个视图激活时设置
            if controlActiveState == .key {
                NSApp.keyWindow?.isMovableByWindowBackground = true
            }
        }
        .onChange(of: viewModel.currentImageIndex) { _ in
            if viewModel.isFirstTimeInSingleView {
                if let currentImage = self.currentImage {
                    UnifiedWindowManager.shared.adjustWindowForImage(currentImage.size, shouldCenter: true)
                }
                viewModel.isFirstTimeInSingleView = false
            }
            
            // 检测是否接近图片列表末尾，自动加载更多图片
            checkAndLoadMoreIfNeeded()
        }
        .onDisappear {
            // 离开时恢复
            NSApp.keyWindow?.isMovableByWindowBackground = false
        }        
    }
    
    private var currentImage: ImageItem? {
        guard viewModel.images.indices.contains(viewModel.currentImageIndex) else {
            return nil
        }
        return viewModel.images[viewModel.currentImageIndex]
    }
    
    private func checkAndLoadMoreIfNeeded() {
        // 当浏览到接近列表末尾时自动加载更多图片
        let threshold = 5 // 距离末尾5张图片时触发加载
        let currentIndex = viewModel.currentImageIndex
        let totalImages = viewModel.images.count
        
        if currentIndex >= totalImages - threshold && viewModel.canLoadMore && !viewModel.isLoadingMore {
            print("SingleImageView: 接近列表末尾，自动加载更多图片 (当前索引: \(currentIndex), 总数: \(totalImages))")
            viewModel.loadMoreImages()
        }
    }
    
    private func imageView(for imageItem: ImageItem) -> some View {
        GeometryReader { geometry in
            if let nsImage = NSImage(contentsOf: imageItem.url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)   
                    .overlay( //锐化边缘增强
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .blur(radius: 1)  // 轻微模糊
                            .blendMode(.difference)  // 差异混合突出边缘
                            .opacity(0.2)  // 降低强度
                    )
                    .contrast(1.2) //对比度和亮度
                    .brightness(0.05)                 
                    .onAppear {

                    }
                    .onChange(of: viewModel.currentImageIndex) { _ in
                        // 当切换图片时重置缩放并重新触发动画
                        scale = 1.1
                        withAnimation(.easeInOut(duration: viewModel.autoPlayInterval-1)) {
                            scale = 1.15
                        }
                    }
            } else {
                Rectangle()
                    .fill(Color.gray)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 48))
                            .foregroundColor(.white)
                    )
            }
        }
    }
    
}

#Preview {
    SingleImageView(viewModel: ImageBrowserViewModel())
}
