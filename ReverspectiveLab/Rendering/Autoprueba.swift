//  Autoprueba.swift — ReverspectiveLab
//  Chequeos que corren al arrancar (solo en DEBUG) con valores que se
//  conocen de antemano por cómo está armada la escena de prueba. Si algo
//  del pipeline se rompe (una fila al revés, un formato mal leído), se ve
//  aquí antes que en la pantalla.

import Metal
import simd

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

    /// R4.5: dibuja la pieza desde C en una textura de N×N y la compara con
    /// la foto de color en los píxeles válidos.
    ///
    /// Es el invariante central de la reverspectiva: como cada vértice se
    /// quedó sobre el rayo de su píxel, desde C la pieza tiene que verse
    /// igual que la escena original, aunque su relieve esté al revés. Si
    /// los rayos, la UV o la orientación de la rejilla estuvieran mal, la
    /// diferencia lo delataría.
    ///
    /// Pasa si la diferencia media absoluta por canal (RGB) es menor que
    /// 3/255.
    ///
    /// Se deja fuera el anillo de píxeles del borde de la imagen: la malla
    /// va del centro del primer píxel al centro del último, así que los
    /// centros de la última fila y la última columna caen justo sobre su
    /// borde, y la regla de rasterización de la GPU (no pinta los bordes
    /// derecho e inferior de un triángulo) los deja sin pintar. Contarlos
    /// mezclaría ese detalle con errores de verdad.
    static func revisarPiezaDesdeC(device: MTLDevice, commandQueue: MTLCommandQueue,
                                   pieza: Pieza, fotos: FotosC, leidas: FotosLeidas,
                                   camaraC: Camara) -> Chequeo {
        let n = fotos.tamaño
        // Sin tintes: se compara la textura tal cual.
        let dibujada = dibujarDesdeC(device: device, commandQueue: commandQueue, pieza: pieza,
                                     fotos: fotos, camaraC: camaraC,
                                     interruptores: PiezaUniforms(resaltarParedes: 0, marcarTraseras: 0))
        var suma = 0, validos = 0
        for j in 1..<(n - 1) {
            for i in 1..<(n - 1) where leidas.id[leidas.indice(i, j)] != 0 {
                let k = leidas.indice(i, j)
                let a = dibujada[k], b = leidas.color[k]
                for canal in 0..<3 {    // RGB, sin alfa
                    suma += abs(Int(a[canal]) - Int(b[canal]))
                }
                validos += 1
            }
        }
        let media = Float(suma) / Float(max(validos * 3, 1))
        return Chequeo(nombre: "Pieza desde C = foto de color (dif. media < 3/255)",
                       paso: media < 3,
                       detalle: String(format: "medido %.2f/255 en %d píxeles válidos del interior", media, validos))
    }

    /// R6.4: desde C ningún triángulo de la pieza se ve por detrás.
    ///
    /// Comprueba la orientación de la rejilla (R3.6) junto con
    /// `setFrontFacing(.counterClockwise)`: dibuja la pieza desde C con y
    /// sin "caras traseras en azul" y exige que salgan idénticas. Si la
    /// rejilla estuviera en sentido horario, o Metal tomara el otro sentido
    /// como frontal, toda la pieza saldría azul.
    static func revisarCarasDesdeC(device: MTLDevice, commandQueue: MTLCommandQueue,
                                   pieza: Pieza, fotos: FotosC, camaraC: Camara) -> Chequeo {
        let normal = dibujarDesdeC(device: device, commandQueue: commandQueue, pieza: pieza,
                                   fotos: fotos, camaraC: camaraC,
                                   interruptores: PiezaUniforms(resaltarParedes: 0, marcarTraseras: 0))
        let conTraseras = dibujarDesdeC(device: device, commandQueue: commandQueue, pieza: pieza,
                                        fotos: fotos, camaraC: camaraC,
                                        interruptores: PiezaUniforms(resaltarParedes: 0, marcarTraseras: 1))
        let distintos = zip(normal, conTraseras).filter { $0 != $1 }.count
        return Chequeo(nombre: "Desde C no hay caras traseras",
                       paso: distintos == 0,
                       detalle: "\(distintos) píxeles azules")
    }

    /// Dibuja la pieza desde C en una textura de N×N como la foto de color,
    /// espera a la GPU y la devuelve leída en la CPU.
    ///
    /// Usa la textura de profundidad de las fotos, que está libre después
    /// de tomarlas.
    private static func dibujarDesdeC(device: MTLDevice, commandQueue: MTLCommandQueue,
                                      pieza: Pieza, fotos: FotosC, camaraC: Camara,
                                      interruptores: PiezaUniforms) -> [SIMD4<UInt8>] {
        let n = fotos.tamaño
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: fotos.color.pixelFormat,
                                                                  width: n, height: n, mipmapped: false)
        descriptor.usage = [.renderTarget]
        descriptor.storageMode = .shared
        let destino = device.makeTexture(descriptor: descriptor)!
        destino.label = "Autoprueba: pieza desde C"

        let pasada = MTLRenderPassDescriptor()
        pasada.colorAttachments[0].texture = destino
        pasada.colorAttachments[0].loadAction = .clear
        pasada.colorAttachments[0].clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        pasada.colorAttachments[0].storeAction = .store
        pasada.depthAttachment.texture = fotos.profundidad
        pasada.depthAttachment.loadAction = .clear
        pasada.depthAttachment.clearDepth = 1
        pasada.depthAttachment.storeAction = .dontCare

        let depthDesc = MTLDepthStencilDescriptor()
        depthDesc.depthCompareFunction = .less
        depthDesc.isDepthWriteEnabled = true

        let commandBuffer = commandQueue.makeCommandBuffer()!
        commandBuffer.label = "Autoprueba: pieza desde C"
        let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pasada)!
        // Sin MSAA, como la foto: se compara píxel a píxel.
        encoder.setRenderPipelineState(pieza.crearPipeline(formatoColor: destino.pixelFormat,
                                                           formatoProfundidad: fotos.profundidad.pixelFormat,
                                                           muestras: 1))
        encoder.setDepthStencilState(device.makeDepthStencilState(descriptor: depthDesc)!)
        let viewProjection = camaraC.matrizProyeccion(aspect: 1) * camaraC.matrizVista()
        pieza.dibujar(encoder: encoder, viewProjection: viewProjection, colorFoto: fotos.color,
                      interruptores: interruptores)
        encoder.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        return FotosC.copiar(destino, como: SIMD4<UInt8>.self)
    }

    static func imprimir(_ chequeos: [Chequeo]) {
        print("Autoprueba de arranque:")
        for chequeo in chequeos {
            print("  " + chequeo.linea)
        }
    }
}
