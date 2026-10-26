//  Escena.swift — ReverspectiveLab
//  Escena de prueba con distancias conocidas (para el paso 5).
//
//  Mundo: Y hacia arriba. La cámara C está en (0, 0, 5) mirando al origen.
//  IDs: 0 = fondo (nada), 1 = esfera, 2 = cubo, 3 = piso.
//
//  Valor esperado en el paso 5: el píxel del centro de la foto cae en la
//  esfera (radio 1, centro en el origen), así que su distancia a C es
//  5 - 1 = 4.0 (más o menos 0.01 porque la esfera está hecha de triángulos).

import MetalKit
import ModelIO
import simd

struct ObjetoEscena {
    let nombre: String
    let id: UInt16              // lo que escribirás en la foto de ID
    let malla: MTKMesh
    let modelo: simd_float4x4   // matriz del objeto al mundo
}

enum EscenaPrueba {

    static let posicionCamara = SIMD3<Float>(10, 0, 0)
    static let objetivoCamara = SIMD3<Float>(0, 0, 0)
    static let arribaCamara   = SIMD3<Float>(0, 1, 0)
    static let fovVerticalGrados: Float = 45   // la foto es cuadrada: aspecto = 1

    /// Formato de los vértices: posición (float3) + normal (float3).
    /// Usa este mismo descriptor para crear el pipeline:
    ///   MTKMetalVertexDescriptorFromModelIO(EscenaPrueba.descriptorVertices)
    /// En el shader: [[attribute(0)]] = posición, [[attribute(1)]] = normal.
    static let descriptorVertices: MDLVertexDescriptor = {
        let d = MDLVertexDescriptor()
        d.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition,
                                             format: .float3, offset: 0, bufferIndex: 0)
        d.attributes[1] = MDLVertexAttribute(name: MDLVertexAttributeNormal,
                                             format: .float3, offset: 12, bufferIndex: 0)
        d.layouts[0] = MDLVertexBufferLayout(stride: 24)
        return d
    }()

    static func crear(device: MTLDevice) throws -> [ObjetoEscena] {
        let allocator = MTKMeshBufferAllocator(device: device)

        func aMetal(_ mdl: MDLMesh) throws -> MTKMesh {
            mdl.vertexDescriptor = descriptorVertices   // reordena los datos al formato de arriba
            return try MTKMesh(mesh: mdl, device: device)
        }

        // Esfera de radio 1 (extent = diámetro)
        let esfera = MDLMesh(sphereWithExtent: [2, 2, 2], segments: [48, 48],
                             inwardNormals: false, geometryType: .triangles,
                             allocator: allocator)

        // Cubo de lado 1
        let cubo = MDLMesh(boxWithExtent: [1, 1, 1], segments: [1, 1, 1],
                           inwardNormals: false, geometryType: .triangles,
                           allocator: allocator)

        // Piso de 8 × 8 en el plano XZ (normal hacia +Y)
        let piso = MDLMesh(planeWithExtent: [8, 0, 8], segments: [1, 1],
                           geometryType: .triangles, allocator: allocator)

        return [
            ObjetoEscena(nombre: "esfera", id: 1, malla: try aMetal(esfera),
                         modelo: traslacion([0, 0, 0])),        // toca el piso en y = -1
            ObjetoEscena(nombre: "cubo",   id: 2, malla: try aMetal(cubo),
                         modelo: traslacion([1.8, -0.5, -1])),  // apoyado en el piso, más atrás
            ObjetoEscena(nombre: "piso",   id: 3, malla: try aMetal(piso),
                         modelo: traslacion([0, -1, 0])),
        ]
    }

    static func traslacion(_ t: SIMD3<Float>) -> simd_float4x4 {
        var m = matrix_identity_float4x4
        m.columns.3 = SIMD4<Float>(t, 1)
        return m
    }
}
