//  RayosTests.swift — pruebas de los rayos desde C.

import Testing
import simd
@testable import ReverspectiveCore

/// La cámara C de la escena de prueba.
let camaraC = Camara(posicion: [0, 0, 5], objetivo: [0, 0, 0], fovGrados: 45)
/// Lado de las fotos (N).
let ladoFotos = 256

/// El rayo del centro de la imagen apunta al objetivo de la cámara.
@Test func rayoDelCentroApuntaAlObjetivo() {
    let esperado = simd_normalize(camaraC.objetivo - camaraC.posicion)
    let r = camaraC.rayo(ndc: [0, 0])
    #expect(simd_distance(r, esperado) < 1e-6)

    // Con N par no hay píxel central: el promedio de los 4 del centro sí
    // cae en el eje.
    let h = ladoFotos / 2
    let promedio = camaraC.rayo(i: h - 1, j: h - 1, n: ladoFotos) + camaraC.rayo(i: h, j: h - 1, n: ladoFotos)
                 + camaraC.rayo(i: h - 1, j: h, n: ladoFotos) + camaraC.rayo(i: h, j: h, n: ladoFotos)
    #expect(simd_distance(simd_normalize(promedio), esperado) < 1e-6)
}

/// Ida y vuelta: un punto sobre el rayo del píxel (i, j), proyectado con la
/// `viewProjection` de C, cae en el centro de ese mismo píxel. Si la fila 0
/// quedara abajo o la base estuviera volteada, aquí se notaría.
@Test(arguments: [(0, 0), (ladoFotos - 1, 0), (0, ladoFotos - 1), (ladoFotos - 1, ladoFotos - 1), (ladoFotos / 2, ladoFotos / 2), (37, 201)])
func idaYVuelta(i: Int, j: Int) {
    let viewProjection = camaraC.matrizProyeccion(aspect: 1) * camaraC.matrizVista()
    let punto = camaraC.posicion + camaraC.rayo(i: i, j: j, n: ladoFotos) * 5
    let clip = viewProjection * SIMD4<Float>(punto, 1)
    let ndc = SIMD2<Float>(clip.x, clip.y) / clip.w

    // De NDC a píxel, al revés de lo que hace `rayo`.
    let iMedido = (ndc.x + 1) / 2 * Float(ladoFotos) - 0.5
    let jMedido = (1 - ndc.y) / 2 * Float(ladoFotos) - 0.5
    #expect(abs(iMedido - Float(i)) < 0.01)
    #expect(abs(jMedido - Float(j)) < 0.01)
}

/// Los rayos son unitarios y `rayos(n:)` respeta el orden k = j·N + i.
@Test func rayosEnOrden() {
    let todos = camaraC.rayos(n: 4)
    #expect(todos.count == 16)
    #expect(todos[2 * 4 + 3] == camaraC.rayo(i: 3, j: 2, n: 4))
    #expect(todos.allSatisfy { abs(simd_length($0) - 1) < 1e-6 })
}
