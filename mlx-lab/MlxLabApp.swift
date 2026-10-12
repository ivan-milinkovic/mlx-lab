import SwiftUI

@main
struct MlxLabApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(AppModel.shared)
        }
    }
}
