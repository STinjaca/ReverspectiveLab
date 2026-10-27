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

/// Lo que escribe `fs_fotos`: un valor por cada imagen de la pasada.
/// `[[color(n)]]` manda el campo a `colorAttachments[n]` en Swift, y el tipo
/// tiene que corresponder al formato de esa textura.
struct FotosDesdeC {
    float4 color     [[color(0)]];   // fotos.color      rgba8Unorm
    float  distancia [[color(1)]];   // fotos.distancia  r32Float
    ushort id        [[color(2)]];   // fotos.id         r16Uint
};

/// Fragment shader de las fotos de la cámara C: color, distancia e ID en
/// una sola pasada.
///
/// La distancia es radial: `length(punto − C)`, a lo largo del rayo que sale
/// de C y pasa por este píxel. No sirve el z-buffer, porque guarda un valor
/// deformado por la perspectiva y medido a lo largo del eje de la cámara.
/// Para eso `scene.cameraPosition` tiene que ser la posición de C, no la
/// del visor.
fragment FotosDesdeC fs_fotos(VertexOut in [[stage_in]],
                              constant Uniforms &uniforms [[buffer(1)]],
                              constant SceneUniforms &scene [[buffer(2)]]) {
    FotosDesdeC out;
    out.color = float4(sombrear(in, uniforms, scene), 1.0);
    out.distancia = distance(in.worldPosition, scene.cameraPosition);
    out.id = ushort(uniforms.objetoID);
    return out;
}

// MARK: - Miniaturas de las fotos

/// Qué se le pasa a `fs_miniatura` para cada foto (buffer 0 del fragment).
/// El mismo struct existe en Swift (`MiniaturaUniforms` en Miniaturas.swift):
/// si se cambia uno, se cambia el otro en el mismo commit.
struct MiniaturaUniforms {
    uint  tipo;     // 0 = color, 1 = distancia, 2 = ID
    float dMin;     // distancia mínima entre los píxeles válidos
    float dMax;     // distancia máxima entre los píxeles válidos
};

struct MiniaturaOut {
    float4 position [[position]];
    float2 uv;
};

/// Un cuadrado que llena todo el viewport, sin vertex buffer: con
/// `drawPrimitives(.triangle, vertexCount: 6)` Metal llama a esta función 6
/// veces, y `[[vertex_id]]` dice cuál de los 6 vértices toca. El tamaño y la
/// posición en pantalla los decide `setViewport` en Swift.
vertex MiniaturaOut vs_miniatura(uint vid [[vertex_id]]) {
    // Dos triángulos en NDC: (−1, −1) es la esquina inferior izquierda.
    const float2 esquinas[6] = { {-1, -1}, {1, -1}, {-1, 1},
                                 {-1,  1}, {1, -1}, { 1, 1} };
    float2 p = esquinas[vid];

    MiniaturaOut out;
    out.position = float4(p, 0.0, 1.0);
    // En NDC y crece hacia arriba; en las texturas la fila 0 está arriba.
    // Por eso v = (1 − y)/2: el borde de arriba del cuadrado lee la fila 0.
    out.uv = float2((p.x + 1.0) * 0.5, (1.0 - p.y) * 0.5);
    return out;
}

/// Colores falsos fijos por ID: 0 (fondo) negro y luego colores bien
/// distintos entre sí. Del 4 en adelante se repiten.
float3 colorDeID(ushort id) {
    if (id == 0) { return float3(0.0); }
    const float3 paleta[4] = { {0.95, 0.30, 0.25},    // 1 esfera: rojo
                               {0.25, 0.80, 0.35},    // 2 cubo: verde
                               {0.25, 0.45, 0.95},    // 3 piso: azul
                               {0.95, 0.85, 0.20} };  // 4: amarillo
    return paleta[(id - 1) % 4];
}

/// Pinta una de las tres fotos según `u.tipo`.
///
/// La foto de ID es `r16Uint`, una textura de enteros: se declara como
/// `texture2d<ushort>` y se lee con `read(uint2)` en coordenadas de píxel.
/// `sample()` no sirve con texturas enteras, porque mezclar (filtrar) IDs
/// no tiene sentido: el promedio entre la esfera (1) y el piso (3) no es el
/// cubo (2). La distancia también se lee con `read`, para ver los valores
/// tal cual, sin mezclar.
fragment float4 fs_miniatura(MiniaturaOut in [[stage_in]],
                             constant MiniaturaUniforms &u [[buffer(0)]],
                             texture2d<float>  color     [[texture(0)]],
                             texture2d<float>  distancia [[texture(1)]],
                             texture2d<ushort> id        [[texture(2)]]) {
    if (u.tipo == 0) {
        constexpr sampler lineal(filter::linear);
        return float4(color.sample(lineal, in.uv).rgb, 1.0);
    }

    // De UV (0…1) a píxel (0…N−1). El min evita salirse en uv = 1.
    uint2 tam = uint2(id.get_width(), id.get_height());
    uint2 pixel = min(uint2(in.uv * float2(tam)), tam - 1);
    ushort objeto = id.read(pixel).r;

    if (u.tipo == 1) {
        if (objeto == 0) { return float4(0.0, 0.0, 0.0, 1.0); }   // fondo: el ID manda
        float d = distancia.read(pixel).r;
        float t = saturate((d - u.dMin) / (u.dMax - u.dMin));    // 0 = cerca, 1 = lejos
        // Cerca claro, lejos oscuro. El gris no baja de 0.15 para que lo más
        // lejano no se confunda con el fondo negro.
        float gris = mix(1.0, 0.15, t);
        return float4(float3(gris), 1.0);
    }

    return float4(colorDeID(objeto), 1.0);
}

// MARK: - Pieza invertida

/// Un vértice de la pieza. Llega de dos buffers distintos (ver
/// `Pieza.descriptorVertices` en Swift): la posición cambia con la
/// inversión, la UV y la marca de válido no.
struct PiezaIn {
    float3 posicion [[attribute(0)]];   // buffer 0: dinámico
    float2 uv       [[attribute(1)]];   // buffer 1: estático
    float  valido   [[attribute(2)]];   // buffer 1: 1 = objeto, 0 = fondo
};

struct PiezaOut {
    float4 position [[position]];
    float2 uv;
    float  valido;      // interpolado: < 1 si el triángulo toca el fondo
};

/// Vertex shader de la pieza: solo proyecta. Las posiciones ya están en el
/// mundo (las calculó la CPU con el núcleo), así que no hay matriz de modelo.
vertex PiezaOut vs_pieza(PiezaIn in [[stage_in]],
                         constant float4x4 &viewProjection [[buffer(2)]]) {
    PiezaOut out;
    out.position = viewProjection * float4(in.posicion, 1.0);
    out.uv = in.uv;
    out.valido = in.valido;
    return out;
}

/// Fragment shader de la pieza: la foto de color pegada como textura.
///
/// **Sin iluminación:** la luz ya está "pintada" en la foto. Si se volviera
/// a iluminar, las sombras saldrían dos veces y, peor, con la geometría
/// invertida, que es justo lo que la ilusión tiene que esconder.
///
/// **Fondo:** los índices de la rejilla no saben qué píxeles son fondo,
/// así que hay triángulos que unen un objeto con el fondo. La marca
/// `valido` vale 1 en los vértices de objetos y 0 en los de fondo; al
/// interpolarla, cualquier punto de un triángulo que toque el fondo queda
/// por debajo de 1, y se descarta.
fragment float4 fs_pieza(PiezaOut in [[stage_in]],
                         texture2d<float> color [[texture(0)]]) {
    if (in.valido < 0.999) {
        discard_fragment();
    }
    constexpr sampler lineal(filter::linear, address::clamp_to_edge);
    return float4(color.sample(lineal, in.uv).rgb, 1.0);
}
