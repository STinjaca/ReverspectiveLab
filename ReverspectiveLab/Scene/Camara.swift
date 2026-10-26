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

    /// Gira la cámara alrededor de `objetivo` sin cambiar la distancia.
    ///
    /// Pasa `posicion - objetivo` a esféricas con Y arriba (yaw alrededor de Y,
    /// pitch = elevación sobre el plano XZ), suma los incrementos y vuelve a
    /// cartesianas. El estado es la propia `posicion`, así que cada llamada
    /// parte de donde quedó la anterior.
    mutating func orbitar(yaw dYaw: Float, pitch dPitch: Float) {
        let offset = posicion - objetivo
        let radio = simd_length(offset)
        guard radio > 0 else { return }

        let yaw = atan2(offset.x, offset.z) + dYaw
        // En ±90° la dirección de vista queda paralela a `arriba` y el look-at
        // no puede armar la base (el producto cruz da cero).
        let limite = Float.pi / 2 - 0.01
        let pitch = min(max(asin(offset.y / radio) + dPitch, -limite), limite)

        posicion = objetivo + radio * SIMD3<Float>(cos(pitch) * sin(yaw),
                                                   sin(pitch),
                                                   cos(pitch) * cos(yaw))
    }
}
