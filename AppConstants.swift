import SwiftUI

/// 应用常量统一配置文件
/// 集中管理所有延迟时间、尺寸配置、UI常量等
struct AppConstants {
    
    // MARK: - 延迟时间配置
    struct Delays {
        /// 应用启动延迟（秒）- 等待应用完全启动
        static let appLaunch: Double = 0.05
        
        /// 初始文件处理延迟（秒）- 等待应用完全启动后再处理启动参数
        static let initialFileProcessing: Double = 0.1
        
        /// 部分加载后重试延迟（秒）- 在图片列表部分加载后尝试定位图片
        static let retryAfterPartialLoad: Double = 0.1
        
        /// 完整扫描后重试延迟（秒）- 在触发完整目录扫描后再次尝试定位图片
        static let retryAfterFullScan: Double = 0.1
        
        /// 强制滚动延迟时间（秒），用于避免滚动冲突
        static let forceScroll: Double = 0.1
        
        /// 窗口关闭延迟时间（秒），用于确保应用正确退出
        static let windowClose: Double = 0.1
        
        /// 窗口初始化延迟时间（秒）
        static let windowInitialization: Double = 0.1
    }
    
    // MARK: - 窗口和尺寸配置
    struct Window {
        /// 最小窗口宽度（像素）
        static let minWidth: CGFloat = 400
        
        /// 最小窗口高度（像素）
        static let minHeight: CGFloat = 300
        
        /// 默认窗口宽度（像素）
        static let defaultWidth: CGFloat = 1200
        
        /// 默认窗口高度（像素）
        static let defaultHeight: CGFloat = 800
        
        /// 最大屏幕使用比例（0.0-1.0），控制窗口占屏幕的最大比例
        static let maxScreenUsageRatio: CGFloat = 0.95
        
        /// 默认屏幕使用比例，用于计算默认窗口大小
        static let defaultScreenUsageRatio: CGFloat = 0.8
        
        /// 窗口边距配置
        static let margins: (horizontal: CGFloat, vertical: CGFloat) = (40, 40)
        
        /// 窗口大小变化检测阈值（像素），避免微小变化触发重布局
        static let resizeDetectionThreshold: CGFloat = 5
    }
    
    // MARK: - 列表视图配置
    struct ListView {
        /// 每行显示的图片数量，影响网格布局的列数
        static let imagesPerRow = 6
        
        /// 图片之间的间距（水平和垂直方向相同）
        static let spacing: CGFloat = 10
        
        /// 列表视图的水平内边距，用于左右两侧的留白
        static let horizontalPadding: CGFloat = 10
        
        /// 图片缩略图的圆角半径，影响视觉风格
        static let cornerRadius: CGFloat = 4
        
        /// 选中图片时的边框宽度，用于突出显示选中状态
        static let selectedBorderWidth: CGFloat = 1
        
        /// 占位符图标的缩放比例，相对于缩略图尺寸
        static let placeholderIconScale: CGFloat = 0.3
        
        /// 占位符背景的不透明度，用于空状态显示
        static let placeholderBackgroundOpacity: CGFloat = 0.1
         
        /// 根据是否从单页返回进行延迟滚动
        static let scrollDelay: Double = 0.15
        
        /// 滚动状态清理延迟时间（秒），滚动完成后清理相关状态
        static let scrollCleanup: Double = 1

        /// 窗口大小变化检测延迟时间（秒），用于判断窗口拉伸是否完成
        static let resizeEndDelay: Double = 0.3
    }
    
    // MARK: - 滚动配置
    struct Scroll {
        /// 滚动历史最大记录数量
        static let maxHistoryCount: Int = 500

        /// 滚动动画持续时间（秒）
        static let animationDuration: Double = 0.3

        /// 预加载区域检测阈值（屏幕高度的倍数）
        static let preloadThresholdMultiplier: CGFloat = 1.5

        /// 区域定位的动画持续时间（秒）
        static let regionPositioningDuration: Double = 0.2

        /// 目标定位到区域中间时的偏移量调整
        static let targetPositionOffset: CGFloat = 0.5

        /// 滚动位置检测频率（秒）
        static let positionDetectionInterval: Double = 0.1

    }
    
    // MARK: - 分页和加载配置
    struct Pagination {
        /// 默认初始加载图片数量
        static let defaultInitialLoadCount: Int = 50
        
        /// 分页加载的每页图片数量
        static let pageSize: Int = 50
        
        /// 环境变量名称，用于覆盖默认初始加载数量
        static let initialLoadCountEnvironmentVariable = "PV_INITIAL_LOAD_COUNT"
        
        /// 最大重试尝试次数 - 控制图片定位的重试逻辑
        static let maxRetryAttempts = 3

    }
    
    // MARK: - 错误和日志消息
    struct Messages {
        /// 空状态视图的默认标题
        static let emptyStateTitle = "点击选择目录"
        
        /// 空状态视图的默认副标题
        static let emptyStateSubtitle = "支持 JPG、PNG、GIF 等常见图片格式"
        
        /// 空状态视图的默认图标
        static let emptyStateIcon = "photo.on.rectangle"
    }
    
    // MARK: - 通知名称统一管理
    struct Notifications {
        /// 文件打开请求通知
        static let fileOpenRequest = NSNotification.Name("PVApp.FileOpenRequest")
        
        /// 设置列表视图焦点通知
        static let setFocusToListView = NSNotification.Name("SetFocusToListView")
        
        /// 选择目录通知
        static let selectDirectory = NSNotification.Name("UnifiedWindowManager.selectDirectory")
        
        /// 滚动到图片通知
        static let scrollToImage = NSNotification.Name("UnifiedWindowManager.scrollToImage")
        
        /// 调整窗口大小通知
        static let adjustWindowForImage = NSNotification.Name("UnifiedWindowManager.adjustWindowForImage")
        
        /// 预加载图片区域通知
        static let preloadImageRegion = NSNotification.Name("ListView.preloadImageRegion")
    }
}