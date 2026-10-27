//  Rayos.swift — ReverspectiveLab
//  El rayo que sale de C y pasa por el centro de cada píxel de las fotos.
//  Es lo que permite pasar de "píxel + distancia" a un punto 3D:
//  punto = C + rayo · distancia.

import simd

extension Camara {

    /// Dirección unitaria, en el mundo, del rayo que sale de la cámara y
    /// pasa por el centro del píxel (i, j) de una foto cuadrada de N×N.
    ///
    /// Sigue las convenciones de REQUISITOS §3:
    /// 1. Centro del píxel en UV: `u = (i + 0.5)/N`, `v = (j + 0.5)/N`.
    /// 2. A NDC: `x = 2u − 1`, `y = 1 − 2v`. La `y` se voltea porque la fila
    ///    0 está arriba y en NDC la y crece hacia arriba.
    /// 3. En el espacio de la cámara, el plano de la imagen a distancia 1
    ///    mide `tan(fov/2)` de alto hacia cada lado: el rayo es
    ///    `(x·tan·aspecto, y·tan, −1)`, porque la cámara mira hacia −z.
    /// 4. Al mundo, con la misma base que arma `matrizVista`
    ///    (derecha, arriba, −adelante). Así el rayo es exactamente el
    ///    inverso de proyectar con la cámara: hay una prueba de ida y vuelta.
    func rayo(i: Int, j: Int, n: Int) -> SIMD3<Float> {
        let u = (Float(i) + 0.5) / Float(n)
        let v = (Float(j) + 0.5) / Float(n)
        return rayo(ndc: SIMD2<Float>(2 * u - 1, 1 - 2 * v))
    }

    /// El rayo que pasa por un punto de la imagen dado en NDC (−1…1). La
    /// foto es cuadrada, así que el aspecto es 1.
    func rayo(ndc: SIMD2<Float>) -> SIMD3<Float> {
        let tanMedio = tan(fovGrados * .pi / 180 / 2)
        let aspecto: Float = 1
        let enCamara = SIMD3<Float>(ndc.x * tanMedio * aspecto, ndc.y * tanMedio, -1)

        // La misma base que `matrix4x4LookAt`.
        let adelante = simd_normalize(objetivo - posicion)
        let derecha = simd_normalize(simd_cross(adelante, arriba))
        let arribaReal = simd_cross(derecha, adelante)
        let enMundo = enCamara.x * derecha + enCamara.y * arribaReal - enCamara.z * adelante
        return simd_normalize(enMundo)
    }

    /// Los N² rayos de la foto, en el mismo orden que los píxeles
    /// (`k = j·N + i`). Dependen solo de la cámara y de N, así que se
    /// calculan una vez y se reutilizan cada vez que cambia la inversión.
    func rayos(n: Int) -> [SIMD3<Float>] {
        var resultado: [SIMD3<Float>] = []
        resultado.reserveCapacity(n * n)
        for j in 0..<n {
            for i in 0..<n {
                resultado.append(rayo(i: i, j: j, n: n))
            }
        }
        return resultado
    }
}
