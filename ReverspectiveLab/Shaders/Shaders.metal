//
//  Shaders.metal
//  ReverspectiveLab
//
//  Created by Santi T on 25/10/26.
//

#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal [[attribute(1)]];
};

/// Uniforms por objeto (buffer 1). Renderer.swift los sube una vez por
/// objeto en el loop de `draw(in:)`, así que son los mismos para todos los
/// vértices y fragmentos de un objeto dentro de un mismo draw call.
struct Uniforms {
    float4x4 modelMatrix;   // world space — usado para posición/normal en vs_main
    float4x4 mvpMatrix;     // clip space — el único que necesita out.position
    float4 baseColor;       // usado solo en fs_main
    float shininess;        // usado solo en sombrear
    uint objetoID;          // usado solo en fs_fotos; 32 bits como el UInt32 de Swift
};

/// Uniforms de la escena (buffer 2, distinto del buffer 1 de `Uniforms`).
/// Se suben una sola vez por frame en draw(), no por objeto — luz y
/// cámara no cambian de un objeto a otro.
struct SceneUniforms {
    float3 lightPosition;
    float3 cameraPosition;
};

/// Lo que produce vs_main y consume el fragment shader. `[[position]]` es
/// el único campo obligatorio — es lo que la GPU usa para rasterizar. Los
/// otros dos (worldPosition, worldNormal) viajan "de contrabando": el
/// rasterizador los interpola automáticamente entre los 3 vértices del
/// triángulo, sin que tengas que pedirlo explícitamente.
struct VertexOut {
    float4 position [[position]];
    float3 worldPosition;
    float3 worldNormal;
};

/// Vertex shader — una invocación por vértice, en paralelo.
///
/// Hace dos cosas: (1) transforma la posición a clip space para que el
/// rasterizador sepa dónde cae en pantalla, y (2) transforma posición y
/// normal a world space, que es donde el fragment shader hace la
/// iluminación (Blinn-Phong necesita posición/normal en el mismo espacio
/// que la luz y la cámara).
///
/// - Parameters:
///   - in: El vértice que le toca a esta invocación (posición y normal),
///     ya armado por Metal a partir del vertex buffer (buffer 0) usando el
///     descriptor de vértices del pipeline — `[[stage_in]]`.
///   - uniforms: Datos del objeto actual (buffer 1) — mismos para
///     todas las invocaciones de este draw call.
vertex VertexOut vs_main(VertexIn in [[stage_in]],
                          constant Uniforms &uniforms [[buffer(1)]]) {
    VertexOut out;
    float4 worldPos = uniforms.modelMatrix * float4(in.position, 1.0);
    out.position = uniforms.mvpMatrix * float4(in.position, 1.0);
    out.worldPosition = worldPos.xyz;
    // Sin escalado no-uniforme en la escena, la 3x3 superior de modelMatrix
    // transforma normales correctamente sin necesitar la inversa-transpuesta.
    out.worldNormal = (uniforms.modelMatrix * float4(in.normal, 0.0)).xyz;
    return out;
}

/// Blinn-Phong: ambient + diffuse (N·L) + specular (N·H, término de Blinn).
///
/// Función normal (sin `fragment`) para que la compartan `fs_main` y
/// `fs_fotos`: la foto de color tiene que verse igual que la pantalla.
///
/// `in` no es el dato de ningún vértice: es el resultado de interpolar
/// `worldPosition`/`worldNormal` de los 3 vértices del triángulo según
/// qué tan cerca esté este píxel de cada uno (coordenadas baricéntricas,
/// slide 4) — por eso dos píxeles vecinos del mismo triángulo tienen
/// normales ligeramente distintas, y de ahí sale el sombreado suave.
///
/// - Parameters:
///   - in: Posición y normal en world space, ya interpoladas por el
///     rasterizador — específicas de este píxel, no de un vértice.
///   - uniforms: Color base y shininess del objeto (buffer 1).
///   - scene: Posición de luz y cámara (buffer 2), iguales para
///     todos los píxeles del frame.
/// - Returns: Color RGB del píxel, sin alfa.
float3 sombrear(VertexOut in, constant Uniforms &uniforms, constant SceneUniforms &scene) {
    float3 N = normalize(in.worldNormal);
    float3 L = normalize(scene.lightPosition - in.worldPosition);
    float3 V = normalize(scene.cameraPosition - in.worldPosition);
    float3 H = normalize(L + V);

    float ambient = 0.12;
    float diffuse = max(dot(N, L), 0.0);
    float specular = pow(max(dot(N, H), 0.0), uniforms.shininess);

    return uniforms.baseColor.rgb * (ambient + diffuse) + specular * 0.6;
}

/// Fragment shader de la pantalla — una invocación por píxel cubierto.
fragment float4 fs_main(VertexOut in [[stage_in]],
                         constant Uniforms &uniforms [[buffer(1)]],
                         constant SceneUniforms &scene [[buffer(2)]]) {
    return float4(sombrear(in, uniforms, scene), uniforms.baseColor.a);
}
