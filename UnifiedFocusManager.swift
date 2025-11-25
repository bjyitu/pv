import SwiftUI
import AppKit

/// UnifiedFocusManager常量定义
struct UnifiedFocusManagerConstants {
    /// 键盘事件相关常量
    struct KeyEvents {
        /// 空格键键码 - 播放/暂停
        static let spaceKeyCode: UInt16 = 49
        /// 回车键键码 - 返回列表视图
        static let returnKeyCode: UInt16 = 36
        /// 上箭头键码 - 上一张图片
        static let upArrowKeyCode: UInt16 = 126
        /// 下箭头键码 - 下一张图片
        static let downArrowKeyCode: UInt16 = 125
        /// 右箭头键码 - 下一张图片
        static let rightArrowKeyCode: UInt16 = 124
        /// 左箭头键码 - 上一张图片
        static let leftArrowKeyCode: UInt16 = 123
        
        /// 回车键字符 - 进入单张浏览模式
        static let returnCharacter = "\r"
        /// 上箭头Unicode字符
        static let upArrowCharacter = "\u{F700}"
        /// 下箭头Unicode字符
        static let downArrowCharacter = "\u{F701}"
        /// 左箭头Unicode字符
        static let leftArrowCharacter = "\u{F703}"
        /// 右箭头Unicode字符
        static let rightArrowCharacter = "\u{F702}"
        /// 减号键字符 - 缩小缩略图
        static let minusCharacter = "-"
        /// 等号键字符 - 放大缩略图
        static let equalsCharacter = "="
    }
    
    /// 滚动事件相关常量
    struct ScrollEvents {
        /// 滚轮灵敏度阈值
        static let wheelSensitivity: CGFloat = 0.5
    }
    
    /// 延迟时间相关常量
    struct Delays {
        /// 设置焦点通知延迟时间（秒）
        static let setFocusDelay: Double = 0.1
    }
    
    /// 焦点管理相关方法
    struct FocusMethods {
        /// 安全设置第一响应者
        /// - Parameters:
        ///   - view: 要设置焦点的视图
        ///   - checkCurrentResponder: 是否检查当前响应者状态，默认为true（推荐）
        static func safeSetFirstResponder(_ view: NSView, checkCurrentResponder: Bool = true) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Delays.setFocusDelay) {
                if checkCurrentResponder {
                    // 带检查的版本：只有当视图不是当前第一响应者时才设置
                    if view.acceptsFirstResponder && view.window?.firstResponder != view {
                    view.window?.makeFirstResponder(view)
                }
                } else {
                    // 无检查的版本：直接设置第一响应者
                    view.window?.makeFirstResponder(view)
                }
            }
        }
        
        // 为向后兼容性保留的便捷方法
        
        /// 安全设置第一响应者（无检查）
        /// - Parameter view: 要设置焦点的视图
        static func safeSetFirstResponder(_ view: NSView) {
            safeSetFirstResponder(view, checkCurrentResponder: false)
        }
        
        /// 安全设置第一响应者（带检查）
        /// - Parameter view: 要设置焦点的视图
        static func safeSetFirstResponderWithCheck(_ view: NSView) {
            safeSetFirstResponder(view, checkCurrentResponder: true)
        }
    }
    
    /// 通知名称常量
    struct Notifications {
        /// 设置焦点到列表视图的通知名称
        static let setFocusToListView = "SetFocusToListView"
    }
}

enum ViewMode {
    case list
    case single
}

class UnifiedFocusView: NSView {
    weak var viewModel: ImageBrowserViewModel?
    
    init() {
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        let result = super.becomeFirstResponder()
        return result
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        
        UnifiedFocusManagerConstants.FocusMethods.safeSetFirstResponderWithCheck(self)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSetFocusNotification),
            name: NSNotification.Name(UnifiedFocusManagerConstants.Notifications.setFocusToListView),
            object: nil
        )
    }
    
    @objc private func handleSetFocusNotification() {
        guard let viewModel = viewModel, !viewModel.isSingleViewMode else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + UnifiedFocusManagerConstants.Delays.setFocusDelay) {
            UnifiedFocusManagerConstants.FocusMethods.safeSetFirstResponderWithCheck(self)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func keyDown(with event: NSEvent) {
        
        guard let viewModel = viewModel else {
            super.keyDown(with: event)
            return
        }
        
        if viewModel.isSingleViewMode {
            handleSingleViewKeyEvents(event: event, viewModel: viewModel)
        } else {
            handleListViewKeyEvents(event: event, viewModel: viewModel)
        }
    }
    
    private func handleSingleViewKeyEvents(event: NSEvent, viewModel: ImageBrowserViewModel) {
        guard viewModel.isSingleViewMode else { 
            super.keyDown(with: event)
            return
        }
        
        let keyCode = event.keyCode
        
        switch keyCode {
        case UnifiedFocusManagerConstants.KeyEvents.spaceKeyCode:  // 空格键 - 播放/暂停
            viewModel.toggleAutoPlay()
        case UnifiedFocusManagerConstants.KeyEvents.returnKeyCode:  // 回车键 - 返回列表视图
            returnToListView(viewModel: viewModel)
        case UnifiedFocusManagerConstants.KeyEvents.upArrowKeyCode:  // 上箭头 - 上一张图片
            break
        case UnifiedFocusManagerConstants.KeyEvents.downArrowKeyCode:  // 下箭头 - 下一张图片
            break
        case UnifiedFocusManagerConstants.KeyEvents.rightArrowKeyCode:  // 右箭头 - 下一张图片
            viewModel.stopAutoPlay()
            viewModel.nextImage()
        case UnifiedFocusManagerConstants.KeyEvents.leftArrowKeyCode:  // 左箭头 - 上一张图片
            viewModel.stopAutoPlay()
            viewModel.previousImage()
        default:
            super.keyDown(with: event)
        }
    }
    
    private func handleListViewKeyEvents(event: NSEvent, viewModel: ImageBrowserViewModel) {
        guard let characters = event.charactersIgnoringModifiers else { 
            super.keyDown(with: event)
            return
        }
        
        guard !viewModel.isSingleViewMode else { 
            super.keyDown(with: event)
            return
        }
        
        switch characters {
        case UnifiedFocusManagerConstants.KeyEvents.returnCharacter:  // 回车键 - 进入单张浏览模式
            if !viewModel.selectedImages.isEmpty {
                if let firstSelectedId = viewModel.selectedImages.first,
                   let index = viewModel.images.firstIndex(where: { $0.id == firstSelectedId }) {
                    viewModel.selectImage(at: index)
                }
            } else if !viewModel.images.isEmpty {
                viewModel.selectImage(at: viewModel.currentImageIndex)
            }
        case UnifiedFocusManagerConstants.KeyEvents.upArrowCharacter:  // 上箭头
            viewModel.navigateSelection(direction: .right)  // 右箭头向右选择
        case UnifiedFocusManagerConstants.KeyEvents.downArrowCharacter:  // 下箭头
            viewModel.navigateSelection(direction: .left)  // 左箭头向左选择
        case UnifiedFocusManagerConstants.KeyEvents.leftArrowCharacter:  // 左箭头
            break
        case UnifiedFocusManagerConstants.KeyEvents.rightArrowCharacter:  // 右箭头
            break
        case UnifiedFocusManagerConstants.KeyEvents.minusCharacter:  // 减号键 - 缩小缩略图
            viewModel.handleKeyPress(UnifiedFocusManagerConstants.KeyEvents.minusCharacter)
        case UnifiedFocusManagerConstants.KeyEvents.equalsCharacter:  // 等号键 - 放大缩略图
            viewModel.handleKeyPress(UnifiedFocusManagerConstants.KeyEvents.equalsCharacter)
        default:
            super.keyDown(with: event)
        }
    }
    
    override func scrollWheel(with event: NSEvent) {
        guard let viewModel = viewModel else { 
            super.scrollWheel(with: event)
            return 
        }
        
        // 列表模式下检测滚轮，触发用户滚动检测
        if !viewModel.isSingleViewMode {
            UnifiedWindowManager.shared.handleUserScrollRequest()
            super.scrollWheel(with: event)
            return
        }
        
        // 单张图片模式下
        guard viewModel.isSingleViewMode else { 
            super.scrollWheel(with: event)
            return 
        }
        
        guard !viewModel.isAutoPlaying else { return }
        
        let deltaY = event.scrollingDeltaY
        
        let sensitivity: CGFloat = UnifiedFocusManagerConstants.ScrollEvents.wheelSensitivity
        
        if deltaY > sensitivity {
            viewModel.previousImage()
        } else if deltaY < -sensitivity {
            viewModel.nextImage()
        }
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override func mouseDown(with event: NSEvent) {
        UnifiedFocusManagerConstants.FocusMethods.safeSetFirstResponderWithCheck(self)
        super.mouseDown(with: event)
    }
    
    private func returnToListView(viewModel: ImageBrowserViewModel) {
        viewModel.stopAutoPlay()
        
        guard viewModel.images.indices.contains(viewModel.currentImageIndex) else {
            viewModel.toggleViewMode()
            return
        }
        
        viewModel.toggleViewMode()
    }
}

struct UnifiedKeyboardListener: NSViewRepresentable {
    @ObservedObject var viewModel: ImageBrowserViewModel
    let mode: ViewMode
    
    func makeNSView(context: Context) -> NSView {
        let view = UnifiedFocusView()
        view.viewModel = viewModel
        
        view.translatesAutoresizingMaskIntoConstraints = false
        
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let superview = nsView.superview else { return }
        
        if superview.constraints.isEmpty {
            NSLayoutConstraint.activate([
                nsView.leadingAnchor.constraint(equalTo: superview.leadingAnchor),
                nsView.trailingAnchor.constraint(equalTo: superview.trailingAnchor),
                nsView.topAnchor.constraint(equalTo: superview.topAnchor),
                nsView.bottomAnchor.constraint(equalTo: superview.bottomAnchor)
            ])
        }
        
        switch mode {
        case .list:
            if !viewModel.isSingleViewMode {
            }
        case .single:
            if viewModel.isSingleViewMode {
            }
        }
    }
}