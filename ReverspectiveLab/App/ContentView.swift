import SwiftUI

struct ContentView: View {
    /// `@State` hace que el estado viva lo mismo que la ventana, y no se
    /// cree de nuevo cada vez que SwiftUI recalcula `body`.
    @State private var estado = EstadoVisor()

    var body: some View {
        HStack(spacing: 0) {
            MetalView(estado: estado)
                .frame(minWidth: 800, minHeight: 600)
                .overlay(alignment: .bottomLeading) { etiquetasMiniaturas }
            Divider()
            PanelControl(estado: estado)
                .frame(width: 280)
        }
    }

    /// Los nombres de las miniaturas, encima de cada una. Las miniaturas las
    /// dibuja Metal; el texto es más fácil en SwiftUI. Las dos partes usan las
    /// mismas medidas en puntos (`Miniaturas.lado`, …) para quedar alineadas.
    private var etiquetasMiniaturas: some View {
        HStack(alignment: .top, spacing: Miniaturas.separacion) {
            ForEach(Miniaturas.nombres, id: \.self) { nombre in
                Text(nombre)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.6), in: .rect(cornerRadius: 4))
                    .padding(4)
                    .frame(width: Miniaturas.lado, height: Miniaturas.lado, alignment: .topLeading)
            }
        }
        .padding(Miniaturas.margen)
        .allowsHitTesting(false)    // que los gestos sigan llegando a la vista Metal
    }
}

#Preview {
    ContentView()
}
