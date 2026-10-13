import SwiftUI

/// The notch silhouette: flat along the top edge of the screen, with "ears"
/// curving outwards where it meets the menu bar, and rounded bottom corners.
/// Both radii animate, so the shape morphs smoothly between presentations.
struct NotchShape: Shape {
    var earRadius: CGFloat
    var bottomRadius: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(earRadius, bottomRadius) }
        set {
            earRadius = newValue.first
            bottomRadius = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let ear = min(earRadius, rect.width / 4)
        let bottom = min(bottomRadius, (rect.width - ear * 2) / 2, rect.height - ear)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // Left ear.
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + ear, y: rect.minY + ear),
            control: CGPoint(x: rect.minX + ear, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + ear, y: rect.maxY - bottom))
        // Bottom-left corner.
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + ear + bottom, y: rect.maxY),
            control: CGPoint(x: rect.minX + ear, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - ear - bottom, y: rect.maxY))
        // Bottom-right corner.
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - ear, y: rect.maxY - bottom),
            control: CGPoint(x: rect.maxX - ear, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - ear, y: rect.minY + ear))
        // Right ear.
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.maxX - ear, y: rect.minY)
        )
        path.closeSubpath()
        return path
    }
}
