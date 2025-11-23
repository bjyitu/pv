import SwiftUI

struct SettingsView: View {
    @StateObject private var appSettings = AppSettings()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("滚动设置")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 10)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("滚动速度")
                    .font(.headline)
                
                HStack {
                    Text("慢")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $appSettings.scrollSpeed, in: 0.5...2.0, step: 0.1)
                        .labelsHidden()
                    
                    Text("快")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(appSettings.scrollSpeed, specifier: "1.1")x")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 30)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("滚动灵敏度")
                    .font(.headline)
                
                HStack {
                    Text("低")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $appSettings.scrollSensitivity, in: 0.5...2.0, step: 0.1)
                        .labelsHidden()
                    
                    Text("高")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(appSettings.scrollSensitivity, specifier: "1.1")x")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 30)
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("滚动动画持续时间")
                    .font(.headline)
                
                HStack {
                    Text("快")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $appSettings.scrollAnimationDuration, in: 0.1...1.0, step: 0.1)
                        .labelsHidden()
                    
                    Text("慢")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(appSettings.scrollAnimationDuration, specifier: "1.1")s")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 30)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Toggle("启用自动滚动", isOn: $appSettings.autoScrollEnabled)
                    .font(.body)
                
                Toggle("显示滚动指示器", isOn: $appSettings.showScrollIndicator)
                    .font(.body)
                
                Toggle("启用键盘导航", isOn: $appSettings.enableKeyboardNavigation)
                    .font(.body)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("预设配置")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Button("默认") {
                        resetToDefaults()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("快速") {
                        applyFastPreset()
                    }
                    .buttonStyle(.bordered)
                    
                    Button("平滑") {
                        applySmoothPreset()
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            Spacer()
        }
        .padding(20)
        .frame(width: 400, height: 500)
    }
    
    private func resetToDefaults() {
        appSettings.resetToDefaults()
    }
    
    private func applyFastPreset() {
        appSettings.scrollSpeed = 1.5
        appSettings.scrollSensitivity = 1.5
        appSettings.scrollAnimationDuration = 0.1
        appSettings.autoScrollEnabled = true
    }
    
    private func applySmoothPreset() {
        appSettings.scrollSpeed = 0.8
        appSettings.scrollSensitivity = 0.8
        appSettings.scrollAnimationDuration = 0.6
        appSettings.autoScrollEnabled = true
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}