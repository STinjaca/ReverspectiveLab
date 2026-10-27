//  MedianaTests.swift — pruebas de la mediana.

import Testing
@testable import ReverspectiveCore

@Test func medianaImpar() {
    #expect(mediana([5, 1, 3]) == 3)
}

@Test func medianaPar() {
    #expect(mediana([4, 1, 3, 2]) == 2.5)
}

@Test func medianaVacia() {
    #expect(mediana([]) == nil)
}

/// Los píxeles de fondo (ID 0) no cuentan, aunque su distancia no sea 0.
@Test func medianaIgnoraNoValidos() {
    let distancias: [Float] = [100, 2, 4, 100, 6]
    let ids: [UInt16]       = [0,   1, 1, 0,   2]
    #expect(mediana(distancias: distancias, ids: ids) == 4)
}

/// Con `soloID`, solo cuentan los píxeles de ese objeto.
@Test func medianaPorObjeto() {
    let distancias: [Float] = [1, 2, 3, 10, 20, 9]
    let ids: [UInt16]       = [1, 1, 1, 2,  2,  0]
    #expect(mediana(distancias: distancias, ids: ids, soloID: 1) == 2)
    #expect(mediana(distancias: distancias, ids: ids, soloID: 2) == 15)
    #expect(mediana(distancias: distancias, ids: ids, soloID: 3) == nil)
}
