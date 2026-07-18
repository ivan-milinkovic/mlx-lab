import SwiftUI

struct ContentView: View {
    
    enum Route: String, Identifiable, CaseIterable {
        case hfList = "HuggingFace List"
        var id: String { rawValue }
    }
    
    @State private var route: Route? = nil

    var body: some View {
        NavigationSplitView {
            List(Route.allCases, selection: $route) { route in
                Text(route.rawValue)
                    .tag(route)
            }
        }
        detail: {
            switch route {
            case .hfList:
                HuggingFaceListView()
            case nil:
                Text("Select a screen from the sidebar")
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
