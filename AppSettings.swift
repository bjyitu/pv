import SwiftUI

@MainActor
class AppSettings: ObservableObject {
    @AppStorage("scrollSpeed") public var scrollSpeed: Double = 1.0
    @AppStorage("autoScrollEnabled") public var autoScrollEnabled: Bool = true
    @AppStorage("showScrollIndicator") public var showScrollIndicator: Bool = true
    @AppStorage("scrollAnimationDuration") public var scrollAnimationDuration: Double = 0.3
    @AppStorage("scrollSensitivity") public var scrollSensitivity: Double = 1.0
    
    @AppStorage("enableKeyboardNavigation") public var enableKeyboardNavigation: Bool = true
    
    func resetToDefaults() {
        scrollSpeed = 1.0
        autoScrollEnabled = true
        showScrollIndicator = true
        scrollAnimationDuration = 0.3
        scrollSensitivity = 1.0
        enableKeyboardNavigation = true
    }
    
    func exportSettings() -> [String: Any] {
        return [
            "scrollSpeed": scrollSpeed,
            "autoScrollEnabled": autoScrollEnabled,
            "showScrollIndicator": showScrollIndicator,
            "scrollAnimationDuration": scrollAnimationDuration,
            "scrollSensitivity": scrollSensitivity,
            "enableKeyboardNavigation": enableKeyboardNavigation
        ]
    }
}