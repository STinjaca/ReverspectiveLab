//
//  MetalView.swift
//  ReverspectiveLab
//
//  Created by Santi T on 25/10/26.
//

import SwiftUI
import MetalKit

struct MetalView: NSViewRepresentable {
    /// El estado compartido con el panel; el Renderer lo lee en cada frame.
    let estado: EstadoVisor

    // Solo sirve para mantener vivo al Renderer mientras exista la vista.
    final class Coordinator {
        var renderer: Renderer?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> VistaMetal {
        let view = VistaMetal()
        view.device = MTLCreateSystemDefaultDevice()      // 1. primero el device
        view.clearColor = MTLClearColor(red: 0.06, green: 0.07, blue: 0.09, alpha: 1)

        let renderer = Renderer(vista: view, estado: estado)              // 2. luego el Renderer, con ESTA vista
        context.coordinator.renderer = renderer           // 3. guardarlo para que no muera
        view.delegate = renderer                          // 4. conectarlo
        view.alGesto = { [weak renderer] gesto in         // 5. los gestos van a su cámara
            renderer?.aplicar(gesto)
        }
        return view
    }

    func updateNSView(_ nsView: VistaMetal, context: Context) {}
}
