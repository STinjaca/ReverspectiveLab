//  ObjetoEscena.swift — ReverspectiveLab
//  Qué es un objeto de la escena y qué es una escena.

import MetalKit
import simd

struct ObjetoEscena {
    let nombre: String
    let id: UInt16              // lo que se escribe en la foto de ID (0 = fondo)
    let malla: MTKMesh
    let modelo: simd_float4x4   // matriz del objeto al mundo
    let color: SIMD4<Float>     // color base para Blinn-Phong
}

struct Escena {
    let objetos: [ObjetoEscena]
    let camaraC: Camara         // la cámara fija que toma las fotos
    let luz: SIMD3<Float>       // luz puntual, la misma para las fotos y la pantalla
}
