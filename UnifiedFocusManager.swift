import SwiftUI
import AppKit

/// UnifiedFocusManager常量定义
struct UnifiedFocusManagerConstants {
    /// 按键定义
    struct Key {
        let keyCode: UInt16
        let character: String
        let description: String
    }
    
    /// 键盘事件相关常量
    struct KeyEvents {
        /// 空格键 - 播放/暂停
        static let space = Key(keyCode: 49, character: " ", description: "播放/暂停")
        /// 回车键 - 返回列表视图/进入单张浏览模式
        static let `return` = Key(keyCode: 36, character: "\r", description: "返回列表视图/进入单张浏览模式")
        /// 上箭头 - 上一张图片
        static let upArrow = Key(keyCode: 126, character: "\u{F700}", description: " ")
        /// 下箭头 - 在Finder中显示
        static let downArrow = Key(keyCode: 125, character: "\u{F701}", description: "在Finder中显示")
        /// 右箭头 - 下一张图片
        static let rightArrow = Key(keyCode: 124, character: "\u{F702}", description: "下一张图片")
        /// 左箭头 - 上一张图片
        static let leftArrow = Key(keyCode: 123, character: "\u{F703}", description: "上一张图片")
        /// 删除键 - 删除选中图片
        static let delete = Key(keyCode: 51, character: "\u{007F}", description: "删除选中图片")
        /// 减号键 - 缩小缩略图
        static let minus = Key(keyCode: 27, character: "-", description: "缩小缩略图")
        /// 等号键 - 放大缩略图
        static let equals = Key(keyCode: 24, character: "=", description: "放大缩略图")
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
        /// - Parameter view: 要设置焦点的视图
        static func safeSetFirstResponder(_ view: NSView) {
            DispatchQueue.main.asyncAfter(deadline: .now() + Delays.setFocusDelay) {
                if view.acceptsFirstResponder && view.window?.firstResponder != view {
                    view.window?.makeFirstResponder(view)
                }
            }
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
        
        UnifiedFocusManagerConstants.FocusMethods.safeSetFirstResponder(self)
        
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
            UnifiedFocusManagerConstants.FocusMethods.safeSetFirstResponder(self)
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
            // 列表模式
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
        case UnifiedFocusManagerConstants.KeyEvents.space.keyCode:  // 空格键 - 播放/暂停
            viewModel.toggleAutoPlay()
        case UnifiedFocusManagerConstants.KeyEvents.return.keyCode:  // 回车键 - 返回列表视图
            returnToListView(viewModel: viewModel)
        case UnifiedFocusManagerConstants.KeyEvents.upArrow.keyCode:  // 上箭头 
            break
        case UnifiedFocusManagerConstants.KeyEvents.downArrow.keyCode:  // 下箭头 - 在Finder中显示
            viewModel.stopAutoPlay()
            print("Single view down arrow: currentImageIndex = \(viewModel.currentImageIndex)")
            viewModel.revealInFinder(at: viewModel.currentImageIndex)
        case UnifiedFocusManagerConstants.KeyEvents.rightArrow.keyCode:  // 右箭头 - 下一张图片
            viewModel.stopAutoPlay()
            viewModel.nextImage()
        case UnifiedFocusManagerConstants.KeyEvents.leftArrow.keyCode:  // 左箭头 - 上一张图片
            viewModel.stopAutoPlay()
            viewModel.previousImage()
        case UnifiedFocusManagerConstants.KeyEvents.delete.keyCode:  // 删除键 - 删除当前图片
            viewModel.stopAutoPlay()
            viewModel.deleteImage(at: viewModel.currentImageIndex)
        default:
            super.keyDown(with: event)
        }
    }
    
    private func handleDeleteKeyEvent(event: NSEvent, viewModel: ImageBrowserViewModel) {
        // 检查是否有选中的图片
        if !viewModel.selectedImages.isEmpty {
            // 获取所有选中图片的索引（按降序排列，避免删除时索引变化）
            let selectedIndices = viewModel.selectedImages.compactMap { selectedId in
                viewModel.images.firstIndex { $0.id == selectedId }
            }.sorted(by: >) // 降序排列，从后往前删除
            
            // 删除所有选中的图片
            for index in selectedIndices {
                viewModel.deleteImage(at: index)
            }
        } else if !viewModel.images.isEmpty {
            // 如果没有选中的图片，删除当前图片
            viewModel.deleteImage(at: viewModel.currentImageIndex)
        }
    }
    
    private func handleRevealInFinderKeyEvent(event: NSEvent, viewModel: ImageBrowserViewModel) {
        // 检查是否有选中的图片
        if !viewModel.selectedImages.isEmpty {
            // 如果有选中的图片，在Finder中显示第一个选中的图片
            if let firstSelectedId = viewModel.selectedImages.first,
               let index = viewModel.images.firstIndex(where: { $0.id == firstSelectedId }) {
                viewModel.revealInFinder(at: index)
            }
        } else if !viewModel.images.isEmpty {
            // 如果没有选中的图片，在Finder中显示当前图片
            viewModel.revealInFinder(at: viewModel.currentImageIndex)
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
        case UnifiedFocusManagerConstants.KeyEvents.return.character:  // 回车键 - 进入单张浏览模式
            if !viewModel.selectedImages.isEmpty {
                if let firstSelectedId = viewModel.selectedImages.first,
                   let index = viewModel.images.firstIndex(where: { $0.id == firstSelectedId }) {
                    viewModel.selectImage(at: index)
                }
            } else if !viewModel.images.isEmpty {
                viewModel.selectImage(at: viewModel.currentImageIndex)
            }
        case UnifiedFocusManagerConstants.KeyEvents.upArrow.character:  // 上箭头
            break
        case UnifiedFocusManagerConstants.KeyEvents.downArrow.character:  // 下箭头 - 在Finder中显示
            handleRevealInFinderKeyEvent(event: event, viewModel: viewModel)
        case UnifiedFocusManagerConstants.KeyEvents.leftArrow.character:  // 左箭头
            viewModel.navigateSelection(direction: .left)  // 左箭头向左选择
        case UnifiedFocusManagerConstants.KeyEvents.rightArrow.character:  // 右箭头
            viewModel.navigateSelection(direction: .right)  // 右箭头向右选择
        case UnifiedFocusManagerConstants.KeyEvents.minus.character:  // 减号键 - 缩小缩略图
            viewModel.handleKeyPress(UnifiedFocusManagerConstants.KeyEvents.minus.character)
        case UnifiedFocusManagerConstants.KeyEvents.equals.character:  // 等号键 - 放大缩略图
            viewModel.handleKeyPress(UnifiedFocusManagerConstants.KeyEvents.equals.character)
        case UnifiedFocusManagerConstants.KeyEvents.delete.character:  // 删除键 - 删除选中图片
            handleDeleteKeyEvent(event: event, viewModel: viewModel)
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
        UnifiedFocusManagerConstants.FocusMethods.safeSetFirstResponder(self)
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
        
    }
}