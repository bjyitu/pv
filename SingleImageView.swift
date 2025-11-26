import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins

/// NSImage扩展：添加锐化功能
extension NSImage {
    /// 应用锐化滤镜
    func sharpened(intensity: Double = 0.8, radius: Double = 2.0) -> NSImage? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        // 使用USM锐化滤镜（Unsharp Mask）
        let sharpenFilter = CIFilter.unsharpMask()
        sharpenFilter.inputImage = ciImage
        sharpenFilter.intensity = Float(intensity)
        sharpenFilter.radius = Float(radius)
        
        guard let outputImage = sharpenFilter.outputImage else {
            return nil
        }
        
        // 将CIImage转换回NSImage
        let rep = NSCIImageRep(ciImage: outputImage)
        let sharpenedImage = NSImage(size: rep.size)
        sharpenedImage.addRepresentation(rep)
        
        return sharpenedImage
    }
}

/// 单图视图常量定义
struct SingleImageViewConstants {
    /// 图片初始缩放比例
    static let initialScale: CGFloat = 1.1
    
    /// 图片动画结束时的缩放比例
    static let targetScale: CGFloat = 1.15
    
    /// 进度条高度（像素）
    static let progressBarHeight: CGFloat = 4
    
    /// 自动加载更多图片的阈值（距离末尾的图片数量）
    static let loadMoreThreshold: Int = 5
    
    /// 锐化滤镜强度 (0.0 - 2.0)
    static let sharpenIntensity: Double = 0.6
    
    /// 锐化滤镜半径 (像素)
    static let sharpenRadius: Double = 0.7
    
    /// 图片对比度增强值
    static let contrastEnhancement: CGFloat = 1.2
    
    /// 图片亮度调整值
    static let brightnessAdjustment: CGFloat = 0.03
    
    /// 占位符图标的大小
    static let placeholderIconSize: CGFloat = 48
}

struct SingleImageView: View {
    @ObservedObject var viewModel: ImageBrowserViewModel
    @State private var scale: CGFloat = SingleImageViewConstants.initialScale
    @Environment(\.controlActiveState) private var controlActiveState

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            if let currentImage = currentImage {
                imageView(for: currentImage)
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
                            .fill(Color.accentColor.opacity(0.8))
                            .frame(
                                width: geometry.size.width * CGFloat(viewModel.currentImageIndex + 1) / CGFloat(viewModel.totalImagesInDirectory),
                                height: 4
                            )
                            .animation(.linear, value: viewModel.currentImageIndex)
                    }
                    .frame(height: SingleImageViewConstants.progressBarHeight)
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
                            
                            // 确保焦点正确设置到列表视图,model里有延迟设定0.3秒
                            NotificationCenter.default.post(name: NSNotification.Name("SetFocusToListView"), object: nil)
                        } else {
                            // 从列表切换到单图视图
                            viewModel.toggleViewMode()
                        }
                    }
                }
        )
        .onAppear {
            adjustWindowForCurrentImage()
            //实现窗口可拖
            if controlActiveState == .key {
                NSApp.keyWindow?.isMovableByWindowBackground = true
            }
        }
        .onChange(of: viewModel.currentImageIndex) { _ in
            //修改窗口大小,如果是第一张
            if viewModel.isFirstTimeInSingleView {
                adjustWindowForCurrentImage()
            }
            
            // 检测是否接近图片列表末尾，自动加载更多图片
            checkAndLoadMoreIfNeeded()
        }
        .onDisappear {
            // 离开时恢复
            NSApp.keyWindow?.isMovableByWindowBackground = false
        }        
    }
    
    private func adjustWindowForCurrentImage() {
        if let currentImage = self.currentImage {
            UnifiedWindowManager.shared.adjustWindowForImage(currentImage.size, shouldCenter: true)
            viewModel.isFirstTimeInSingleView = false
        }
    }
    
    private var currentImage: ImageItem? {
        guard viewModel.images.indices.contains(viewModel.currentImageIndex) else {
            return nil
        }
        return viewModel.images[viewModel.currentImageIndex]
    }
    
    private func checkAndLoadMoreIfNeeded() {
        let threshold = SingleImageViewConstants.loadMoreThreshold
        let currentIndex = viewModel.currentImageIndex
        let totalImages = viewModel.images.count
        
        if currentIndex >= totalImages - threshold && viewModel.canLoadMore && !viewModel.isLoadingMore {
            print("SingleImageView: 接近列表末尾，自动加载更多图片 (当前索引: \(currentIndex), 总数: \(totalImages))")
            viewModel.loadMoreImages()
        }
    }
    
    private func imageView(for imageItem: ImageItem) -> some View {
        GeometryReader { geometry in
            if let nsImage = NSImage(contentsOf: imageItem.url),
               let sharpenedImage = nsImage.sharpened(
                   intensity: SingleImageViewConstants.sharpenIntensity,
                   radius: SingleImageViewConstants.sharpenRadius
               ) {
                Image(nsImage: sharpenedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contrast(SingleImageViewConstants.contrastEnhancement)
                    .brightness(SingleImageViewConstants.brightnessAdjustment)
                    .scaleEffect(scale)
                    .onChange(of: viewModel.currentImageIndex) { _ in
                        withAnimation(.linear(duration: 0)) {
                            scale = SingleImageViewConstants.initialScale
                        }
                        withAnimation(.easeOut(duration: viewModel.autoPlayInterval-2)) {
                            scale = SingleImageViewConstants.targetScale
                        }
                    }
            } else {
                Rectangle()
                    .fill(Color.gray)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: SingleImageViewConstants.placeholderIconSize))
                            .foregroundColor(.white)
                    )
            }
        }
    }
    
}

#Preview {
    SingleImageView(viewModel: ImageBrowserViewModel())
}