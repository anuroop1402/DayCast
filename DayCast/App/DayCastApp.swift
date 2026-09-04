import SwiftUI

@main
struct DayCastApp: App {

    /// Built once and held for the app's lifetime. Nothing below this line constructs a
    /// concrete repository or client — see `DependencyContainer`.
    @State private var container = DependencyContainer()

    var body: some Scene {
        WindowGroup {
            CitySearchScreen(container: container)
        }
    }
}
