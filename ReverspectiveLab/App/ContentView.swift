import SwiftUI

struct ContentView: View {
    // Arrastre total desde que abrió la app. `DragGesture` solo da el
    // desplazamiento del gesto actual, así que hay que sumarlo a lo que ya
    // se había arrastrado antes; si no, cada gesto nuevo arranca desde cero.
    @State private var arrastre: CGSize = .zero
    @State private var arrastreAnterior: CGSize = .zero

    var body: some View {
        VStack {
            MetalView(arrastre: $arrastre)
                .frame(minWidth: 800, minHeight: 600)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            arrastre = CGSize(
                                width: arrastreAnterior.width + value.translation.width,
                                height: arrastreAnterior.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            arrastreAnterior = arrastre
                        }
                )
            Text("Arrastre: X: \(Int(arrastre.width)), Y: \(Int(arrastre.height))")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
        }
    }
}

#Preview {
    ContentView()
}
