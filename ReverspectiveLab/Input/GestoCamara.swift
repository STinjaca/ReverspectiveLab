//  GestoCamara.swift — ReverspectiveLab
//  Lo que el usuario quiere hacerle a la cámara, sin importar con qué
//  dispositivo lo pidió. VistaMetal traduce eventos a gestos; el Renderer
//  traduce gestos a la cámara.

import CoreGraphics

enum GestoCamara {
    /// Girar alrededor del objetivo. En puntos de pantalla, con Y hacia abajo
    /// (arrastrar hacia la derecha = dx positivo).
    case orbitar(dx: CGFloat, dy: CGFloat)

    /// Acercar (> 0) o alejar (< 0). Misma unidad que `NSEvent.magnification`:
    /// 0.1 ≈ acercar un 10 %.
    case zoom(magnificacion: CGFloat)
}
