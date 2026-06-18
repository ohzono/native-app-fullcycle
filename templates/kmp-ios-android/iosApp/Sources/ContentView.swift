import SwiftUI
import Shared

struct ContentView: View {
    var body: some View {
        Text(Greeting().greet())
            .font(.title)
            .padding()
    }
}

#Preview {
    ContentView()
}
