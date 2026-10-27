//  Paredes.swift — ReverspectiveLab
//  Las "paredes" de la reverspectiva: triángulos de la rejilla que unen
//  vértices a profundidades muy distintas. Desde C no se notan (se ven de
//  canto), pero al moverse se estiran y son los que rompen la ilusión.

/// Qué triángulos de la pieza son pared, para una inversión dada.
struct Paredes {
    /// Por vértice: 1 si toca algún triángulo pared, 0 si no. Es lo que se
    /// sube a la GPU para teñirlos (un valor por vértice, no por triángulo,
    /// porque la malla comparte vértices entre triángulos).
    let marcaVertice: [Float]
    /// Triángulos con sus tres vértices válidos (los únicos que se dibujan).
    let triangulosValidos: Int
    /// Cuántos de esos son pared.
    let triangulosPared: Int

    /// % de triángulos válidos que son pared, para el panel.
    var porcentaje: Float {
        triangulosValidos > 0 ? 100 * Float(triangulosPared) / Float(triangulosValidos) : 0
    }

    /// ¿Hay salto entre dos vértices? Diferencia relativa de d' mayor que τ,
    /// medida respecto al más cercano de los dos: `|a − b| / min(a, b)`.
    ///
    /// Relativa y no absoluta porque lo que se ve es el ángulo: el mismo
    /// salto de 0.3 se nota mucho más a distancia 1 que a distancia 6.
    static func hayRuptura(_ a: Float, _ b: Float, umbral: Float) -> Bool {
        abs(a - b) / min(a, b) > umbral
    }

    /// Recorre los 2·(N−1)² triángulos de la rejilla y marca las paredes.
    ///
    /// Un triángulo es **pared** si, entre dos de sus vértices, d' salta más
    /// que el umbral τ o el ID cambia (un borde entre objetos). Solo cuentan
    /// los triángulos con los tres vértices válidos: los que tocan el fondo
    /// no se dibujan.
    ///
    /// Los triángulos son los mismos que forman las tiras de `Rejilla`: en
    /// cada cuadro, (arriba-izq, abajo-izq, arriba-der) y (abajo-izq,
    /// arriba-der, abajo-der).
    ///
    /// - Parameters:
    ///   - distancias: d' por píxel (`GeometriaPieza.distancias`).
    ///   - ids: la foto de ID.
    ///   - umbral: τ, por ejemplo 0.08 (un 8 %).
    static func calcular(distancias: [Float], ids: [UInt16], n: Int, umbral: Float) -> Paredes {
        var marca = [Float](repeating: 0, count: n * n)
        var validos = 0, pared = 0

        func revisar(_ a: Int, _ b: Int, _ c: Int) {
            guard ids[a] != 0, ids[b] != 0, ids[c] != 0 else { return }
            validos += 1
            let cambiaID = ids[a] != ids[b] || ids[b] != ids[c]
            let salta = hayRuptura(distancias[a], distancias[b], umbral: umbral)
                     || hayRuptura(distancias[b], distancias[c], umbral: umbral)
                     || hayRuptura(distancias[a], distancias[c], umbral: umbral)
            if cambiaID || salta {
                pared += 1
                marca[a] = 1; marca[b] = 1; marca[c] = 1
            }
        }

        for j in 0..<(n - 1) {
            for i in 0..<(n - 1) {
                let arribaIzq = j * n + i, arribaDer = arribaIzq + 1
                let abajoIzq = arribaIzq + n, abajoDer = abajoIzq + 1
                revisar(arribaIzq, abajoIzq, arribaDer)
                revisar(abajoIzq, arribaDer, abajoDer)
            }
        }
        return Paredes(marcaVertice: marca, triangulosValidos: validos, triangulosPared: pared)
    }
}
