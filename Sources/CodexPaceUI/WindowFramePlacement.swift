import CoreGraphics

public enum WindowFramePlacement {
    public static func frameKeepingResizeVisible(
        resizedFrame: CGRect,
        previousFrame: CGRect,
        visibleFrame: CGRect,
        preservesRightEdge: Bool
    ) -> CGRect {
        var result = resizedFrame

        if result.width > visibleFrame.width {
            result.origin.x = visibleFrame.minX
        } else if preservesRightEdge || result.maxX > visibleFrame.maxX {
            result.origin.x = min(
                max(previousFrame.maxX - result.width, visibleFrame.minX),
                visibleFrame.maxX - result.width
            )
        } else if result.minX < visibleFrame.minX {
            result.origin.x = visibleFrame.minX
        }

        if result.height > visibleFrame.height {
            result.origin.y = visibleFrame.minY
        } else {
            result.origin.y = min(
                max(result.origin.y, visibleFrame.minY),
                visibleFrame.maxY - result.height
            )
        }

        return result
    }
}
