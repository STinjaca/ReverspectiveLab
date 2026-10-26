//  VistaMetal.swift — ReverspectiveLab
//  MTKView que convierte eventos de mouse en GestoCamara.
//
//    Botón central + arrastrar   → .orbitar
//
//  DragGesture de SwiftUI no deja filtrar por botón, así que se escuchan
//  los eventos de AppKit directamente.

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
}
