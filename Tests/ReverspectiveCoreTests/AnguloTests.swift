//  AnguloTests.swift — pruebas de P y θ.

import Testing
import simd
@testable import ReverspectiveCore

/// P está sobre el eje de C, a distancia D.
@Test func puntoPSobreElEje() {
    let p = camaraC.puntoP(distancia: 4)
    #expect(simd_distance(p, [0, 0, 1]) < 1e-6)
}

/// θ = 0 en C y sobre la misma línea, aunque cambie la distancia (zoom).
@Test func thetaCeroSobreLaLinea() {
    let p = camaraC.puntoP(distancia: 4)
    #expect(anguloTheta(c: camaraC.posicion, visor: camaraC.posicion, p: p) == 0)
    #expect(abs(anguloTheta(c: camaraC.posicion, visor: [0, 0, 9], p: p)) < 1e-4)
}

/// Orbitar 10° alrededor de P da θ = 10°, hacia cualquier lado.
@Test(arguments: [Float(10), -10, 35])
func thetaTrasOrbitar(grados: Float) {
    let p = camaraC.puntoP(distancia: 4)
    var visor = Camara(posicion: camaraC.posicion, objetivo: p)
    visor.orbitar(yaw: grados * .pi / 180, pitch: 0)
    #expect(abs(anguloTheta(c: camaraC.posicion, visor: visor.posicion, p: p) - abs(grados)) < 1e-3)
}
