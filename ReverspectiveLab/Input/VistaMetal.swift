//  VistaMetal.swift — ReverspectiveLab
//  MTKView que convierte eventos de mouse y trackpad en GestoCamara.
//
//    Botón central + arrastrar   → .orbitar
//    Trackpad, dos dedos         → .orbitar
//    Rueda del mouse             → .zoom
//    Trackpad, pellizco          → .zoom
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
        // La rueda clásica da saltos por línea.
        guard event.hasPreciseScrollingDeltas else {
            // Con "desplazamiento natural" macOS invierte el signo; se deshace
            // para que girar la rueda hacia adelante siempre acerque.
            let lineas = event.isDirectionInvertedFromDevice ? -event.scrollingDeltaY
                                                             : event.scrollingDeltaY
            let magnificacionPorLinea: CGFloat = 0.1
            alGesto?(.zoom(magnificacion: lineas * magnificacionPorLinea))
            return
        }
        // Ignorar la inercia que sigue al levantar los dedos: la cámara
        // se detiene cuando se detiene la mano.
        guard event.momentumPhase.isEmpty else { return }
        alGesto?(.orbitar(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY))
    }

    override func magnify(with event: NSEvent) {
        // Separar los dedos da magnificación positiva: acercar.
        alGesto?(.zoom(magnificacion: event.magnification))
    }
}
