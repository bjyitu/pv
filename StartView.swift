import SwiftUI

struct StartView: View {
    @ObservedObject var viewModel: ImageBrowserViewModel
    @State private var isTapped = false
    
    var body: some View {
        Group {
            // 显示内容视图或空状态视图
            if viewModel.hasContent {
                ListView(viewModel: viewModel)
                    .frame(minWidth: 400, minHeight: 400)
            } else {
                emptyStateView
                    .frame(minWidth: 400, minHeight: 400)
                    .contentShape(Rectangle())
                    .scaleEffect(isTapped ? 0.9 : 1.0)
                    .animation(.linear(duration: 0.1), value: isTapped)
                    .onTapGesture {
                        // 点击开始动画
                        isTapped = true
                        
                        // 0.1秒后恢复并执行选择目录,模拟onrelease效果
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isTapped = false
                            viewModel.dataManager.selectDirectory()
                        }
                    }
            }
        }
        .overlay {
            if viewModel.isSingleViewMode {
                SingleImageView(viewModel: viewModel)
            }
        }
        .onAppear {
            setupNotificationObservers()
        }
    }
    
    // 空状态视图
    private var emptyStateView: some View {
        UnifiedStateViews.emptyView(icon: AppConstants.Messages.emptyStateIcon, 
                                   title: AppConstants.Messages.emptyStateTitle, 
                                   subtitle: AppConstants.Messages.emptyStateSubtitle)
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: AppConstants.Notifications.selectDirectory,
            object: nil,
            queue: .main
        ) { _ in
            viewModel.dataManager.selectDirectory()
        }
    }

}