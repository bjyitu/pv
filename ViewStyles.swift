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