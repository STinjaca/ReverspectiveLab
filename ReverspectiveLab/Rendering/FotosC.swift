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
