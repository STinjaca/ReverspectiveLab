import SwiftUI

struct ContentView: View {
    var body: some View {
        MetalView()
            .frame(minWidth: 800, minHeight: 600)
            .overlay(alignment: .bottomLeading) { etiquetasMiniaturas }
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
