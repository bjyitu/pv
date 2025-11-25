import SwiftUI

struct StartView: View {
    @ObservedObject var viewModel: ImageBrowserViewModel
    @State private var isTapped = false
    
    var body: some View {
        ZStack {
            // 显示内容视图或空状态视图
            if viewModel.hasContent {
                ListView(viewModel: viewModel)
                    .frame(minWidth: 400, minHeight: 400)
            } else {
                emptyStateView
                    .frame(minWidth: 400, minHeight: 400)
                    .contentShape(Rectangle())
                    .scaleEffect(isTapped ? 0.9 : 1.0)
                    .opacity(isTapped ? 0.6 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isTapped)
                    .onTapGesture {
                        // 点击开始动画
                        isTapped = true
                        
                        // 0.1秒后恢复并执行选择目录
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTapped = false
                            viewModel.selectDirectory()
                        }
                    }
            }
            
            if viewModel.isSingleViewMode {
                SingleImageView(viewModel: viewModel)
                    // .transition(.opacity)
            }
        }
        .onAppear {
            viewModel.loadInitialDirectory()
            setupNotificationObservers()
        }
    }
    
    // 空状态视图
    private var emptyStateView: some View {
        UnifiedStateViews.emptyView(icon: "photo.on.rectangle", 
                                   title: "点击选择目录", 
                                   subtitle: "支持 JPG、PNG、GIF 等常见图片格式")
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: UnifiedWindowManager.Notification.selectDirectory,
            object: nil,
            queue: .main
        ) { _ in
            viewModel.selectDirectory()
        }
    }

}
