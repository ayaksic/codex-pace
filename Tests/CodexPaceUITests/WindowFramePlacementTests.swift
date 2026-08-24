import CoreGraphics
import Testing
@testable import CodexPaceUI

@Test func expansionNearRightEdgeKeepsPreviousRightEdge() {
    let previousFrame = CGRect(x: 1_000, y: 400, width: 400, height: 250)
    let resizedFrame = CGRect(x: 1_000, y: 150, width: 800, height: 500)
    let visibleFrame = CGRect(x: 0, y: 0, width: 1_440, height: 900)

    let result = WindowFramePlacement.frameKeepingResizeVisible(
        resizedFrame: resizedFrame,
        previousFrame: previousFrame,
        visibleFrame: visibleFrame,
        preservesRightEdge: false
    )

    #expect(result == CGRect(x: 600, y: 150, width: 800, height: 500))
}

@Test func expansionAwayFromRightEdgeKeepsHorizontalPosition() {
    let previousFrame = CGRect(x: 100, y: 400, width: 400, height: 250)
    let resizedFrame = CGRect(x: 100, y: 150, width: 800, height: 500)
    let visibleFrame = CGRect(x: 0, y: 0, width: 1_440, height: 900)

    let result = WindowFramePlacement.frameKeepingResizeVisible(
        resizedFrame: resizedFrame,
        previousFrame: previousFrame,
        visibleFrame: visibleFrame,
        preservesRightEdge: false
    )

    #expect(result == resizedFrame)
}

@Test func expansionUsesTheSuppliedDisplayCoordinates() {
    let previousFrame = CGRect(x: 2_400, y: 300, width: 400, height: 250)
    let resizedFrame = CGRect(x: 2_400, y: -100, width: 800, height: 700)
    let visibleFrame = CGRect(x: 1_440, y: 20, width: 1_440, height: 860)

    let result = WindowFramePlacement.frameKeepingResizeVisible(
        resizedFrame: resizedFrame,
        previousFrame: previousFrame,
        visibleFrame: visibleFrame,
        preservesRightEdge: false
    )

    #expect(result == CGRect(x: 2_000, y: 20, width: 800, height: 700))
}

@Test func oversizedExpansionAlignsWithVisibleFrameOrigin() {
    let previousFrame = CGRect(x: 1_000, y: 300, width: 400, height: 250)
    let resizedFrame = CGRect(x: 1_000, y: -100, width: 1_600, height: 1_000)
    let visibleFrame = CGRect(x: 0, y: 20, width: 1_440, height: 860)

    let result = WindowFramePlacement.frameKeepingResizeVisible(
        resizedFrame: resizedFrame,
        previousFrame: previousFrame,
        visibleFrame: visibleFrame,
        preservesRightEdge: false
    )

    #expect(result == CGRect(x: 0, y: 20, width: 1_600, height: 1_000))
}

@Test func contractionKeepsPreviousRightEdge() {
    let previousFrame = CGRect(x: 600, y: 150, width: 800, height: 500)
    let resizedFrame = CGRect(x: 600, y: 400, width: 400, height: 250)
    let visibleFrame = CGRect(x: 0, y: 0, width: 1_440, height: 900)

    let result = WindowFramePlacement.frameKeepingResizeVisible(
        resizedFrame: resizedFrame,
        previousFrame: previousFrame,
        visibleFrame: visibleFrame,
        preservesRightEdge: true
    )

    #expect(result == CGRect(x: 1_000, y: 400, width: 400, height: 250))
}
