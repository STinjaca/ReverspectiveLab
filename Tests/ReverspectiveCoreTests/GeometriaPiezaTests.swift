//  GeometriaPiezaTests.swift — pruebas de las posiciones de la pieza.

import Testing
import simd
@testable import ReverspectiveCore

/// Fotos de 2×2 inventadas: fondo arriba a la izquierda, esfera (1) en dos
/// píxeles y piso (3) en uno.
let distancias2x2: [Float] = [0, 3, 5, 4]
let ids2x2: [UInt16]       = [0, 1, 3, 1]

@Test func posicionesSobreSuRayo() {
    let rayos = camaraC.rayos(n: 2)
    let pivotes = Pivotes(distancias: distancias2x2, ids: ids2x2)
    let g = GeometriaPieza.calcular(rayos: rayos, origen: camaraC.posicion,
                                    distancias: distancias2x2, ids: ids2x2,
                                    parametros: ParametrosInversion(estrategia: .global, s: 1),
                                    pivotes: pivotes)
    #expect(g.validos == 3)
    #expect(g.recortados == 0)
    // D = 4: el 3 pasa a 5, el 5 a 3 y el 4 se queda.
    #expect(g.distancias == [0, 5, 3, 4])
    for k in 0..<4 {
        // Cada vértice está en C + r·d' (el fondo, a la distancia D).
        let d = ids2x2[k] == 0 ? pivotes.global : g.distancias[k]
        #expect(simd_distance(g.posiciones[k], camaraC.posicion + rayos[k] * d) < 1e-5)
    }
}

/// Con s = 0 global, todos los válidos quedan a la distancia D de C.
@Test func sCeroEsUnCascaron() {
    let pivotes = Pivotes(distancias: distancias2x2, ids: ids2x2)
    let g = GeometriaPieza.calcular(rayos: camaraC.rayos(n: 2), origen: camaraC.posicion,
                                    distancias: distancias2x2, ids: ids2x2,
                                    parametros: ParametrosInversion(estrategia: .global, s: 0),
                                    pivotes: pivotes)
    for k in 0..<4 where ids2x2[k] != 0 {
        #expect(abs(simd_distance(g.posiciones[k], camaraC.posicion) - 4) < 1e-5)
    }
}
