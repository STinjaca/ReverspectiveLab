//  Miniaturas.swift — ReverspectiveLab
//  Dibuja las tres fotos de C (color, distancia, ID) como miniaturas en una
//  franja abajo a la izquierda del visor, encima de la escena.

import MetalKit
import simd

/// Lo que recibe `fs_miniatura` en el buffer 0. Tiene que medir lo mismo
/// que el struct de Metal (12 bytes): si se cambia uno, se cambia el otro
/// en el mismo commit.
struct MiniaturaUniforms {
    var tipo: UInt32    // 0 = color, 1 = distancia, 2 = ID
    var dMin: Float
    var dMax: Float
}

final class Miniaturas {

    /// Medidas en puntos de pantalla (no en píxeles). Las usa también
    /// `ContentView` para poner las etiquetas encima de cada miniatura.
    static let lado: CGFloat = 160
    static let margen: CGFloat = 12
    static let separacion: CGFloat = 12
    static let nombres = ["Color", "Distancia", "ID"]

    private let pipelineState: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState

    /// - Parameters:
    ///   - vista: de ella salen los formatos de color y profundidad, que
    ///     tienen que coincidir con los del encoder del visor donde se dibuja.
    init(device: MTLDevice, library: MTLLibrary, vista: MTKView) {
        let desc = MTLRenderPipelineDescriptor()
        desc.label = "Miniaturas"
        desc.vertexFunction = library.makeFunction(name: "vs_miniatura")
        desc.fragmentFunction = library.makeFunction(name: "fs_miniatura")
        // Sin vertexDescriptor: el vertex shader no lee ningún buffer.
        desc.colorAttachments[0].pixelFormat = vista.colorPixelFormat
        desc.depthAttachmentPixelFormat = vista.depthStencilPixelFormat
        self.pipelineState = try! device.makeRenderPipelineState(descriptor: desc)

        // Las miniaturas van encima de todo: ni se comparan con la
        // profundidad de la escena ni la modifican.
        let depthDesc = MTLDepthStencilDescriptor()
        depthDesc.depthCompareFunction = .always
        depthDesc.isDepthWriteEnabled = false
        self.depthState = device.makeDepthStencilState(descriptor: depthDesc)!
    }

    /// Dibuja las tres miniaturas en `encoder`, el mismo del visor.
    ///
    /// Cambia el viewport del encoder y no lo restaura, así que tiene que
    /// ser lo último que se dibuja en él.
    ///
    /// - Parameters:
    ///   - escala: píxeles por punto (2 en una pantalla Retina). El viewport
    ///     se da en píxeles y las medidas de arriba están en puntos.
    ///   - altoPixeles: alto del drawable en píxeles; el viewport cuenta y
    ///     desde arriba, y la franja va abajo.
    ///   - rango: distancias mínima y máxima de los píxeles válidos, para
    ///     normalizar la miniatura de distancia.
    func dibujar(encoder: MTLRenderCommandEncoder, fotos: FotosC,
                 rango: ClosedRange<Float>, escala: CGFloat, altoPixeles: CGFloat) {
        encoder.pushDebugGroup("Miniaturas")
        encoder.setRenderPipelineState(pipelineState)
        encoder.setDepthStencilState(depthState)
        encoder.setFragmentTexture(fotos.color, index: 0)
        encoder.setFragmentTexture(fotos.distancia, index: 1)
        encoder.setFragmentTexture(fotos.id, index: 2)

        let lado = Self.lado * escala
        let y = altoPixeles - (Self.margen + Self.lado) * escala
        for tipo in 0..<3 {
            let x = (Self.margen + CGFloat(tipo) * (Self.lado + Self.separacion)) * escala
            encoder.setViewport(MTLViewport(originX: Double(x), originY: Double(y),
                                            width: Double(lado), height: Double(lado),
                                            znear: 0, zfar: 1))
            var u = MiniaturaUniforms(tipo: UInt32(tipo), dMin: rango.lowerBound,
                                      dMax: rango.upperBound)
            encoder.setFragmentBytes(&u, length: MemoryLayout<MiniaturaUniforms>.stride, index: 0)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        }
        encoder.popDebugGroup()
    }
}
