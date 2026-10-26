//
//  MetalView.swift.swift
//  ReverspectiveLab
//
//  Created by Santi T on 25/10/26.
//

import SwiftUI
import MetalKit

struct MetalView: NSViewRepresentable {
    
    @Binding var arrastre: CGSize
    

    // Solo sirve para mantener vivo al Renderer mientras exista la vista.
    final class Coordinator {
        var renderer: Renderer?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView()
        view.device = MTLCreateSystemDefaultDevice()      // 1. primero el device
        view.clearColor = MTLClearColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1)

        let renderer = Renderer(vista: view)              // 2. luego el Renderer, con ESTA vista
        context.coordinator.renderer = renderer           // 3. guardarlo para que no muera
        view.delegate = renderer                          // 4. conectarlo
        return view
    }

    func updateNSView(_ nsView: MTKView, context: Context) {
        context.coordinator.renderer?.arrastre = arrastre
    }
}


// 1. Fuente de verdad: Almacena la posición actual del cursor
//
//        var body: some View {
//            VStack {
//                Text("Mueve el dedo o cursor sobre el lienzo")
//                    .font(.headline)
//                    .padding()
//
//                // 2. El lienzo de dibujo
//                Canvas { context, size in
//                    // Dibujar el fondo del canvas
//                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.gray.opacity(0.1)))
//
//                    // 3. Dibujar el indicador del cursor basado en el estado
//                    let cursorSize: CGFloat = 20
//                    let cursorRect = CGRect(
//                        x: cursorPosition.x - cursorSize / 2,
//                        y: cursorPosition.y - cursorSize / 2,
//                        width: cursorSize,
//                        height: cursorSize
//                    )
//
//                    // Renderiza un círculo naranja en la posición del cursor
//                    context.fill(Path(ellipseIn: cursorRect), with: .color(.orange))
//                }
//                .frame(width: 300, height: 300)
//                .cornerRadius(12)
//                // 4. Reconocedor de gestos para actualizar el estado continuamente
//                .gesture(
//                    DragGesture(minimumDistance: 0)
//                        .onChanged { value in
//                            // Actualiza la posición con las coordenadas del evento
//                            cursorPosition = value.location
//                        }
//                )
//
//                // Mostrar coordenadas en tiempo real
//                Text("Posición: X: \(Int(cursorPosition.x)), Y: \(Int(cursorPosition.y))")
//                    .font(.caption)
//                    .foregroundColor(.secondary)
//                    .padding()
//            }
//        }
