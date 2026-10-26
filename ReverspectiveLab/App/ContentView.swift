import SwiftUI

struct ContentView: View {
    @State private var cursorPosition: CGPoint = CGPoint(x: 150, y: 150)
    
    var body: some View {
        MetalView(cursorPosition: $cursorPosition)
            .frame(minWidth: 800, minHeight: 600)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        cursorPosition = value.location
                    }
            )
        Text("Posición: X: \(Int(cursorPosition.x)), Y: \(Int(cursorPosition.y))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
    }
}

#Preview {
    ContentView()
}
