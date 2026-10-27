//  Pieza.swift — ReverspectiveLab
//  La pieza invertida en la GPU: la rejilla de un vértice por píxel, con
//  las posiciones que calcula el núcleo y la foto de color como textura.

import MetalKit
import simd

/// Lo que no cambia de un vértice mientras no cambien las fotos.
/// Tiene que coincidir con los atributos 1 y 2 de `PiezaIn` en Metal.
struct VerticeFijo {
    var uv: SIMD2<Float>    // centro del píxel en la foto de color
    var valido: Float       // 1 = objeto, 0 = fondo
}

/// Interruptores de `fs_pieza` (buffer 0 del fragment). Tiene que medir
/// lo mismo que el struct de Metal (8 bytes): si se cambia uno, se cambia
/// el otro en el mismo commit.
struct PiezaUniforms {
    var resaltarParedes: UInt32     // 0 o 1
    var marcarTraseras: UInt32      // 0 o 1
}

final class Pieza {

    /// Índices del buffer de vértices en el vertex shader. El 2 es para la
    /// `viewProjection` (`setVertexBytes`).
    static let bufferPosiciones = 0
    static let bufferFijo = 1
    static let bufferViewProjection = 2

    /// Dos buffers por vértice: lo dinámico en el 0 y lo fijo en el 1.
    ///
    /// Van separados porque cambian a ritmos distintos: las posiciones y la
    /// marca de pared se recalculan con cada cambio de estrategia o de `s`;
    /// la UV y la marca de válido solo si cambian las fotos. Así se sube
    /// solo lo que cambió.
    ///
    /// En el buffer 0 cada vértice es un `SIMD4<Float>`: xyz = posición y
    /// w = marca de pared. Una posición sola (`SIMD3`) ya ocupaba 16 bytes
    /// por la alineación, así que la marca va en ese hueco, gratis.
    static let descriptorVertices: MTLVertexDescriptor = {
        let d = MTLVertexDescriptor()
        d.attributes[0].format = .float3
        d.attributes[0].offset = 0
        d.attributes[0].bufferIndex = bufferPosiciones
        d.attributes[3].format = .float
        d.attributes[3].offset = 3 * MemoryLayout<Float>.stride   // la w
        d.attributes[3].bufferIndex = bufferPosiciones
        d.layouts[bufferPosiciones].stride = MemoryLayout<SIMD4<Float>>.stride

        d.attributes[1].format = .float2
        d.attributes[1].offset = MemoryLayout<VerticeFijo>.offset(of: \.uv)!
        d.attributes[1].bufferIndex = bufferFijo
        d.attributes[2].format = .float
        d.attributes[2].offset = MemoryLayout<VerticeFijo>.offset(of: \.valido)!
        d.attributes[2].bufferIndex = bufferFijo
        d.layouts[bufferFijo].stride = MemoryLayout<VerticeFijo>.stride
        return d
    }()

    private let device: MTLDevice
    private let library: MTLLibrary
    private(set) var posiciones: MTLBuffer
    private let fijo: MTLBuffer
    private let indices: MTLBuffer
    private let cantidadIndices: Int

    /// Arma los buffers fijos (UV, válido, índices) y unas posiciones
    /// iniciales.
    ///
    /// - Parameters:
    ///   - ids: la foto de ID, para la marca de válido.
    ///   - geometria, paredes: posiciones y marcas iniciales (ver `actualizar`).
    init(device: MTLDevice, library: MTLLibrary, n: Int, ids: [UInt16],
         geometria: GeometriaPieza, paredes: Paredes) {
        self.device = device
        self.library = library

        var fijos: [VerticeFijo] = []
        fijos.reserveCapacity(n * n)
        for j in 0..<n {
            for i in 0..<n {
                let uv = SIMD2<Float>((Float(i) + 0.5) / Float(n), (Float(j) + 0.5) / Float(n))
                fijos.append(VerticeFijo(uv: uv, valido: ids[j * n + i] != 0 ? 1 : 0))
            }
        }
        self.fijo = device.makeBuffer(bytes: fijos,
                                      length: fijos.count * MemoryLayout<VerticeFijo>.stride,
                                      options: .storageModeShared)!
        fijo.label = "Pieza: UV y válido"

        let rejilla = Rejilla.indices(n: n)
        self.indices = device.makeBuffer(bytes: rejilla,
                                         length: rejilla.count * MemoryLayout<UInt32>.stride,
                                         options: .storageModeShared)!
        indices.label = "Pieza: índices"
        self.cantidadIndices = rejilla.count

        self.posiciones = Self.crearBufferPosiciones(device: device, geometria: geometria, paredes: paredes)
    }

    /// Cambia las posiciones de la pieza por las de `geometria`, y las
    /// marcas de pared por las de `paredes`.
    ///
    /// Crea un buffer nuevo en vez de escribir encima del viejo: la GPU
    /// puede estar todavía dibujando un frame anterior con el buffer viejo,
    /// y escribirle encima mientras lo lee daría un frame mezclado. El
    /// command buffer de ese frame retiene el buffer viejo hasta terminar;
    /// después se libera solo. Es 1 MB y solo pasa cuando cambia la
    /// inversión, no en cada frame.
    func actualizar(_ geometria: GeometriaPieza, paredes: Paredes) {
        posiciones = Self.crearBufferPosiciones(device: device, geometria: geometria, paredes: paredes)
    }

    /// Junta posición (xyz) y marca de pared (w) de cada vértice en un buffer.
    ///
    /// Escribe directo en la memoria del buffer en vez de armar primero un
    /// arreglo de Swift y copiarlo: con N = 1024 son un millón de vértices,
    /// y el arreglo intermedio costaba más que todo el resto del recálculo
    /// en Debug. Se puede porque el buffer es `.shared`: `contents()` es un
    /// puntero a la memoria que también lee la GPU.
    private static func crearBufferPosiciones(device: MTLDevice, geometria: GeometriaPieza,
                                              paredes: Paredes) -> MTLBuffer {
        let cantidad = geometria.posiciones.count
        let buffer = device.makeBuffer(length: cantidad * MemoryLayout<SIMD4<Float>>.stride,
                                       options: .storageModeShared)!
        buffer.label = "Pieza: posiciones"
        // `bindMemory` dice "trata estos bytes como un arreglo de SIMD4<Float>".
        let vertices = buffer.contents().bindMemory(to: SIMD4<Float>.self, capacity: cantidad)
        for k in 0..<cantidad {
            let p = geometria.posiciones[k]
            vertices[k] = SIMD4<Float>(p.x, p.y, p.z, paredes.marcaVertice[k])
        }
        return buffer
    }

    /// Un pipeline para dibujar la pieza en un destino con estos formatos.
    ///
    /// Se necesitan dos: uno para la pantalla (bgra8Unorm) y otro para la
    /// autoprueba, que dibuja en una textura como la foto de color
    /// (rgba8Unorm). Los shaders y los buffers son los mismos.
    ///
    func crearPipeline(formatoColor: MTLPixelFormat, formatoProfundidad: MTLPixelFormat) -> MTLRenderPipelineState {
        let desc = MTLRenderPipelineDescriptor()
        desc.label = "Pieza"
        desc.vertexFunction = library.makeFunction(name: "vs_pieza")
        desc.fragmentFunction = library.makeFunction(name: "fs_pieza")
        desc.vertexDescriptor = Self.descriptorVertices
        desc.colorAttachments[0].pixelFormat = formatoColor
        desc.depthAttachmentPixelFormat = formatoProfundidad
        return try! device.makeRenderPipelineState(descriptor: desc)
    }

    /// Dibuja la pieza en `encoder`, que ya tiene puestos el pipeline (de
    /// `crearPipeline`) y el depth state.
    ///
    /// Una sola llamada para toda la malla: las tiras de la rejilla van
    /// separadas por el índice de reinicio, que Metal respeta solo.
    ///
    /// Sin cull (`.none`, que ya es el valor por defecto; se pide explícito
    /// para que se lea): las caras traseras no se esconden. Al girar, parte
    /// de la pieza se ve "por detrás", y eso es información para R6, no
    /// algo que ocultar.
    ///
    /// Cara frontal = antihoraria (`.counterClockwise`), que es como se ven
    /// los triángulos de la rejilla desde C. Metal por defecto toma la
    /// horaria; sin este cambio, `[[front_facing]]` diría lo contrario.
    func dibujar(encoder: MTLRenderCommandEncoder, viewProjection: simd_float4x4,
                 colorFoto: MTLTexture, interruptores: PiezaUniforms) {
        encoder.pushDebugGroup("Pieza")
        encoder.setCullMode(.none)
        encoder.setFrontFacing(.counterClockwise)
        encoder.setVertexBuffer(posiciones, offset: 0, index: Self.bufferPosiciones)
        encoder.setVertexBuffer(fijo, offset: 0, index: Self.bufferFijo)
        var vp = viewProjection
        encoder.setVertexBytes(&vp, length: MemoryLayout<simd_float4x4>.stride, index: Self.bufferViewProjection)
        encoder.setFragmentTexture(colorFoto, index: 0)
        var u = interruptores
        encoder.setFragmentBytes(&u, length: MemoryLayout<PiezaUniforms>.stride, index: 0)
        encoder.drawIndexedPrimitives(type: .triangleStrip, indexCount: cantidadIndices,
                                      indexType: .uint32, indexBuffer: indices, indexBufferOffset: 0)
        encoder.popDebugGroup()
    }
}
