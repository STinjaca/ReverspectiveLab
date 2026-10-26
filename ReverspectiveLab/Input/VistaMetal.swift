//  VistaMetal.swift — ReverspectiveLab
//  MTKView que convierte eventos de mouse y trackpad en GestoCamara.
//
//    Botón central + arrastrar   → .orbitar
//    Trackpad, dos dedos         → .orbitar
//
//  DragGesture de SwiftUI no deja filtrar por botón ni distinguir trackpad
//  de rueda, así que se escuchan los eventos de AppKit directamente.

import MetalKit

final class VistaMetal: MTKView {
    var alGesto: ((GestoCamara) -> Void)?

    // Los `otherMouse*` llegan para cualquier botón que no sea el izquierdo
    // o el derecho; el central es el 2.
    override func otherMouseDragged(with event: NSEvent) {
        guard event.buttonNumber == 2 else { return }
        // deltaX/deltaY ya son el cambio desde el evento anterior, Y hacia abajo.
        alGesto?(.orbitar(dx: event.deltaX, dy: event.deltaY))
    }

    override func scrollWheel(with event: NSEvent) {
        // Trackpad (y Magic Mouse): deltas continuos en puntos.
        // La rueda clásica da saltos por línea y queda libre para el zoom.
        guard event.hasPreciseScrollingDeltas else { return }
        // Ignorar la inercia que sigue al levantar los dedos: la cámara
        // se detiene cuando se detiene la mano.
        guard event.momentumPhase.isEmpty else { return }
        alGesto?(.orbitar(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY))
    }
}
