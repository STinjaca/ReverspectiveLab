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
}

/// Uniforms globales de la escena, subidos una sola vez por frame (buffer
/// distinto al de `Uniforms`, índice 2) — no dependen de qué objeto se esté
/// dibujando, así que no tiene sentido repetirlos por draw call.
struct SceneUniforms {
    var lightPosition: SIMD3<Float>
    var cameraPosition: SIMD3<Float>
}

final class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let commandQueue: MTLCommandQueue
    
    let escena: Escena

    /// Cámara para mirar la escena en pantalla. Es independiente de
    /// `escena.camaraC`, que se queda fija para tomar las fotos.
    var camaraVisor = Camara(posicion: [10, 0, 7], objetivo: [0, 0, 0])


    // Pipeline "normal": Blinn-Phong real, escribe y prueba profundidad.
    let pipelineState: MTLRenderPipelineState
    let depthState: MTLDepthStencilState

    let lightPosition = SIMD3<Float>(
        3,
        5,
        4
    )
    
    var aspect: Float = 1
    
    /// Arrastre acumulado del mouse, en puntos. Solo importa cuánto cambió
    /// desde la última vez: ese incremento es lo que gira la cámara.
    var arrastre: CGSize = .zero {
        didSet {
            let radianesPorPunto: Float = 0.01
            camaraVisor.orbitar(
                yaw: -Float(arrastre.width - oldValue.width) * radianesPorPunto,
                pitch: Float(arrastre.height - oldValue.height) * radianesPorPunto
            )
        }
    }

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
        super.init()
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
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: descriptor
            )
        else {
            return
        }
        
        let viewProjection = camaraVisor.matrizProyeccion(aspect: aspect)
            * camaraVisor.matrizVista()
        
        var scene = SceneUniforms(
            lightPosition: lightPosition,
            cameraPosition: camaraVisor.posicion
        )
        encoder
            .setFragmentBytes(
                &scene,
                length: MemoryLayout<SceneUniforms>.stride,
                index: 2
            )
        
        encoder.setRenderPipelineState(pipelineState)
        encoder.setDepthStencilState(depthState)
        
        
        for obj in escena.objetos {
            
            var uniforms = Uniforms(
                modelMatrix: obj.modelo,
                mvpMatrix: viewProjection * obj.modelo,
                baseColor: colorPara(id: obj.id),
                shininess: 32
            )
            
            encoder.setVertexBytes(
                &uniforms,
                length: MemoryLayout<Uniforms>.stride,
                index: 1
            )
            
            encoder.setFragmentBytes(
                &uniforms,
                length: MemoryLayout<Uniforms>.stride,
                index: 1
            )
            
            let vb = obj.malla.vertexBuffers[0]
            encoder.setVertexBuffer(vb.buffer, offset: vb.offset, index: 0)


            
            for submesh in obj.malla.submeshes {
                
                encoder.drawIndexedPrimitives(
                    type: submesh.primitiveType,
                    indexCount: submesh.indexCount,
                    indexType:  submesh.indexType,
                    indexBuffer: submesh.indexBuffer.buffer,
                    indexBufferOffset: submesh.indexBuffer.offset
                )
            }
        }

        encoder
            .endEncoding()
        commandBuffer
            .present(
                drawable
            )
        commandBuffer
            .commit()
    }
    
    func colorPara(id: UInt16) -> SIMD4<Float> {
        switch id {
        case 1:
            return SIMD4<Float>(1.0, 0.5, 0.0, 1.0)
        case 2:
            return SIMD4<Float>(1.0, 0.0, 1.0, 1.0)
        default:
            return SIMD4<Float>(1.0, 1.0, 1.0, 1.0)
        }
    }
}
