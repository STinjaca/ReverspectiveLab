//  Inversion.swift — ReverspectiveLab
//  El corazón de la reverspectiva: a cada píxel se le cambia la distancia
//  d por una d' que voltea el relieve. Lo cerca pasa a estar lejos y
//  viceversa, siempre sobre el mismo rayo, así que desde C se ve igual.

/// Cómo se elige el pivote alrededor del cual se voltea el relieve.
enum Estrategia: String, CaseIterable {
    /// Un solo pivote para toda la escena: se voltea todo, incluido el
    /// orden entre objetos.
    case global = "Global"
    /// Cada objeto se voltea alrededor de su propio pivote y se queda a su
    /// distancia promedio: el orden entre objetos se conserva.
    case porObjeto = "Por objeto"
    /// Entre las dos: el orden entre objetos se voltea en otra medida
    /// (`sOrden`) que el relieve de cada objeto (`s`).
    case hibrida = "Híbrida"
}

/// Los pivotes de la inversión, calculados una vez a partir de las fotos.
struct Pivotes {
    /// D: mediana de las distancias de todos los píxeles válidos.
    let global: Float
    /// d_b(k): mediana de las distancias de los píxeles de cada objeto.
    let porObjeto: [UInt16: Float]

    /// Calcula D y un d_b por cada ID que aparezca en la foto (sin el 0).
    init(distancias: [Float], ids: [UInt16]) {
        self.global = mediana(distancias: distancias, ids: ids) ?? 0
        var porObjeto: [UInt16: Float] = [:]
        for id in Set(ids) where id != 0 {
            porObjeto[id] = mediana(distancias: distancias, ids: ids, soloID: id)
        }
        self.porObjeto = porObjeto
    }

    /// Para pruebas: pivotes dados a mano.
    init(global: Float, porObjeto: [UInt16: Float]) {
        self.global = global
        self.porObjeto = porObjeto
    }

    /// Distancia mínima permitida para d': el 5 % del pivote global. Evita
    /// que un vértice quede pegado a C o detrás de ella (d' ≤ 0), que
    /// daría triángulos gigantes.
    var dMinima: Float { 0.05 * global }
}

/// Qué inversión aplicar: la estrategia y sus factores.
struct ParametrosInversion: Equatable {
    var estrategia: Estrategia = .global
    /// Factor de inversión del relieve, en [0, 1]. 0 = todo aplanado en el
    /// pivote; 1 = inversión completa. Es el `s_relieve` de R7.
    var s: Float = 1
    /// Cuánto se voltea el orden entre objetos en la estrategia híbrida,
    /// de −1 a 1. Las otras estrategias lo fijan solas (ver `sOrden`).
    var sOrdenHibrida: Float = 0.5

    /// El `s_orden` de la fórmula general para la estrategia elegida:
    /// - global: igual a `s`, todo se voltea junto;
    /// - por objeto: −1, cada objeto se queda en su distancia promedio;
    /// - híbrida: el que se eligió.
    var sOrden: Float {
        switch estrategia {
        case .global: s
        case .porObjeto: -1
        case .hibrida: sOrdenHibrida
        }
    }
}

/// La fórmula general de la inversión (R7), sin recorte:
///
///     d' = [D + (D − d_b)·s_orden] + (d_b − d)·s_relieve
///
/// El corchete es dónde queda el objeto (su pivote movido); el segundo
/// término es su relieve volteado alrededor de ese punto. Con
/// `s_orden = s_relieve = s` los d_b se cancelan y queda la global,
/// `D + (D − d)·s`; con `s_orden = −1` el corchete vale d_b y queda la
/// por objeto, `d_b + (d_b − d)·s`.
func distanciaInvertida(d: Float, pivoteGlobal D: Float, pivoteObjeto db: Float,
                        sOrden: Float, sRelieve: Float) -> Float {
    (D + (D - db) * sOrden) + (db - d) * sRelieve
}

/// Invierte la distancia de un píxel: `(d, ID, estrategia, s) → d'`.
///
/// Aplica la fórmula general con los factores de `parametros` y luego el
/// **recorte**: si d' queda por debajo de `pivotes.dMinima`, se fija en
/// ese valor y se avisa con `recortado`. Es la restricción
/// `d < d_b(1 + s)/s` del diseño (que garantiza d' > 0), con un margen.
///
/// - Returns: la distancia nueva y si hubo que recortarla.
func invertir(d: Float, id: UInt16, parametros: ParametrosInversion,
              pivotes: Pivotes) -> (d: Float, recortado: Bool) {
    // Un ID sin pivote no debería pasar; se usa el global para no fallar.
    let db = pivotes.porObjeto[id] ?? pivotes.global
    let nueva = distanciaInvertida(d: d, pivoteGlobal: pivotes.global, pivoteObjeto: db,
                                   sOrden: parametros.sOrden, sRelieve: parametros.s)
    if nueva < pivotes.dMinima {
        return (pivotes.dMinima, true)
    }
    return (nueva, false)
}
