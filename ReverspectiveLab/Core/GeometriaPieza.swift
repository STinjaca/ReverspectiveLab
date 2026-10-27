//  GeometriaPieza.swift — ReverspectiveLab
//  Las posiciones 3D de la pieza invertida: cada píxel de las fotos se
//  vuelve un vértice, movido sobre su propio rayo hasta la distancia d'.

import simd

/// La forma de la pieza para una inversión dada: un vértice por píxel.
struct GeometriaPieza {
    /// `p'(i, j) = C + r(i, j)·d'(i, j)`, en el orden de los píxeles.
    let posiciones: [SIMD3<Float>]
    /// d' por píxel. 0 en los no válidos.
    let distancias: [Float]
    /// Cuántos píxeles válidos hubo que recortar (ver `invertir`).
    let recortados: Int
    /// Cuántos píxeles válidos (ID ≠ 0) hay.
    let validos: Int

    /// Invierte todas las distancias de las fotos y arma las posiciones.
    ///
    /// Como cada vértice se queda sobre el rayo de su píxel, desde C se ve
    /// exactamente en el mismo lugar de la imagen que el punto original:
    /// por eso la pieza, vista desde C, es idéntica a la escena. Lo único
    /// que cambia es qué tan lejos está.
    ///
    /// Los píxeles no válidos (fondo) quedan sobre su rayo a la distancia
    /// del pivote global. Su posición da igual porque no se dibujan, pero
    /// así no son puntos raros (ni NaN ni pegados a C).
    ///
    /// - Parameters:
    ///   - rayos: `camaraC.rayos(n:)`, calculados una vez.
    ///   - origen: la posición de C.
    ///   - distancias, ids: las fotos de C, un valor por píxel.
    static func calcular(rayos: [SIMD3<Float>], origen: SIMD3<Float>,
                         distancias: [Float], ids: [UInt16],
                         parametros: ParametrosInversion, pivotes: Pivotes) -> GeometriaPieza {
        var posiciones: [SIMD3<Float>] = []
        var nuevas: [Float] = []
        posiciones.reserveCapacity(rayos.count)
        nuevas.reserveCapacity(rayos.count)
        var recortados = 0, validos = 0

        for k in rayos.indices {
            guard ids[k] != 0 else {
                posiciones.append(origen + rayos[k] * pivotes.global)
                nuevas.append(0)
                continue
            }
            let r = invertir(d: distancias[k], id: ids[k], parametros: parametros, pivotes: pivotes)
            posiciones.append(origen + rayos[k] * r.d)
            nuevas.append(r.d)
            validos += 1
            if r.recortado { recortados += 1 }
        }
        return GeometriaPieza(posiciones: posiciones, distancias: nuevas,
                              recortados: recortados, validos: validos)
    }
}
