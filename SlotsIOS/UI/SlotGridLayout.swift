import SwiftUI

/// Cuántas filas ocupa una card en la grilla (1 o 2).
private struct SlotRowSpan: LayoutValueKey {
    static let defaultValue = 1
}

extension View {
    func slotRowSpan(_ rows: Int) -> some View {
        layoutValue(key: SlotRowSpan.self, value: rows)
    }
}

/// Grilla de dos columnas con cards de alto variable. Cada card va a la columna más corta.
struct SlotGridLayout: Layout {
    static let rowHeight: CGFloat = 166
    var spacing: CGFloat = SlotsSpace.entreCards

    private func frames(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], height: CGFloat) {
        let columnWidth = (width - spacing) / 2
        var heights: [CGFloat] = [0, 0]
        var frames: [CGRect] = []
        for subview in subviews {
            let rows = CGFloat(subview[SlotRowSpan.self])
            let height = rows * Self.rowHeight + (rows - 1) * spacing
            let column = heights[1] < heights[0] ? 1 : 0
            let y = heights[column] == 0 ? 0 : heights[column] + spacing
            frames.append(CGRect(x: CGFloat(column) * (columnWidth + spacing), y: y, width: columnWidth, height: height))
            heights[column] = y + height
        }
        return (frames, max(heights[0], heights[1]))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        return CGSize(width: width, height: frames(width: width, subviews: subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = frames(width: bounds.width, subviews: subviews)
        for (subview, frame) in zip(subviews, layout.frames) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }
}
