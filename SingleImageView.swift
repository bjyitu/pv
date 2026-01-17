import SwiftUI
import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit

/// NSImage扩展：添加锐化功能
extension NSImage {
    /// 应用锐化滤镜
    func sharpened(intensity: Double = 1.2, radius: Double = 1) -> NSImage? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        // 使用USM锐化滤镜（Unsharp Mask）
        // let sharpenFilter = CIFilter.unsharpMask()
        // sharpenFilter.inputImage = ciImage
        // sharpenFilter.intensity = Float(intensity)
        // sharpenFilter.radius = Float(radius)

        let sharpenFilter = CIFilter.noiseReduction()
        sharpenFilter.inputImage = ciImage
        sharpenFilter.noiseLevel = 0.015 //最大0.1,0.01至0.02
        sharpenFilter.sharpness = 0.8 //最大2,0.2-1之间
        
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
    static let initialScale: CGFloat = 1.02
    
    /// 图片动画结束时的缩放比例
    static let targetScale: CGFloat = 1.02
    
    /// 自动加载更多图片的阈值（距离末尾的图片数量）
    static let loadMoreThreshold: Int = 5
    
    /// 锐化滤镜强度 (0.0 - 2.0)
    static let sharpenIntensity: Double = 5.0
    
    /// 锐化滤镜半径 (像素)
    static let sharpenRadius: Double = 0.3
    
    /// 图片对比度增强值
    static let contrastEnhancement: CGFloat = 1.1
    
    /// 图片亮度调整值
    static let brightnessAdjustment: CGFloat = 0.05
    
    /// 占位符图标的大小
    static let placeholderIconSize: CGFloat = 48
}

struct SingleImageView: View {
    @ObservedObject var viewModel: ImageBrowserViewModel
    @State private var scale: CGFloat = SingleImageViewConstants.initialScale
    @State private var animationProgress: CGFloat = 0.0
    @State private var cachedImage: NSImage?
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
                    UnifiedProgressBar(
                        currentIndex: viewModel.currentImageIndex,
                        totalItems: viewModel.totalImagesInDirectory,
                        isAutoPlaying: viewModel.isAutoPlaying,
                        animationProgress: animationProgress,
                        autoPlayInterval: viewModel.autoPlayInterval
                    )
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
            
            // 初始化单图视图缓存
            initializeSingleViewCache()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("UpdateSingleViewCache"))) { _ in
            // 更新缓存并预加载相邻图片
            updateSingleViewCache()
            
            // 通知列表视图更新预加载区域
            notifyListViewToPreloadCurrentRegion()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ClearSingleViewCache"))) { _ in
            // 清理缓存的图片
            cachedImage = nil
        }
        .onChange(of: viewModel.currentImageIndex) { _ in
            //修改窗口大小,如果是第一张,则需要调整窗口大小,暂时禁用,每一张都调整窗口大小
            if viewModel.isFirstTimeInSingleView {
                adjustWindowForCurrentImage(shouldCenter: true)
            }else{
                adjustWindowForCurrentImage(shouldCenter: false)
            }
            
            // 检测是否接近图片列表末尾，自动加载更多图片
            checkAndLoadMoreIfNeeded()
            
            // 重置动画进度
            resetAnimationProgress()
            
            // 延迟更新缓存，确保images数组已经更新
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.updateSingleViewCache()
            }
            
            // 通知列表视图更新预加载区域
            notifyListViewToPreloadCurrentRegion()
        }
        .onChange(of: viewModel.isAutoPlaying) { isAutoPlaying in
            if isAutoPlaying {
                resetAnimationProgress()
            } else {
                animationProgress = 0.0
            }
        }
        .onDisappear {
            // 离开时恢复
            NSApp.keyWindow?.isMovableByWindowBackground = false
            
            // 清理单图视图缓存
            cleanupSingleViewCache()
        }
        .onChange(of: controlActiveState) { newState in
            // 窗口激活状态变化时更新缓存窗口大小
            if newState == .key, let window = NSApp.keyWindow {
                let windowSize = window.frame.size
                UnifiedCacheManager.shared.singleViewCacheManager.updateWindowSize(windowSize)
            }
        }
        .overlay(
            // 播放/暂停按钮 - 放在左下角
            VStack {
                Spacer()
                HStack {
                    playPauseButton
                        .padding(.leading, 20)
                        .padding(.bottom, 20)
                    Spacer()
                }
            }
        )
    }
    
    // 播放/暂停按钮
    private var playPauseButton: some View {
        PlayPauseButton(
            isAutoPlaying: viewModel.isAutoPlaying,
            action: {
                viewModel.toggleAutoPlay()
            }
        )
    }
    
    private func adjustWindowForCurrentImage(shouldCenter centered: Bool = true) {
        if let currentImage = self.currentImage {
            UnifiedWindowManager.shared.adjustWindowForImage(currentImage.size, shouldCenter: centered)
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
            viewModel.dataManager.loadMoreImages()
        }
    }
    
    private func resetAnimationProgress() {
        animationProgress = 0.0
        
        // 启动动画
        if viewModel.isAutoPlaying {
            withAnimation(.easeOut(duration: viewModel.autoPlayInterval)) {
                animationProgress = 1.0
            }
        }
    }
    
    // MARK: - 单图视图缓存管理
    
    private func initializeSingleViewCache() {
        guard let window = NSApp.keyWindow else { return }
        let windowSize = window.frame.size
        
        // 初始化缓存窗口大小
        UnifiedCacheManager.shared.singleViewCacheManager.updateWindowSize(windowSize)
        
        // 加载当前图片到缓存
        updateSingleViewCache()
    }
    
    private func updateSingleViewCache() {
        guard let currentImage = currentImage else { return }
        
        // 使用单图视图缓存管理器加载图片
        UnifiedCacheManager.shared.singleViewCacheManager.loadSingleViewImage(for: currentImage) { image in
            DispatchQueue.main.async {
                self.cachedImage = image
            }
        }
        
        // 预加载相邻图片
        UnifiedCacheManager.shared.singleViewCacheManager.preloadImages(for: viewModel.images, around: viewModel.currentImageIndex)
    }
    
    private func cleanupSingleViewCache() {
        // 清理单图视图缓存
        UnifiedCacheManager.shared.singleViewCacheManager.clearSingleViewCache()
        cachedImage = nil
    }
    
    // 通知列表视图预加载当前区域
    private func notifyListViewToPreloadCurrentRegion() {
        let currentIndex = viewModel.currentImageIndex
        
        // 发送通知，让列表视图预加载当前图片所在的区域
        NotificationCenter.default.post(
            name: AppConstants.Notifications.preloadImageRegion,
            object: nil,
            userInfo: ["index": currentIndex]
        )
        
        print("SingleImageView: 通知列表视图预加载区域，当前索引: \(currentIndex), 总图片数: \(viewModel.images.count)")
    }
    
    private func printImageSizeInfo(image: NSImage, geometry: GeometryProxy) {
        // 打印调试信息
        print("=== 图片尺寸调试信息 ===")
        print("图片原始尺寸: \(image.size)")
        
        // 获取窗口尺寸
        if let window = NSApp.keyWindow {
            print("窗口尺寸: \(window.frame.size)")
            print("窗口内容区域尺寸: \(window.contentView?.frame.size ?? .zero)")
        }
        
        print("GeometryReader 尺寸: \(geometry.size)")
        print("安全区域: \(geometry.safeAreaInsets)")
        
        // 计算适配比例
        let scaleX = geometry.size.width / image.size.width
        let scaleY = geometry.size.height / image.size.height
        let actualScale = min(scaleX, scaleY)
        let displaySize = CGSize(
            width: image.size.width * actualScale,
            height: image.size.height * actualScale
        )
        print("适配比例: scaleX=\(scaleX), scaleY=\(scaleY), actualScale=\(actualScale)")
        print("预期显示尺寸: \(displaySize)")
        print("水平黑边: \((geometry.size.width - displaySize.width) / 2)")
        print("垂直黑边: \((geometry.size.height - displaySize.height) / 2)")
        print("========================")
    }
    
    private func imageView(for imageItem: ImageItem) -> some View {
        GeometryReader { geometry in
            // 获取图片：优先使用缓存，其次从文件加载
            let image: NSImage? = {
                if let cachedImage = cachedImage {
                    return cachedImage
                } else if let nsImage = NSImage(contentsOf: imageItem.url) {
                    return nsImage
                }
                return nil
            }()
            
            // 调试信息：打印尺寸信息
            if let image = image {
                let sharpenedImage = image.sharpened(intensity: SingleImageViewConstants.sharpenIntensity, 
                                                    radius: SingleImageViewConstants.sharpenRadius) ?? image
                
                // 统一的图片显示视图
                Image(nsImage: sharpenedImage)
                    .resizable()
                    // .antialiased(true)
                    // .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .clipped()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contrast(SingleImageViewConstants.contrastEnhancement)
                    .brightness(SingleImageViewConstants.brightnessAdjustment)
                    .scaleEffect(scale)
                    .onAppear {
                        printImageSizeInfo(image: sharpenedImage, geometry: geometry)
                    }
                    .onChange(of: viewModel.currentImageIndex) { _ in
                        scale = SingleImageViewConstants.initialScale
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.005) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                scale = SingleImageViewConstants.targetScale
                            }
                        }
                    }
            } else {
                // 占位符视图
                Rectangle()
                    .fill(Color.gray)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: SingleImageViewConstants.placeholderIconSize))
                            .foregroundColor(.white)
                    )
            }
            
        }
        .edgesIgnoringSafeArea(.all)
    }
    
}

#Preview {
    SingleImageView(viewModel: ImageBrowserViewModel())
}