//
//  MatrixMath.swift
//  ReverspectiveLab
//
//  Created by Santi T on 8/09/26.
//

import simd


/// Matriz de proyección en perspectiva (view space → clip space).
///
/// Implementa `clip = P · v_view` — la matriz P del pipeline de transformación.
/// Usa la convención de Metal para NDC, donde `z` queda mapeado a `[0, 1]`
/// (no `[-1, 1]` como en OpenGL/el artefacto de proyección en HTML). El principio
/// es el mismo en ambas convenciones: la GPU divide por `w` después de este paso,
/// y esa división homogénea es lo que produce la perspectiva.
///
/// - Parameters:
///   - fovYRadians: Ángulo de apertura vertical de la cámara, en radianes.
///     `.pi / 3` ≈ 60°.
///   - aspect: Relación de aspecto del viewport (`width / height`).
///   - near: Distancia al near plane. Vértices más cerca que esto se recortan.
///   - far: Distancia al far plane. Vértices más lejos que esto se recortan.
/// - Returns: Matriz de proyección en perspectiva, lista para multiplicar
///   por la matriz de vista (`P · V · M · v`).
func matrix4x4Perspective(fovYRadians: Float, aspect: Float, near: Float, far: Float) -> simd_float4x4 {
    let yScale = 1 / tan(fovYRadians * 0.5)
    let xScale = yScale / aspect
    let zRange = near - far
    let zScale = far / zRange
    let wzScale = near * far / zRange

    return simd_float4x4(columns: (
        SIMD4<Float>(xScale, 0, 0, 0),
        SIMD4<Float>(0, yScale, 0, 0),
        SIMD4<Float>(0, 0, zScale, -1),
        SIMD4<Float>(0, 0, wzScale, 0)
    ))
}

/// Matriz de vista (world space → view space): posiciona y orienta la cámara.
///
/// Construye una base ortonormal (`x`, `y`, `z`) centrada en `eye` y apuntando
/// hacia `center`, luego traduce el mundo al espacio de esa cámara. Es la matriz
/// `V` del pipeline — se aplica antes que la proyección: `clip = P · V · v_world`.
///
/// - Parameters:
///   - eye: Posición de la cámara en world space.
///   - center: Punto hacia el que mira la cámara.
///   - up: Vector "arriba" de referencia (normalmente `[0, 1, 0]`), usado para
///     resolver la orientación de la base — no necesita ser perpendicular a
///     `eye - center`, se re-ortogonaliza internamente vía producto cruz.
/// - Returns: Matriz de vista, lista para multiplicar por la de proyección.
func matrix4x4LookAt(eye: SIMD3<Float>, center: SIMD3<Float>, up: SIMD3<Float>) -> simd_float4x4 {
    let z = simd_normalize(eye - center)
    let x = simd_normalize(simd_cross(up, z))
    let y = simd_cross(z, x)
    let t = SIMD3<Float>(-simd_dot(x, eye), -simd_dot(y, eye), -simd_dot(z, eye))

    return simd_float4x4(columns: (
        SIMD4<Float>(x.x, y.x, z.x, 0),
        SIMD4<Float>(x.y, y.y, z.y, 0),
        SIMD4<Float>(x.z, y.z, z.z, 0),
        SIMD4<Float>(t.x, t.y, t.z, 1)
    ))
}
