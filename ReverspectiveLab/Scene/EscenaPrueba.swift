//  EscenaPrueba.swift — ReverspectiveLab
//  Fábrica de la escena de prueba con distancias conocidas (para el paso 5).
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

enum EscenaPrueba {

    static func crear(device: MTLDevice) throws -> Escena {
        let allocator = MTKMeshBufferAllocator(device: device)

        func aMetal(_ mdl: MDLMesh) throws -> MTKMesh {
            mdl.vertexDescriptor = VertexLayout.modelIO   // reordena los datos al formato común
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

        let objetos = [
            ObjetoEscena(nombre: "esfera", id: 1, malla: try aMetal(esfera),
                         modelo: traslacion([0, 0, 0]),         // toca el piso en y = -1
                         color: [1.0, 0.5, 0.0, 1.0]),
            ObjetoEscena(nombre: "cubo",   id: 2, malla: try aMetal(cubo),
                         modelo: traslacion([1.8, -0.5, -1]),   // apoyado en el piso, más atrás
                         color: [1.0, 0.0, 1.0, 1.0]),
            ObjetoEscena(nombre: "piso",   id: 3, malla: try aMetal(piso),
                         modelo: traslacion([0, -1, 0]),
                         color: [1.0, 1.0, 1.0, 1.0]),
        ]

        // La foto es cuadrada (256×256), así que esta cámara siempre usa aspecto 1.
        let camaraC = Camara(posicion: [0, 0, 5], objetivo: [0, 0, 0], fovGrados: 45)

        return Escena(objetos: objetos, camaraC: camaraC, luz: [3, 5, 4])
    }

    static func traslacion(_ t: SIMD3<Float>) -> simd_float4x4 {
        var m = matrix_identity_float4x4
        m.columns.3 = SIMD4<Float>(t, 1)
        return m
    }
}
