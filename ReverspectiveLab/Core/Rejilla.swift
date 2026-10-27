//  Rejilla.swift — ReverspectiveLab
//  Los índices de la malla de la pieza: un vértice por píxel de las fotos,
//  unidos en triángulos con sus vecinos. Solo dependen de N, no de lo que
//  muestran las fotos, así que se arman una vez.

enum Rejilla {

    /// Índice que corta una tira de triángulos y empieza otra. En Metal el
    /// reinicio siempre está activo para `.triangleStrip`; con índices de
    /// 32 bits el valor de reinicio es el máximo, 0xFFFFFFFF.
    static let reinicio: UInt32 = 0xFFFF_FFFF

    /// Índices de la rejilla de N×N vértices como tiras de triángulos
    /// (`.triangleStrip`), una tira por fila de quads.
    ///
    /// La tira de la fila j recorre las columnas alternando entre la fila j
    /// (arriba) y la j+1 (abajo): `(j,0) (j+1,0) (j,1) (j+1,1) …`. Cada
    /// vértice nuevo forma un triángulo con los dos anteriores, así que una
    /// fila de N columnas da 2·(N−1) triángulos con solo 2·N índices.
    ///
    /// **Orientación:** el primer triángulo es arriba-izquierda, abajo-
    /// izquierda, arriba-derecha. Visto desde C (en NDC, y hacia arriba)
    /// eso gira en sentido antihorario. En una tira la GPU invierte el
    /// orden de los triángulos impares para que todos queden con la misma
    /// orientación que el primero. Así, más adelante, una cara que aparezca
    /// en sentido horario desde el visor es una cara trasera.
    ///
    /// Entre filas va `reinicio`: sin él, la GPU uniría el final de una
    /// fila con el principio de la siguiente.
    static func indices(n: Int) -> [UInt32] {
        var resultado: [UInt32] = []
        resultado.reserveCapacity(2 * n * (n - 1) + (n - 2))
        for j in 0..<(n - 1) {
            if j > 0 {
                resultado.append(reinicio)
            }
            for i in 0..<n {
                resultado.append(UInt32(j * n + i))        // fila j (arriba)
                resultado.append(UInt32((j + 1) * n + i))  // fila j+1 (abajo)
            }
        }
        return resultado
    }
}
