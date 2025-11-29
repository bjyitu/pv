import SwiftUI

// MARK: - 视图样式常量
struct ViewStyles {
    
    // MARK: - 字体样式
    struct Fonts {
        static let title2 = Font.title2
        static let headline = Font.headline
        static let body = Font.body
        static let caption = Font.caption
        
        static func system(size: CGFloat) -> Font {
            Font.system(size: size)
        }
    }
    
    // MARK: - 颜色样式
    struct Colors {
        static let secondary = Color.secondary
        static let orange = Color.orange
        static let white = Color.white
        static let clear = Color.clear
        
        static func secondaryOpacity(_ opacity: Double) -> Color {
            Color.secondary.opacity(opacity)
        }
        
        static func grayOpacity(_ opacity: Double) -> Color {
            Color.gray.opacity(opacity)
        }
        
        static func blackOpacity(_ opacity: Double) -> Color {
            Color.black.opacity(opacity)
        }
    }
    
    // MARK: - 布局常量
    struct Layout {
        static let leadingPadding: CGFloat = 6
        static let verticalPadding: CGFloat = 20
        static let horizontalPadding: CGFloat = 20
        static let cornerRadius: CGFloat = 4
        static let selectedBorderWidth: CGFloat = 2
        
        static let maxWidthInfinity = CGFloat.infinity
        static let maxHeightInfinity = CGFloat.infinity
        
        static let thumbnailSizeMultiplier: CGFloat = 0.3
    }
    
    // MARK: - 动画常量
    struct Animations {
        static let easeInOutShort = Animation.easeInOut(duration: 0.1)
        static let easeInOutMedium = Animation.easeInOut(duration: 0.15)
        static let easeInOutLong = Animation.easeInOut(duration: 0.3)
    }
    
    // MARK: - 按钮样式
    struct Buttons {
        /// 播放/暂停按钮尺寸
        static let playPauseButtonSize: CGFloat = 50
        
        /// 播放/暂停按钮内边距
        static let playPauseButtonPadding: CGFloat = 8
        
        /// 播放/暂停按钮背景透明度
        static let playPauseButtonBackgroundOpacity: Double = 0.3
        
        /// 播放/暂停按钮悬停时背景透明度
        static let playPauseButtonHoverOpacity: Double = 0.8
        
        /// 播放/暂停按钮圆角半径
        static let playPauseButtonCornerRadius: CGFloat = 25
        
        /// 播放/暂停按钮图标大小
        static let playPauseIconSize: CGFloat = 24
        
        /// 布局切换按钮尺寸
        static let layoutToggleButtonSize: CGFloat = 50
        
        /// 布局切换按钮内边距
        static let layoutToggleButtonPadding: CGFloat = 8
        
        /// 布局切换按钮背景透明度
        static let layoutToggleButtonBackgroundOpacity: Double = 0.3
        
        /// 布局切换按钮悬停时背景透明度
        static let layoutToggleButtonHoverOpacity: Double = 0.8
        
        /// 布局切换按钮圆角半径
        static let layoutToggleButtonCornerRadius: CGFloat = 25
        
        /// 布局切换按钮图标大小
        static let layoutToggleIconSize: CGFloat = 24
    }
}



// MARK: - 预定义样式
struct EmptyStateStyle {
    func apply<V: View>(to view: V) -> some View {
        view
            .frame(maxWidth: ViewStyles.Layout.maxWidthInfinity, 
                   maxHeight: ViewStyles.Layout.maxHeightInfinity)
    }
}

struct LoadingStateStyle {
    func apply<V: View>(to view: V) -> some View {
        view
            .frame(maxWidth: ViewStyles.Layout.maxWidthInfinity, 
                   maxHeight: ViewStyles.Layout.maxHeightInfinity)
    }
}

struct ErrorStateStyle {
    func apply<V: View>(to view: V) -> some View {
        view
            .frame(maxWidth: ViewStyles.Layout.maxWidthInfinity, 
                   maxHeight: ViewStyles.Layout.maxHeightInfinity)
    }
}

// MARK: - 统一状态视图组件
struct UnifiedStateViews {
    
    // 统一的加载状态视图
    static func loadingView(scale: CGFloat = 1.5, message: String = "正在加载图片...") -> some View {
        VStack(spacing: 10) {
            ProgressView()
                .scaleEffect(scale)
            
            Text(message)
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // 统一的错误状态视图
    static func errorView(message: String, onRetry: (() -> Void)? = nil) -> some View {
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
            
            if let onRetry = onRetry {
                Button("重试") {
                    onRetry()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // 统一的空状态视图
    static func emptyView(icon: String = "photo.on.rectangle", 
                         title: String = "点击选择目录", 
                         subtitle: String = "支持 JPG、PNG、GIF 等常见图片格式") -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            Text(subtitle)
                .font(.caption)
                .foregroundColor(Color.secondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 播放/暂停按钮组件
struct PlayPauseButton: View {
    let isAutoPlaying: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var isMouseOut = false
    @State private var mouseOutTimer: Timer?
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(ViewStyles.Buttons.playPauseButtonBackgroundOpacity))
                    .frame(width: ViewStyles.Buttons.playPauseButtonSize, 
                           height: ViewStyles.Buttons.playPauseButtonSize)
                
                Image(systemName: isAutoPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: ViewStyles.Buttons.playPauseIconSize))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(PlayPauseButtonStyle(isPressed: $isPressed))
        .cornerRadius(ViewStyles.Buttons.playPauseButtonCornerRadius)
        .help(isAutoPlaying ? "暂停自动播放" : "开始自动播放")
        .scaleEffect(buttonScale)
        .opacity(buttonOpacity)
        .onHover { hovering in
            isHovered = hovering
            
            // 鼠标移入时取消计时器并恢复不透明度
            if hovering {
                mouseOutTimer?.invalidate()
                mouseOutTimer = nil
                isMouseOut = false
            } else {
                // 鼠标移出时启动1秒后变透明的计时器
                mouseOutTimer?.invalidate()
                mouseOutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                    isMouseOut = true
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: buttonScale)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .animation(.easeInOut(duration: 0.3), value: buttonOpacity)
    }
    
    private var buttonScale: Double {
        isPressed ? 1.0 : (isHovered ? 1.1 : 1.0)
    }
    
    private var buttonOpacity: Double {
        if isPressed {
            return 0.8 // 按下时变暗
        } else if isMouseOut {
            return 0.2 // 鼠标移出后变透明
        } else {
            return 0.5 // 正常状态
        }
    }
    
    // 播放/暂停按钮样式（处理按下状态）
    private struct PlayPauseButtonStyle: ButtonStyle {
        @Binding var isPressed: Bool
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .onChange(of: configuration.isPressed) { pressed in
                    isPressed = pressed
                }
        }
    }
}

// MARK: - 进度条样式和组件
struct ProgressBarStyles {
    /// 进度条高度（像素）
    static let progressBarHeight: CGFloat = 2
    
    /// 进度条背景透明度
    static let progressBarBackgroundOpacity: Double = 0.3
    
    /// 进度条前景透明度
    static let progressBarForegroundOpacity: Double = 0.8
    
    /// 进度条动画持续时间
    static let progressBarAnimationDuration: Double = 0.3
}

// MARK: - 统一进度条组件
struct UnifiedProgressBar: View {
    let currentIndex: Int
    let totalItems: Int
    let isAutoPlaying: Bool
    let animationProgress: CGFloat
    let autoPlayInterval: TimeInterval
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 背景条（整个进度条区域）
                Rectangle()
                    .fill(Color.black.opacity(ProgressBarStyles.progressBarBackgroundOpacity))
                    .frame(width: geometry.size.width, height: ProgressBarStyles.progressBarHeight)
                
                // 动画层 - 根据剩余宽度调整速度的渐变填充动画
                if isAutoPlaying {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0.0),
                                    Color.white.opacity(1.0),
                                    Color.white.opacity(1.0),
                                    Color.white.opacity(1.0),
                                    Color.white.opacity(0.0)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(
                            // width: animationProgress * geometry.size.width * (1 - (CGFloat(currentIndex + 1) / CGFloat(totalItems))), //剩余进度宽度
                            width: animationProgress * geometry.size.width * CGFloat(currentIndex) / CGFloat(totalItems),
                            height: ProgressBarStyles.progressBarHeight - 1
                        )
                        // .offset(x: geometry.size.width * CGFloat(currentIndex) / CGFloat(totalItems)) // 从剩余进度位置开始
                        // 从0开始覆盖现有进度条的方案,width也需要调成当前进度的宽度
                        .offset(x: 0)
                        .blendMode(.overlay)
                        .zIndex(1) // 确保动画层在主进度条之上
                }
                
                // 主进度条
                Rectangle()
                    .fill(Color.accentColor.opacity(ProgressBarStyles.progressBarForegroundOpacity))
                    .frame(
                        width: geometry.size.width * CGFloat(currentIndex) / CGFloat(totalItems),
                        height: ProgressBarStyles.progressBarHeight
                    )
                    .animation(.linear(duration: ProgressBarStyles.progressBarAnimationDuration), value: currentIndex)
            }
        }
        .frame(height: ProgressBarStyles.progressBarHeight)
    }
}

// MARK: - 布局切换按钮组件
struct LayoutToggleButton: View {
    let isSmartLayout: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    @State private var isMouseOut = false
    @State private var mouseOutTimer: Timer?
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(ViewStyles.Buttons.layoutToggleButtonBackgroundOpacity))
                    .frame(width: ViewStyles.Buttons.layoutToggleButtonSize, 
                           height: ViewStyles.Buttons.layoutToggleButtonSize)
                
                Image(systemName: isSmartLayout ? "square.grid.3x3" : "rectangle.grid.1x2")
                    .font(.system(size: ViewStyles.Buttons.layoutToggleIconSize))
                    .foregroundColor(.white)
            }
        }
        .buttonStyle(LayoutToggleButtonStyle(isPressed: $isPressed))
        .cornerRadius(ViewStyles.Buttons.layoutToggleButtonCornerRadius)
        .help(isSmartLayout ? "切换到固定网格布局" : "切换到智能布局")
        .scaleEffect(buttonScale)
        .opacity(buttonOpacity)
        .onHover { hovering in
            isHovered = hovering
            
            // 鼠标移入时取消计时器并恢复不透明度
            if hovering {
                mouseOutTimer?.invalidate()
                mouseOutTimer = nil
                isMouseOut = false
            } else {
                // 鼠标移出时启动1秒后变透明的计时器
                mouseOutTimer?.invalidate()
                mouseOutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { _ in
                    isMouseOut = true
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: buttonScale)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .animation(.easeInOut(duration: 0.3), value: buttonOpacity)
    }
    
    private var buttonScale: Double {
        isPressed ? 1.0 : (isHovered ? 1.1 : 1.0)
    }
    
    private var buttonOpacity: Double {
        if isPressed {
            return 0.8 // 按下时变暗
        } else if isMouseOut {
            return 0.2 // 鼠标移出后变透明
        } else {
            return 0.5 // 正常状态
        }
    }
    
    // 布局切换按钮样式（处理按下状态）
    private struct LayoutToggleButtonStyle: ButtonStyle {
        @Binding var isPressed: Bool
        
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .onChange(of: configuration.isPressed) { pressed in
                    isPressed = pressed
                }
        }
    }
}