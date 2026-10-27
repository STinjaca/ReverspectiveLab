//  Mediana.swift — ReverspectiveLab
//  La mediana es el pivote de la inversión: el punto alrededor del cual
//  se voltea el relieve.

/// Mediana de un conjunto de valores, o `nil` si está vacío.
///
/// Se usa la mediana y no el promedio porque no se deja arrastrar por unos
/// pocos píxeles muy lejanos (por ejemplo, el fondo del piso): la mitad de
/// los píxeles queda más cerca que el pivote y la otra mitad más lejos.
/// Con un número par de valores es el promedio de los dos del medio.
func mediana(_ valores: [Float]) -> Float? {
    guard !valores.isEmpty else { return nil }
    let ordenados = valores.sorted()
    let medio = ordenados.count / 2
    if ordenados.count % 2 == 1 {
        return ordenados[medio]
    }
    return (ordenados[medio - 1] + ordenados[medio]) / 2
}

/// Mediana de las distancias de los píxeles **válidos** (ID ≠ 0).
///
/// El ID es la fuente de verdad del fondo, no `d == 0`. Si se da `soloID`,
/// solo cuentan los píxeles de ese objeto (el pivote por objeto).
///
/// - Parameters:
///   - distancias: la foto de distancia, un valor por píxel.
///   - ids: la foto de ID, en el mismo orden.
func mediana(distancias: [Float], ids: [UInt16], soloID: UInt16? = nil) -> Float? {
    var elegidas: [Float] = []
    for (d, id) in zip(distancias, ids) where id != 0 && (soloID == nil || id == soloID) {
        elegidas.append(d)
    }
    return mediana(elegidas)
}
