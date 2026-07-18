import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            HuggingFaceListView()
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
