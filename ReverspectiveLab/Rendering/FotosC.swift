//
//  FotosC.swift
//  ReverspectiveLab
//
//  Created by Santi T on 25/10/26.
//

import Metal

/// Las texturas donde la cámara C toma sus fotos: color, distancia e ID,
/// más la de profundidad que necesita el depth test. Todas cuadradas y del
/// mismo tamaño.
struct FotosC {
    let tamaño: Int
    let color: MTLTexture
    let distancia: MTLTexture
    let id: MTLTexture
    let profundidad: MTLTexture

    init(device: MTLDevice, tamaño: Int = 256) {
        self.tamaño = tamaño
        self.color = Self.crearTextura(device: device, formato: .rgba8Unorm, tamaño: tamaño,
                                       usage: [.renderTarget, .shaderRead], storage: .shared,
                                       nombre: "Foto color")
        self.distancia = Self.crearTextura(device: device, formato: .r32Float, tamaño: tamaño,
                                           usage: [.renderTarget, .shaderRead], storage: .shared,
                                           nombre: "Foto distancia")
        self.id = Self.crearTextura(device: device, formato: .r16Uint, tamaño: tamaño,
                                    usage: [.renderTarget, .shaderRead], storage: .shared,
                                    nombre: "Foto ID")
        // La profundidad solo la usa la GPU, y los formatos de profundidad
        // no aceptan .shared.
        self.profundidad = Self.crearTextura(device: device, formato: .depth32Float, tamaño: tamaño,
                                             usage: [.renderTarget], storage: .private,
                                             nombre: "Foto profundidad")
    }

    /// Copia las tres fotos a arreglos de Swift para usarlas en la CPU.
    ///
    /// Solo es válido después de que la GPU terminó de tomarlas
    /// (`waitUntilCompleted`); si no, se leen ceros o datos viejos. Funciona
    /// sin copias intermedias porque las texturas están en `.shared`: en un
    /// chip Apple la CPU y la GPU comparten la misma memoria.
    func leer() -> FotosLeidas {
        FotosLeidas(tamaño: tamaño,
                    color: Self.copiar(color, como: SIMD4<UInt8>.self),
                    distancia: Self.copiar(distancia, como: Float.self),
                    id: Self.copiar(id, como: UInt16.self))
    }

    /// Copia una textura entera a un arreglo de `T`, fila por fila con la
    /// fila 0 arriba (el mismo orden de la textura). `T` tiene que medir
    /// lo mismo que un píxel del formato: 4 bytes para rgba8Unorm, 4 para
    /// r32Float y 2 para r16Uint.
    private static func copiar<T>(_ textura: MTLTexture, como _: T.Type) -> [T] {
        let ancho = textura.width, alto = textura.height
        let bytesPorPixel = MemoryLayout<T>.stride
        return [T](unsafeUninitializedCapacity: ancho * alto) { destino, cuantos in
            textura.getBytes(destino.baseAddress!,
                             bytesPerRow: ancho * bytesPorPixel,   // las filas van pegadas, sin relleno
                             from: MTLRegionMake2D(0, 0, ancho, alto),
                             mipmapLevel: 0)
            cuantos = ancho * alto
        }
    }

    private static func crearTextura(device: MTLDevice,
                                     formato: MTLPixelFormat,
                                     tamaño: Int,
                                     usage: MTLTextureUsage,
                                     storage: MTLStorageMode,
                                     nombre: String) -> MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: formato,
                                                                  width: tamaño,
                                                                  height: tamaño,
                                                                  mipmapped: false)
        descriptor.usage = usage
        descriptor.storageMode = storage

        guard let textura = device.makeTexture(descriptor: descriptor) else {
            fatalError("No se pudo crear la textura \"\(nombre)\"")
        }
        textura.label = nombre
        return textura
    }
}

/// Las fotos de C ya copiadas a la CPU. El píxel (i, j) (columna i, fila j
/// desde arriba) está en el índice `k = j·tamaño + i` de cada arreglo.
struct FotosLeidas {
    let tamaño: Int
    /// RGBA, de 0 a 255.
    let color: [SIMD4<UInt8>]
    /// Distancia radial desde C. 0 en el fondo.
    let distancia: [Float]
    /// ID del objeto. 0 = fondo; es la fuente de verdad para saber qué es fondo.
    let id: [UInt16]

    func indice(_ i: Int, _ j: Int) -> Int { j * tamaño + i }
}
