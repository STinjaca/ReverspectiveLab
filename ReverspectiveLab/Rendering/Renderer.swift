//
//  Renderer.swift
//  ReverspectiveLab
//
//  Created by Santi T on 25/10/26.
//

import MetalKit
import simd

/// Uniforms por objeto, subidos una vez por objeto en el loop de draw.
///
/// `modelMatrix` viaja aparte de `mvpMatrix` porque `vs_main` la necesita
/// sin proyectar: con ella pasa posición y normal a world space, que es
/// donde `fs_main` calcula la iluminación.
struct Uniforms {
    var modelMatrix: simd_float4x4
    var mvpMatrix: simd_float4x4
    var baseColor: SIMD4<Float>
    var shininess: Float
    var objetoID: UInt32    // UInt32 y no UInt16: tiene que medir lo mismo que `uint` en Metal
}

/// Uniforms globales de la escena, subidos una sola vez por frame (buffer
/// distinto al de `Uniforms`, índice 2) — no dependen de qué objeto se esté
/// dibujando, así que no tiene sentido repetirlos por draw call.
struct SceneUniforms {
    var lightPosition: SIMD3<Float>
    var cameraPosition: SIMD3<Float>
}

/// Qué se ve en el visor.
enum ModoVista {
    /// La escena 3D de verdad, con Blinn-Phong.
    case escena
    /// La pieza invertida, con la foto de color pegada.
    case pieza
}

final class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    let escena: Escena

    /// Texturas de 256×256 donde la cámara C toma las fotos.
    let fotos: FotosC
    let pasadaFotos: PasadaFotos
    /// Copia de las fotos en la CPU, leída una vez después de tomarlas.
    let fotosLeidas: FotosLeidas
    let miniaturas: Miniaturas

    /// Qué se dibuja en el visor (la interfaz lo cambia en R5).
    var modo: ModoVista = .escena

    // --- Pieza invertida ---
    /// Rayos de C por píxel; dependen solo de C y de N.
    let rayos: [SIMD3<Float>]
    /// D y los d_b de cada objeto, sacados de las fotos.
    let pivotes: Pivotes
    /// Estrategia y factores de la inversión actual.
    private(set) var parametros = ParametrosInversion()
    /// Resultado de la inversión actual (posiciones, recortados…).
    private(set) var geometria: GeometriaPieza
    let pieza: Pieza
    let pipelinePieza: MTLRenderPipelineState
    /// d_min…d_max de los píxeles válidos; normaliza la miniatura de distancia.
    let rangoDistancias: ClosedRange<Float>

    /// Resultado de la autoprueba de arranque, para mostrarlo en la
    /// interfaz. Vacío en Release, donde la autoprueba no corre.
    private(set) var autoprueba: [Chequeo] = []

    #if DEBUG
    /// Volver a tomar las fotos en cada frame. La captura de GPU de Xcode
    /// solo muestra lo que pasa dentro de un frame: con esto en `true` la
    /// pasada de las fotos aparece en la captura. Las fotos salen iguales,
    /// porque la escena y C no cambian.
    var fotosEnCadaFrame = false
    #endif

    /// Cámara para mirar la escena en pantalla. Es independiente de
    /// `escena.camaraC`, que se queda fija para tomar las fotos.
    var camaraVisor = Camara(posicion: [0, 0, 5], objetivo: [0, 0, 0])


    // Pipeline "normal": Blinn-Phong real, escribe y prueba profundidad.
    let pipelineState: MTLRenderPipelineState
    let depthState: MTLDepthStencilState

    var aspect: Float = 1

    init(
        vista: MTKView
    ) {
        self.device = vista.device!
        self.commandQueue =
            device
            .makeCommandQueue()!
        let library = device.makeDefaultLibrary()!
        vista.colorPixelFormat = .bgra8Unorm
        vista.depthStencilPixelFormat = .depth32Float
        
        self.escena = try! EscenaPrueba.crear(device: device)
        self.fotos = FotosC(device: device)
        self.pasadaFotos = PasadaFotos(device: device, library: library,
                                       fotos: fotos, fondo: vista.clearColor)

        // --- pipeline normal: vs_main + fs_main (Blinn-Phong) ---
        let desc = MTLRenderPipelineDescriptor()
        desc.vertexFunction =
            library
            .makeFunction(
                name: "vs_main"
            )
        desc.fragmentFunction =
            library
            .makeFunction(
                name: "fs_main"
            )
        desc.vertexDescriptor = VertexLayout.metal
        desc
            .colorAttachments[0].pixelFormat = vista.colorPixelFormat
        desc.depthAttachmentPixelFormat = vista.depthStencilPixelFormat
        self.pipelineState =
            try! device
            .makeRenderPipelineState(
                descriptor: desc
            )

        let depthDesc = MTLDepthStencilDescriptor()
        depthDesc.depthCompareFunction = .less
        depthDesc.isDepthWriteEnabled = true
        self.depthState =
            device
            .makeDepthStencilState(
                descriptor: depthDesc
            )!

        self.fotosLeidas = Self.tomarFotos(commandQueue: commandQueue, pasada: pasadaFotos,
                                           escena: escena, fotos: fotos)
        self.rangoDistancias = fotosLeidas.rangoDistancias()
        self.miniaturas = Miniaturas(device: device, library: library, vista: vista)

        // La pieza: todo lo que depende solo de las fotos se calcula aquí, una vez.
        self.rayos = escena.camaraC.rayos(n: fotos.tamaño)
        self.pivotes = Pivotes(distancias: fotosLeidas.distancia, ids: fotosLeidas.id)
        self.geometria = GeometriaPieza.calcular(rayos: rayos, origen: escena.camaraC.posicion,
                                                 distancias: fotosLeidas.distancia, ids: fotosLeidas.id,
                                                 parametros: parametros, pivotes: pivotes)
        self.pieza = Pieza(device: device, library: library, n: fotos.tamaño,
                           ids: fotosLeidas.id, geometria: geometria)
        self.pipelinePieza = pieza.crearPipeline(formatoColor: vista.colorPixelFormat,
                                                 formatoProfundidad: vista.depthStencilPixelFormat)
        super.init()

        #if DEBUG
        autoprueba = Autoprueba.revisarFotos(fotosLeidas)
        Autoprueba.imprimir(autoprueba)
        #endif
    }

    /// Toma las fotos desde C una sola vez, antes del primer frame.
    ///
    /// La escena y C no cambian, así que repetirlas en cada frame sería
    /// trabajo perdido. Usa un command buffer propio y espera a que la GPU
    /// termine (`waitUntilCompleted`): así, al volver, las texturas ya tienen
    /// los datos y la CPU las puede leer. Esperar bloquea el hilo, pero pasa
    /// una vez al arrancar y la pasada es pequeña.
    ///
    /// Es `static` para poder llamarla dentro de `init` antes de
    /// `super.init()`, cuando todavía no se puede usar `self`.
    private static func tomarFotos(commandQueue: MTLCommandQueue, pasada: PasadaFotos,
                                   escena: Escena, fotos: FotosC) -> FotosLeidas {
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            fatalError("No se pudo crear el command buffer de las fotos")
        }
        commandBuffer.label = "Fotos C (arranque)"
        pasada.tomar(escena: escena, fotos: fotos, commandBuffer: commandBuffer)
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return fotos.leer()
    }

    func mtkView(
        _ view: MTKView,
        drawableSizeWillChange size: CGSize
    ) {
        guard size.height > 0 else { return }   // ventana minimizada: alto 0, evitar dividir por 0
        aspect = Float(size.width / size.height)
    }

    func draw(
        in view: MTKView
    ) {

        guard let drawable = view.currentDrawable,
            let descriptor = view.currentRenderPassDescriptor,
            let commandBuffer = commandQueue.makeCommandBuffer()
        else {
            return
        }

        #if DEBUG
        // Solo para verlas en la captura de GPU (ver `fotosEnCadaFrame`).
        // Un command buffer admite un encoder abierto a la vez, así que el
        // del visor se abre después.
        if fotosEnCadaFrame {
            pasadaFotos.tomar(escena: escena, fotos: fotos, commandBuffer: commandBuffer)
        }
        #endif

        guard let encoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: descriptor
        ) else {
            return
        }
        encoder.label = "Visor"
        
        let viewProjection = camaraVisor.matrizProyeccion(aspect: aspect)
            * camaraVisor.matrizVista()
        
        var scene = SceneUniforms(
            lightPosition: escena.luz,
            cameraPosition: camaraVisor.posicion
        )
        encoder
            .setFragmentBytes(
                &scene,
                length: MemoryLayout<SceneUniforms>.stride,
                index: 2
            )
        
        encoder.setDepthStencilState(depthState)

        switch modo {
        case .pieza:
            encoder.setRenderPipelineState(pipelinePieza)
            pieza.dibujar(encoder: encoder, viewProjection: viewProjection, colorFoto: fotos.color)
        case .escena:
            encoder.setRenderPipelineState(pipelineState)
            dibujarEscena(encoder: encoder, viewProjection: viewProjection)
        }

        // Al final, porque cambia el viewport del encoder.
        let escala = view.bounds.width > 0 ? view.drawableSize.width / view.bounds.width : 1
        miniaturas.dibujar(encoder: encoder, fotos: fotos, rango: rangoDistancias,
                           escala: escala, altoPixeles: view.drawableSize.height)

        encoder
            .endEncoding()
        commandBuffer
            .present(
                drawable
            )
        commandBuffer
            .commit()
    }
    
    /// Dibuja los objetos de la escena con Blinn-Phong, cada uno con sus
    /// uniforms. Es la misma idea que el loop de `PasadaFotos.tomar`
    /// (deuda conocida: está duplicado).
    private func dibujarEscena(encoder: MTLRenderCommandEncoder, viewProjection: simd_float4x4) {
        for obj in escena.objetos {
            var uniforms = Uniforms(modelMatrix: obj.modelo,
                                    mvpMatrix: viewProjection * obj.modelo,
                                    baseColor: obj.color,
                                    shininess: 32,
                                    objetoID: UInt32(obj.id))
            encoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)
            encoder.setFragmentBytes(&uniforms, length: MemoryLayout<Uniforms>.stride, index: 1)

            let vb = obj.malla.vertexBuffers[0]
            encoder.setVertexBuffer(vb.buffer, offset: vb.offset, index: 0)

            for submesh in obj.malla.submeshes {
                encoder.drawIndexedPrimitives(type: submesh.primitiveType,
                                              indexCount: submesh.indexCount,
                                              indexType: submesh.indexType,
                                              indexBuffer: submesh.indexBuffer.buffer,
                                              indexBufferOffset: submesh.indexBuffer.offset)
            }
        }
    }

    /// Traduce un gesto a la cámara del visor. Las sensibilidades viven aquí
    /// y no en VistaMetal, que solo sabe de dispositivos.
    func aplicar(_ gesto: GestoCamara) {
        switch gesto {
        case let .orbitar(dx, dy):
            let radianesPorPunto: Float = 0.01
            camaraVisor.orbitar(yaw: -Float(dx) * radianesPorPunto,
                                pitch: Float(dy) * radianesPorPunto)
        case let .zoom(magnificacion):
            // Fuera de la esfera (radio 1) y dentro del far plane (20).
            camaraVisor.acercar(magnificacion: Float(magnificacion), radio: 1.5...15)
        }
    }
}
