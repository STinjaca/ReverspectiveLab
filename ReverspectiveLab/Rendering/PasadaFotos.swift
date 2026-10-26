//
//  PasadaFotos.swift
//  ReverspectiveLab
//
//  Created by Santi T on 25/10/26.
//

import MetalKit
import simd

/// Sabe tomar las tres fotos desde la cámara C (color, distancia, ID) en una
/// sola pasada. El Renderer solo decide cuándo.
final class PasadaFotos {
    private let pipelineState: MTLRenderPipelineState
    private let depthState: MTLDepthStencilState
    private let fondo: MTLClearColor

    /// - Parameter fondo: color con que se borra la foto de color; el mismo
    ///   del visor, para que las dos imágenes se vean iguales.
    init(device: MTLDevice, library: MTLLibrary, fotos: FotosC, fondo: MTLClearColor) {
        // Pipeline propio: otro fragment shader y otros formatos de salida.
        let desc = MTLRenderPipelineDescriptor()
        desc.label = "Fotos C"
        desc.vertexFunction = library.makeFunction(name: "vs_main")
        desc.fragmentFunction = library.makeFunction(name: "fs_fotos")
        desc.vertexDescriptor = VertexLayout.metal
        // Los formatos se leen de las texturas para no escribirlos dos veces.
        desc.colorAttachments[0].pixelFormat = fotos.color.pixelFormat
        desc.colorAttachments[1].pixelFormat = fotos.distancia.pixelFormat
        desc.colorAttachments[2].pixelFormat = fotos.id.pixelFormat
        desc.depthAttachmentPixelFormat = fotos.profundidad.pixelFormat
        self.pipelineState = try! device.makeRenderPipelineState(descriptor: desc)

        let depthDesc = MTLDepthStencilDescriptor()
        depthDesc.depthCompareFunction = .less
        depthDesc.isDepthWriteEnabled = true
        self.depthState = device.makeDepthStencilState(descriptor: depthDesc)!

        self.fondo = fondo
    }

    /// Deja escritas en `commandBuffer` las órdenes para tomar las fotos.
    /// No hace `present`: esto no va a la pantalla.
    func tomar(escena: Escena, fotos: FotosC, commandBuffer: MTLCommandBuffer) {
        // Sin vista no hay currentRenderPassDescriptor: se arma a mano.
        let pasada = MTLRenderPassDescriptor()
        configurar(pasada.colorAttachments[0], textura: fotos.color, borrarCon: fondo)
        // 0 significa "aquí no hay nada": distancia 0 e ID 0 = fondo.
        configurar(pasada.colorAttachments[1], textura: fotos.distancia,
                   borrarCon: MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0))
        configurar(pasada.colorAttachments[2], textura: fotos.id,
                   borrarCon: MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0))
        pasada.depthAttachment.texture = fotos.profundidad
        pasada.depthAttachment.loadAction = .clear
        pasada.depthAttachment.clearDepth = 1.0        // lo más lejos
        pasada.depthAttachment.storeAction = .dontCare  // no se usa después

        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pasada) else { return }
        encoder.label = "Fotos C"

        // La foto es cuadrada: aspecto 1.
        let camara = escena.camaraC
        let viewProjection = camara.matrizProyeccion(aspect: 1) * camara.matrizVista()

        // cameraPosition = C: desde ahí se mide la distancia.
        var scene = SceneUniforms(lightPosition: escena.luz, cameraPosition: camara.posicion)
        encoder.setFragmentBytes(&scene, length: MemoryLayout<SceneUniforms>.stride, index: 2)

        encoder.setRenderPipelineState(pipelineState)
        encoder.setDepthStencilState(depthState)

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

        encoder.endEncoding()
    }

    /// Borrar al empezar con `borrarCon`, guardar al terminar.
    private func configurar(_ imagen: MTLRenderPassColorAttachmentDescriptor,
                            textura: MTLTexture, borrarCon color: MTLClearColor) {
        imagen.texture = textura
        imagen.loadAction = .clear
        imagen.clearColor = color
        imagen.storeAction = .store
    }
}
