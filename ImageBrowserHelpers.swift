import SwiftUI


class ImageProcessingHelper {
    static func calculateVisualWeight(_ image: ImageItem) -> CGFloat {
        let aspectRatio = image.size.width / image.size.height
        
        let area = image.size.width * image.size.height
        let normalizedArea = log(area + 1) / log(1_000_000) // 归一化到合理范围
        
        // 简化处理：根据宽高比给予不同的权重
        let typeWeight: CGFloat
        if aspectRatio > 2.0 {
            typeWeight = 1.5 // 超宽图片
        } else if aspectRatio > 1.5 {
            typeWeight = 1.2 // 宽图片
        } else if aspectRatio < 0.5 {
            typeWeight = 1.5 // 超窄图片
        } else if aspectRatio < 0.8 {
            typeWeight = 1.2 // 窄图片
        } else {
            typeWeight = 1.0 // 正常图片
        }
        
        return normalizedArea * typeWeight
    }
    
    static func calculateThumbnailSize(for imageItem: ImageItem, baseSize: CGFloat) -> CGSize {
        let originalSize = imageItem.size
        
        if originalSize.width == 0 || originalSize.height == 0 {
            return CGSize(width: baseSize, height: baseSize)
        }
        
        let aspectRatio = originalSize.width / originalSize.height
        
        if aspectRatio > 1 {
            return CGSize(width: baseSize * aspectRatio, height: baseSize)
        } else {
            return CGSize(width: baseSize * aspectRatio, height: baseSize)
        }
    }
}



class FocusManagerHelper {
    static let focusDelay: TimeInterval = 0.1
    
    static func safeSetFirstResponder(_ view: NSView) {
        DispatchQueue.main.asyncAfter(deadline: .now() + focusDelay) {
            if let window = view.window {
                window.makeFirstResponder(view)
            }
        }
    }
    
    static func safeSetFirstResponderWithCheck(_ view: NSView) {
        DispatchQueue.main.asyncAfter(deadline: .now() + focusDelay) {
            if canBecomeFirstResponder(view) {
                view.window?.makeFirstResponder(view)
            }
        }
    }
    
    static func canBecomeFirstResponder(_ view: NSView) -> Bool {
        return view.window != nil && view.acceptsFirstResponder
    }
}