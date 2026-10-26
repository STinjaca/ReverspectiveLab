//
//  Render.swift
//  ReverspectiveLab
//
//  Created by Santi T on 25/10/26.
//

import MetalKit
import simd

/// Uniforms por entidad, subidos una vez por objeto en el loop de draw.
///
/// `modelMatrix` viaja aparte de `mvpMatrix` porque el fragment shader la
/// necesita sin proyectar — para pasar normales y posición a world space en
/// `vs_main` sin volver a calcular nada del lado de la GPU.
struct Uniforms {
    var modelMatrix: simd_float4x4
    var mvpMatrix: simd_float4x4
    var baseColor: SIMD4<Float>
    var shininess: Float
}

/// Uniforms globales de la escena, subidos una sola vez por frame (buffer
/// distinto al de `Uniforms`, índice 2) — no dependen de qué entidad se esté
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
    
    var cursorPosition: CGPoint = .zero

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
    
    func posCamara()-> SIMD3<Float>{
        let y = camaraVisor.posicion[1]
        let x = camaraVisor.posicion[0]
        let z = camaraVisor.posicion[2]
        
        let R = pow(x, 2) + pow(y, 2) + pow(z, 2)
        
        if(R == 0){
            return SIMD3<Float>(0.0, 0.0, 0.0)
        }
        
        let tetha = atan2(y, x)
        let phi = acos(z / R)
        
        let tetha_nuevo = Float(cursorPosition.x) + tetha
        let phi_tem = Float(cursorPosition.y) + phi
        
        // Limitar phi para evitar el efecto "Gimbal Lock" en los polos (+-90 grados)
        let phi_nuevo = max(min(phi_tem, .pi/2 - 0.001), -.pi/2 + 0.001)
        
        // Re-proyectar a coordenadas cartesianas XYZ
        let x_nueva = R * cos(phi_nuevo) * cos(tetha_nuevo)
        let y_nueva = R * cos(phi_nuevo) * sin(tetha_nuevo)
        let z_nueva = R * sin(phi_nuevo)
        
        let result = SIMD3<Float>(x_nueva, y_nueva, z_nueva)
        return result
    }
    
}
