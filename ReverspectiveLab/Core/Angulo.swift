//  Angulo.swift — ReverspectiveLab
//  Cuánto se movió el observador respecto a C, visto desde la pieza.
//  Es la variable de la pregunta de investigación: a qué θ se rompe la
//  ilusión.

import simd

extension Camara {

    /// El punto P alrededor del cual se mide θ y se orbita: el punto sobre
    /// el eje de la cámara a distancia D (el pivote global).
    ///
    /// Es "el centro de la pieza" visto desde C: orbitar alrededor de P es
    /// caminar alrededor de la pieza. Orbitar alrededor del origen haría que
    /// la pieza "se escapara" del centro de la pantalla.
    func puntoP(distancia D: Float) -> SIMD3<Float> {
        posicion + simd_normalize(objetivo - posicion) * D
    }
}

/// θ en grados: el ángulo entre (C − P) y (visor − P).
///
/// 0° cuando el visor está sobre la línea de C (aunque más cerca o más
/// lejos); crece a medida que el visor se aparta hacia cualquier lado.
/// Usa `atan2(|a × b|, a · b)` en vez de `acos` del producto punto
/// normalizado: cerca de 0°, `acos` pierde precisión y por redondeo
/// puede recibir algo mayor que 1 (y dar NaN).
func anguloTheta(c: SIMD3<Float>, visor: SIMD3<Float>, p: SIMD3<Float>) -> Float {
    let a = c - p, b = visor - p
    let radianes = atan2(simd_length(simd_cross(a, b)), simd_dot(a, b))
    return radianes * 180 / .pi
}
