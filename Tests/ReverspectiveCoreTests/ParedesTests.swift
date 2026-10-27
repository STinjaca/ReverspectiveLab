//  ParedesTests.swift — pruebas de la detección de paredes.

import Testing
@testable import ReverspectiveCore

/// Una rejilla de 3×3 (8 triángulos) toda del mismo objeto y a la misma
/// distancia: ninguna pared.
@Test func planoSinParedes() {
    let p = Paredes.calcular(distancias: Array(repeating: 4, count: 9),
                             ids: Array(repeating: 1, count: 9), n: 3, umbral: 0.08)
    #expect(p.triangulosValidos == 8)
    #expect(p.triangulosPared == 0)
    #expect(p.marcaVertice.allSatisfy { $0 == 0 })
}

/// La columna de la derecha está 20 % más lejos: los triángulos de la
/// segunda columna de cuadros son pared, los de la primera no.
@Test func saltoDeDistancia() {
    let d: [Float] = [4, 4, 4.8,
                      4, 4, 4.8,
                      4, 4, 4.8]
    let p = Paredes.calcular(distancias: d, ids: Array(repeating: 1, count: 9), n: 3, umbral: 0.08)
    #expect(p.triangulosPared == 4)
    #expect(p.porcentaje == 50)
    #expect(p.marcaVertice[0] == 0)      // la columna de la izquierda no toca paredes
    #expect(p.marcaVertice[2] == 1)
}

/// Un salto por debajo de τ no es pared.
@Test func saltoPequeno() {
    let d: [Float] = [4, 4, 4.2,
                      4, 4, 4.2,
                      4, 4, 4.2]
    let p = Paredes.calcular(distancias: d, ids: Array(repeating: 1, count: 9), n: 3, umbral: 0.08)
    #expect(p.triangulosPared == 0)
}

/// Un cambio de ID sin salto de distancia no es pared (R9.3).
@Test func bordeEntreObjetosSinSalto() {
    let ids: [UInt16] = [1, 1, 2,
                         1, 1, 2,
                         1, 1, 2]
    let p = Paredes.calcular(distancias: Array(repeating: 4, count: 9), ids: ids, n: 3, umbral: 0.08)
    #expect(p.triangulosPared == 0)
}

/// Un cambio de ID con salto sí es pared, por el salto.
@Test func bordeEntreObjetosConSalto() {
    let ids: [UInt16] = [1, 1, 2,
                         1, 1, 2,
                         1, 1, 2]
    let d: [Float] = [4, 4, 5,
                      4, 4, 5,
                      4, 4, 5]
    let p = Paredes.calcular(distancias: d, ids: ids, n: 3, umbral: 0.08)
    #expect(p.triangulosPared == 4)
}

/// Los triángulos que tocan el fondo no cuentan, ni como válidos ni como pared.
@Test func fondoNoCuenta() {
    let ids: [UInt16] = [0, 1, 1,
                         1, 1, 1,
                         1, 1, 1]
    let d: [Float] = [0, 4, 4,
                      4, 4, 4,
                      4, 4, 4]
    let p = Paredes.calcular(distancias: d, ids: ids, n: 3, umbral: 0.08)
    #expect(p.triangulosValidos == 7)
    #expect(p.triangulosPared == 0)
}
