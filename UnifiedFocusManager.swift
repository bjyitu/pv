import SwiftUI
import AppKit

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
        
        FocusManagerHelper.safeSetFirstResponderWithCheck(self)
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSetFocusNotification),
            name: NSNotification.Name("SetFocusToListView"),
            object: nil
        )
    }
    
    @objc private func handleSetFocusNotification() {
        guard let viewModel = viewModel, !viewModel.isSingleViewMode else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            FocusManagerHelper.safeSetFirstResponderWithCheck(self)
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
        case 49:  // 空格键 - 播放/暂停
            viewModel.toggleAutoPlay()
        case 36:  // 回车键 - 返回列表视图
            returnToListView(viewModel: viewModel)
        case 126:  // 上箭头 - 上一张图片
            break
        case 125:  // 下箭头 - 下一张图片
            break
        case 124:  // 右箭头 - 下一张图片
            viewModel.stopAutoPlay()
            viewModel.nextImage()
        case 123:  // 左箭头 - 上一张图片
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
        case "\r":  // 回车键 - 进入单张浏览模式
            if !viewModel.selectedImages.isEmpty {
                if let firstSelectedId = viewModel.selectedImages.first,
                   let index = viewModel.images.firstIndex(where: { $0.id == firstSelectedId }) {
                    viewModel.selectImage(at: index)
                }
            } else if !viewModel.images.isEmpty {
                viewModel.selectImage(at: viewModel.currentImageIndex)
            }
        case "\u{F700}":  // 上箭头
            viewModel.navigateSelection(direction: .right)  // 右箭头向右选择
        case "\u{F701}":  // 下箭头
            viewModel.navigateSelection(direction: .left)  // 左箭头向左选择
        case "\u{F703}":  // 左箭头
            break
        case "\u{F702}":  // 右箭头
            break
        case "-":  // 减号键 - 缩小缩略图
            viewModel.handleKeyPress("-")
        case "=":  // 等号键 - 放大缩略图
            viewModel.handleKeyPress("=")
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
        
        let sensitivity: CGFloat = 0.5
        
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
        FocusManagerHelper.safeSetFirstResponderWithCheck(self)
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