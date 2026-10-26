//  VertexLayout.swift — ReverspectiveLab
//  Formato de los vértices, en un solo lugar: lo usan las mallas de la
//  escena (ModelIO) y el pipeline (Metal).
//
//  En el shader: [[attribute(0)]] = posición, [[attribute(1)]] = normal.

import MetalKit
import ModelIO

enum VertexLayout {

    /// Posición (float3) + normal (float3), intercaladas en el buffer 0.
    static let modelIO: MDLVertexDescriptor = {
        let d = MDLVertexDescriptor()
        d.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                             format: .float3, offset: 0, bufferIndex: 0)
        d.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                             format: .float3, offset: 12, bufferIndex: 0)
        d.layouts[0] = MDLVertexBufferLayout(stride: 24)
        return d
    }()

    /// El mismo formato traducido a Metal, para `MTLRenderPipelineDescriptor`.
    static let metal: MTLVertexDescriptor = MTKMetalVertexDescriptorFromModelIO(modelIO)!
}
