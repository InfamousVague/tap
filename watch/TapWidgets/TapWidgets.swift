import WidgetKit
import SwiftUI

@main
struct TapWidgetBundle: WidgetBundle {
    var body: some Widget {
        ServerStatusWidget()
        FleetMetricsWidget()
        DockerWidget()
        UptimeWidget()
        QuickCommandWidget()
    }
}
