import SwiftUI

struct SettingsView: View {
    @StateObject private var appSettings = AppSettings()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("滚动设置")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.bottom, 10)
            
            // 统一的滑块设置项组件，避免重复的布局代码
            sliderSetting(
                title: "滚动速度",
                binding: $appSettings.scrollSpeed,
                range: 0.5...2.0,
                leftLabel: "慢",
                rightLabel: "快",
                valueFormat: "1.1x"
            )
            
            sliderSetting(
                title: "滚动灵敏度", 
                binding: $appSettings.scrollSensitivity,
                range: 0.5...2.0,
                leftLabel: "低",
                rightLabel: "高",
                valueFormat: "1.1x"
            )
            
            sliderSetting(
                title: "滚动动画持续时间",
                binding: $appSettings.scrollAnimationDuration,
                range: 0.1...1.0,
                leftLabel: "快",
                rightLabel: "慢", 
                valueFormat: "1.1s"
            )
            
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
    
    // 统一的滑块设置项组件，避免重复的布局代码
    @ViewBuilder
    private func sliderSetting(
        title: String,
        binding: Binding<Double>,
        range: ClosedRange<Double>,
        leftLabel: String,
        rightLabel: String,
        valueFormat: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            
            HStack {
                Text(leftLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Slider(value: binding, in: range, step: 0.1)
                    .labelsHidden()
                
                Text(rightLabel)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(binding.wrappedValue, specifier: valueFormat)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 30)
            }
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
