//  InversionTests.swift — pruebas de la inversión de distancias.

import Testing
@testable import ReverspectiveCore

/// Pivotes de ejemplo: D = 4, la esfera (1) en 3.8 y el piso (3) en 5.
let pivotesEjemplo = Pivotes(global: 4, porObjeto: [1: 3.8, 3: 5])

func parametros(_ estrategia: Estrategia, s: Float, sOrden: Float = 0.5) -> ParametrosInversion {
    ParametrosInversion(estrategia: estrategia, s: s, sOrdenHibrida: sOrden)
}

/// Un píxel justo en el pivote no se mueve.
@Test(arguments: [Estrategia.global, .porObjeto])
func enElPivoteNoSeMueve(estrategia: Estrategia) {
    let id: UInt16 = 1
    let pivote = estrategia == .global ? pivotesEjemplo.global : pivotesEjemplo.porObjeto[id]!
    let r = invertir(d: pivote, id: id, parametros: parametros(estrategia, s: 0.7),
                     pivotes: pivotesEjemplo)
    #expect(abs(r.d - pivote) < 1e-6)
    #expect(!r.recortado)
}

/// Con s = 0 todo queda aplanado en el pivote, sea cual sea d.
@Test(arguments: [Float(1), 3, 4.5, 9])
func sCeroAplana(d: Float) {
    let global = invertir(d: d, id: 1, parametros: parametros(.global, s: 0), pivotes: pivotesEjemplo)
    #expect(abs(global.d - 4) < 1e-6)
    let porObjeto = invertir(d: d, id: 1, parametros: parametros(.porObjeto, s: 0), pivotes: pivotesEjemplo)
    #expect(abs(porObjeto.d - 3.8) < 1e-6)
}

/// Para s > 0, d' baja estrictamente cuando d sube: lo cerca queda lejos.
/// Se prueba en un rango donde no hay recorte.
@Test(arguments: [Estrategia.global, .porObjeto, .hibrida])
func dPrimaDecrece(estrategia: Estrategia) {
    let ds: [Float] = [2, 3, 3.5, 4, 4.5, 5, 6]
    let resultados = ds.map {
        invertir(d: $0, id: 1, parametros: parametros(estrategia, s: 0.8), pivotes: pivotesEjemplo).d
    }
    for (a, b) in zip(resultados, resultados.dropFirst()) {
        #expect(a > b)
    }
}

/// Si d' quedaría por debajo de 0.05·D, se recorta a ese valor.
@Test func recorte() {
    // Global con s = 1: d' = 2·4 − 10 = −2 → se recorta a 0.2.
    let r = invertir(d: 10, id: 1, parametros: parametros(.global, s: 1), pivotes: pivotesEjemplo)
    #expect(r.recortado)
    #expect(abs(r.d - 0.2) < 1e-6)

    // Justo por encima del mínimo no se recorta.
    let justo = invertir(d: 7.7, id: 1, parametros: parametros(.global, s: 1), pivotes: pivotesEjemplo)
    #expect(!justo.recortado)
    #expect(abs(justo.d - 0.3) < 1e-5)
}

/// La fórmula general reproduce exactamente las dos de R3.5.
@Test(arguments: [Float(0.2), 1.7, 3.8, 5, 6.3])
func formulaGeneralReproduceLasDos(d: Float) {
    let D: Float = 4, db: Float = 3.8
    for s: Float in [0, 0.3, 1] {
        let global = distanciaInvertida(d: d, pivoteGlobal: D, pivoteObjeto: db, sOrden: s, sRelieve: s)
        #expect(abs(global - (D + (D - d) * s)) < 1e-5)

        let porObjeto = distanciaInvertida(d: d, pivoteGlobal: D, pivoteObjeto: db, sOrden: -1, sRelieve: s)
        #expect(abs(porObjeto - (db + (db - d) * s)) < 1e-5)
    }
}

/// Los pivotes se calculan desde las fotos, ignorando el fondo.
@Test func pivotesDesdeLasFotos() {
    let distancias: [Float] = [0, 3, 4, 5, 8, 10]
    let ids: [UInt16]       = [0, 1, 1, 1, 3, 3]
    let p = Pivotes(distancias: distancias, ids: ids)
    #expect(p.global == 5)
    #expect(p.porObjeto == [1: 4, 3: 9])
}
