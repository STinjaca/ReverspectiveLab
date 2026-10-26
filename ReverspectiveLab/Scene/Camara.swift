//  Camara.swift — ReverspectiveLab
//  Cámara de mira (look-at) con proyección en perspectiva.
//
//  Hay dos instancias con propósitos distintos:
//    - Cámara C (Escena.camaraC): fija, toma las fotos de 256×256 (aspecto 1).
//    - Cámara del visor (Renderer.camaraVisor): se mueve, usa el aspecto de la ventana.

import simd

struct Camara {
    var posicion: SIMD3<Float>
    var objetivo: SIMD3<Float>
    var arriba = SIMD3<Float>(0, 1, 0)
    var fovGrados: Float = 45   // apertura vertical
    var cerca: Float = 0.1
    var lejos: Float = 20

    func matrizVista() -> simd_float4x4 {
        matrix4x4LookAt(eye: posicion, center: objetivo, up: arriba)
    }

    func matrizProyeccion(aspect: Float) -> simd_float4x4 {
        matrix4x4Perspective(fovYRadians: fovGrados * .pi / 180,
                             aspect: aspect, near: cerca, far: lejos)
    }
}
