//  EstadoVisor.swift — ReverspectiveLab
//  El estado que comparten la interfaz (SwiftUI) y el Renderer (Metal):
//  la interfaz lo cambia con los controles y el Renderer lo lee en cada
//  frame. El Renderer también escribe aquí los datos que la interfaz muestra.

import Observation
import simd

/// Qué se ve en el visor.
enum ModoVista {
    /// La escena 3D de verdad, con Blinn-Phong.
    case escena
    /// La pieza invertida, con la foto de color pegada.
    case pieza
}

/// `@Observable` hace que SwiftUI se entere sola de los cambios: cada vista
/// que lee una propiedad se vuelve a dibujar cuando esa propiedad cambia.
/// No hace falta `@Published` ni avisar a mano.
@Observable
final class EstadoVisor {

    // MARK: Lo que cambia la interfaz

    var modo: ModoVista = .escena
    /// Estrategia y `s`. El Renderer recalcula la pieza cuando cambian.
    var parametros = ParametrosInversion()
    /// τ: diferencia relativa de d' a partir de la cual un triángulo es
    /// pared. El Renderer recalcula las paredes cuando cambia.
    var umbralPared: Float = 0.08
    /// Teñir de rojo las paredes.
    var resaltarParedes = false
    /// Teñir de azul las caras que el visor ve por detrás.
    var marcarTraseras = false
    /// La cámara del visor. La mueven los gestos y los botones; orbita
    /// alrededor de P (ver `preparar`).
    var camaraVisor = Camara(posicion: [0, 0, 5], objetivo: [0, 0, 0])

    // MARK: Lo que escribe el Renderer

    /// La cámara de las fotos. `nil` hasta que el Renderer llama a `preparar`.
    private(set) var camaraC: Camara?
    /// El centro de la pieza visto desde C (ver `Camara.puntoP`).
    private(set) var puntoP: SIMD3<Float> = .zero
    private(set) var pivotes: Pivotes?
    /// Nombre de cada objeto por su ID, para mostrar los pivotes.
    private(set) var nombresObjetos: [UInt16: String] = [:]
    /// % de píxeles válidos recortados en la inversión actual.
    var porcentajeRecortados: Float = 0
    /// % de triángulos válidos que son pared.
    var porcentajeParedes: Float = 0
    /// Resultado de la autoprueba de arranque (vacío en Release).
    var autoprueba: [Chequeo] = []

    /// Lo llama el Renderer al arrancar, cuando ya conoce C y los pivotes.
    /// Deja el visor en C mirando a P, para que el primer cuadro se vea
    /// igual que antes y orbitar sea girar alrededor de la pieza.
    func preparar(camaraC: Camara, pivotes: Pivotes, nombresObjetos: [UInt16: String]) {
        self.camaraC = camaraC
        self.pivotes = pivotes
        self.nombresObjetos = nombresObjetos
        self.puntoP = camaraC.puntoP(distancia: pivotes.global)
        irAC()
    }

    /// θ actual en grados, o `nil` antes de `preparar`. Se calcula al leerlo,
    /// así siempre corresponde a la cámara de ahora.
    var theta: Float? {
        guard let c = camaraC else { return nil }
        return anguloTheta(c: c.posicion, visor: camaraVisor.posicion, p: puntoP)
    }

    /// Pone el visor exactamente en C, mirando a P. Desde ahí la pieza se ve
    /// idéntica a la escena (θ = 0, y también la misma distancia).
    func irAC() {
        guard let c = camaraC else { return }
        camaraVisor.posicion = c.posicion
        camaraVisor.objetivo = puntoP
    }

    /// Deshace la órbita pero no el zoom: vuelve a la línea de C (θ = 0),
    /// a la distancia de P donde estaba el visor.
    func reiniciarOrbita() {
        guard let c = camaraC else { return }
        let radio = simd_distance(camaraVisor.posicion, puntoP)
        camaraVisor.objetivo = puntoP
        camaraVisor.posicion = puntoP + simd_normalize(c.posicion - puntoP) * radio
    }
}
