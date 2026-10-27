//  Autoprueba.swift — ReverspectiveLab
//  Chequeos que corren al arrancar (solo en DEBUG) con valores que se
//  conocen de antemano por cómo está armada la escena de prueba. Si algo
//  del pipeline se rompe (una fila al revés, un formato mal leído), se ve
//  aquí antes que en la pantalla.

/// Un chequeo de la autoprueba: qué se revisó, si pasó y qué se midió.
struct Chequeo {
    let nombre: String
    let paso: Bool
    /// El valor medido, para saber cuánto se alejó cuando falla.
    let detalle: String

    /// Una línea para la consola: "✓ nombre — detalle".
    var linea: String { "\(paso ? "✓" : "✗") \(nombre) — \(detalle)" }
}

enum Autoprueba {

    /// Chequeos sobre las fotos de C ya leídas en la CPU. Los valores
    /// esperados salen de `EscenaPrueba`: C en (0, 0, 5) mirando al origen,
    /// esfera de radio 1 en el origen, piso en y = −1.
    static func revisarFotos(_ fotos: FotosLeidas) -> [Chequeo] {
        let n = fotos.tamaño
        let centro = fotos.indice(n / 2, n / 2)

        // El píxel del centro cae en la esfera: de C (z = 5) a la
        // superficie (z = 1) hay 4. El margen cubre que la esfera es de
        // triángulos y que el centro del píxel no es exactamente el eje.
        let d = fotos.distancia[centro]
        let distancia = Chequeo(nombre: "Distancia en (\(n / 2), \(n / 2)) ≈ 4.0",
                                paso: abs(d - 4) <= 0.01,
                                detalle: "medido \(d)")

        let idCentro = fotos.id[centro]
        let esfera = Chequeo(nombre: "ID en (\(n / 2), \(n / 2)) = 1 (esfera)",
                             paso: idCentro == 1,
                             detalle: "medido \(idCentro)")

        // Esquina superior izquierda: el rayo va hacia arriba, no hay nada.
        // Si la fila 0 quedara abajo, aquí aparecería el piso.
        let idEsquina = fotos.id[fotos.indice(0, 0)]
        let fondo = Chequeo(nombre: "ID en (0, 0) = 0 (fondo)",
                            paso: idEsquina == 0,
                            detalle: "medido \(idEsquina)")

        // La última fila (abajo) mira hacia el piso.
        let ultimaFila = (0..<n).map { fotos.id[fotos.indice($0, n - 1)] }
        let pixelesPiso = ultimaFila.filter { $0 == 3 }.count
        let piso = Chequeo(nombre: "Fila \(n - 1) tiene piso (ID 3)",
                           paso: pixelesPiso > 0,
                           detalle: "\(pixelesPiso) de \(n) píxeles")

        return [distancia, esfera, fondo, piso]
    }

    static func imprimir(_ chequeos: [Chequeo]) {
        print("Autoprueba de arranque:")
        for chequeo in chequeos {
            print("  " + chequeo.linea)
        }
    }
}
