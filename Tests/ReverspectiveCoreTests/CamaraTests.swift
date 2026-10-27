//  CamaraTests.swift — pruebas de las matrices de la cámara.

import Testing
import simd
@testable import ReverspectiveCore

/// Un punto en el objetivo de la cámara cae en el centro de la imagen
/// (NDC (0, 0)). Es la propiedad mínima de `matrizVista` + `matrizProyeccion`.
@Test func objetivoCaeEnElCentro() {
    let c = Camara(posicion: [0, 0, 5], objetivo: [0, 0, 0])
    let clip = c.matrizProyeccion(aspect: 1) * c.matrizVista() * SIMD4<Float>(0, 0, 0, 1)
    let ndc = SIMD2<Float>(clip.x, clip.y) / clip.w
    #expect(abs(ndc.x) < 1e-6)
    #expect(abs(ndc.y) < 1e-6)
}
