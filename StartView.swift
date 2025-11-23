import SwiftUI

struct StartView: View {
    @ObservedObject var viewModel: ImageBrowserViewModel
    
    var body: some View {
        ZStack {
            ListView(viewModel: viewModel)
                .frame(minWidth: 400, minHeight: 400)
                .onAppear {
                    viewModel.loadInitialDirectory()
                    setupNotificationObservers()
                }
                .onTapGesture {
                    if viewModel.images.isEmpty {
                        NotificationCenter.default.post(name: UnifiedWindowManager.Notification.selectDirectory, object: nil)
                    }
                }
            
            if viewModel.isSingleViewMode {
                SingleImageView(viewModel: viewModel)
                    // .transition(.opacity)
            }
        }
    }
    
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: UnifiedWindowManager.Notification.selectDirectory,
            object: nil,
            queue: .main
        ) { _ in
            self.selectDirectory()
        }
    }
    
    private func selectDirectory() {
        viewModel.selectDirectory()
    }
}