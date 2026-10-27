//  RejillaTests.swift — pruebas de los índices de la rejilla.

import Testing
import simd
@testable import ReverspectiveCore

/// Cuenta los triángulos de una lista de tiras: cada tira de k índices
/// da k − 2 triángulos.
func contarTriangulos(_ indices: [UInt32]) -> Int {
    indices.split(separator: Rejilla.reinicio).map { $0.count - 2 }.reduce(0, +)
}

@Test func rejillaN256() {
    let n = 256
    let indices = Rejilla.indices(n: n)
    let reinicios = indices.filter { $0 == Rejilla.reinicio }.count
    #expect(indices.count - reinicios == 130_560)          // 2·(N−1)·N
    #expect(reinicios == n - 2)
    #expect(indices.allSatisfy { $0 == Rejilla.reinicio || $0 < UInt32(n * n) })
    #expect(contarTriangulos(indices) == 130_050)           // 2·(N−1)²
}

/// N = 3, escrito a mano:
///
///     0 1 2
///     3 4 5
///     6 7 8
@Test func rejillaN3() {
    let r = Rejilla.reinicio
    #expect(Rejilla.indices(n: 3) == [0, 3, 1, 4, 2, 5, r, 3, 6, 4, 7, 5, 8])
}

/// El primer triángulo es antihorario en NDC (área con signo positiva).
@Test func primerTrianguloAntihorario() {
    let n = 3
    let indices = Rejilla.indices(n: n)

    // Centro del píxel k en NDC, como en `Camara.rayo`.
    func ndc(_ k: UInt32) -> SIMD2<Float> {
        let i = Int(k) % n, j = Int(k) / n
        let u = (Float(i) + 0.5) / Float(n), v = (Float(j) + 0.5) / Float(n)
        return [2 * u - 1, 1 - 2 * v]
    }
    let a = ndc(indices[0]), b = ndc(indices[1]), c = ndc(indices[2])
    let ab = b - a, ac = c - a
    let areaConSigno = ab.x * ac.y - ab.y * ac.x
    #expect(areaConSigno > 0)
}
