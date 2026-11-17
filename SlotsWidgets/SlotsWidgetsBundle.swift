import SwiftUI
import WidgetKit

@main
struct SlotsWidgetsBundle: WidgetBundle {
    var body: some Widget {
        OpenSlotsControl()
        CopySlotControl()
        SlotsWidget()
    }
}
