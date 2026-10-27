# ReverspectiveLab — Requisitos del release v0.2 ("avance de la semana")

> Documento para que Claude Code implemente. Léelo completo antes de empezar.
> Autor del proyecto: Santiago (curso Computación Visual Interactiva, Uniandes).
> Las convenciones permanentes del repo están en `CLAUDE.md`; este documento
> define **qué** construir en este release y **cómo saber que quedó bien**.

---

## 0. Contexto

**Qué es el proyecto.** Una *reverspectiva* (Patrick Hughes) es una pieza cuyo
relieve está invertido respecto a lo que muestra la imagen pintada encima: lo
que parece cerca está lejos y viceversa. Al moverse el observador, la escena
parece girar al revés y "seguirlo". El proyecto genera reverspectivas
automáticamente a partir de una escena 3D con varios objetos, y compara tres
estrategias de inversión. La pregunta de investigación compara el ángulo
máximo de visión θ_max que predice la geometría con el ángulo al que la gente
reporta que la ilusión se rompe. Este release cubre solo la parte geométrica,
sin estudio con personas.

**Pipeline completo** (este release llega hasta el punto 4 y un poco del 5):

1. Escena 3D → **tres fotos desde una cámara fija C**: color, distancia radial e ID de objeto.
2. Fotos → **rejilla de triángulos**: un vértice por píxel.
3. Rejilla → **pieza invertida**: cada vértice se mueve a lo largo de su rayo según una estrategia.
4. Pieza → **visor**: se mira desde otras posiciones, con la foto de color pegada como textura.
5. Medición: con qué ángulo aparecen las "paredes" (triángulos estirados) y la ilusión se rompe.

**Estado actual (ya hecho, no rehacer):**

- App macOS en SwiftUI + MetalKit (`App/`, `Rendering/`, `Scene/`, `Shaders/`).
- Escena de prueba (`EscenaPrueba`): esfera radio 1 en el origen (ID 1), cubo de lado 1 en (1.8, −0.5, −1) (ID 2), piso 8×8 en y = −1 (ID 3). ID 0 = fondo.
- Cámara C fija: posición (0, 0, 5), mirando a (0, 0, 0), FOV vertical 45°, aspecto 1.
- Cámara del visor separada (`camaraVisor`) con órbita y zoom por gestos.
- `FotosC`: 4 texturas de 256×256 (`color` rgba8Unorm, `distancia` r32Float, `id` r16Uint, en `.shared`; `profundidad` depth32Float, en `.private`).
- `PasadaFotos`: una pasada con 3 color attachments que escribe color (Blinn-Phong), distancia radial `distance(worldPos, C)` e ID. Hoy se ejecuta **en cada frame**.
- Verificado: distancia en el píxel (128, 128) = 4.0006; ID correctos.
- Deuda conocida: el loop de dibujo está duplicado en `Renderer` y `PasadaFotos`.

---

## 1. Objetivo del release y demo esperada

**Objetivo:** un build que Santiago pueda mostrar en clase (unos 3 minutos) y
que demuestre de punta a punta el pipeline: escena → fotos → pieza invertida →
ilusión → paredes.

**Guion de la demo** (es la prueba de aceptación final):

1. Abre la app. Se ve la escena original desde el visor, con las **tres fotos** en miniatura: color, distancia en grises e ID en colores falsos.
2. Cambia a **"Pieza invertida"** y pulsa **"Ir a C"**. Desde C, la pieza se ve **idéntica** a la escena original, aunque su geometría está al revés.
3. Orbita un poco, unos ±10°. La escena **parece girar en sentido contrario** al movimiento: la esfera "convexa" en realidad es un cuenco y "sigue" al observador. Esa es la ilusión.
4. Orbita más. Aparecen triángulos estirados y la ilusión se rompe. Con **"Resaltar paredes"** se ven en rojo. El panel muestra el ángulo θ actual y el porcentaje de triángulos que son pared.
5. Cambia el **factor s** (0 = plano, 1 = inversión completa) y la **estrategia** (global / por objeto). Se ve cómo cambian las paredes.

---

## 2. Reglas de trabajo para Claude Code

1. **Ramas:** una rama por hito, creada desde `main` actualizado: `feat/r1-fotos-una-vez`, `feat/r2-miniaturas`, `feat/r3-nucleo`, `feat/r4-pieza`, `feat/r5-interfaz`, `feat/r6-paredes`, `feat/r7-hibrida`, `feat/r8-extras`. Al terminar un hito (criterios en verde), se integra a `main` con `git merge --no-ff`, que conserva los commits atómicos y deja visible dónde empieza y termina cada hito, y se borra la rama. El siguiente hito sale del `main` ya integrado. Nunca hagas commits directamente en `main`. **El release no es una rama:** cuando se cumpla la definición de terminado (§7), se crea el tag anotado `v0.2.0` sobre `main`.
2. **Un commit por cambio lógico.** Cada commit compila y la app corre. Mensajes en inglés, en imperativo, como los existentes ("Add …", "Move …").
3. **Compilar y verificar en cada hito:**
   - `xcodebuild -project ReverspectiveLab.xcodeproj -scheme ReverspectiveLab -destination 'platform=macOS' build`
   - `swift test` para el núcleo puro (ver R3).
   - Metal API Validation y GPU Validation activas en el esquema Debug (ya lo están).
4. **No agregues dependencias externas.** Solo Swift, SwiftUI, Metal, MetalKit, ModelIO y simd.
5. **Código didáctico.** Santiago está aprendiendo Swift y Metal y va a continuar programando él mismo. Por eso:
   - Nombres del dominio en español, como el código existente (`camaraC`, `fotos`, `pivote`, `pieza`).
   - Doc comments (`///`) que expliquen el **porqué**, no solo el qué, al estilo de `PasadaFotos.swift` y `Shaders.metal`.
   - Nada de abstracciones "por si acaso". Si algo se usa en un solo lugar, no lo generalices.
6. **Bitácora:** al final de cada hito, agrega una entrada a `docs/BITACORA.md`, en español sencillo y sin jerga innecesaria. Debe decir qué se hizo, qué conceptos de Metal/Swift aparecen por primera vez (explicados en 2–4 líneas cada uno) y en qué archivos mirarlos. Es lo que Santiago va a leer para ponerse al día.
7. **Si algo de este documento resulta incorrecto** (una fórmula, una API, un número esperado), **no lo fuerces**. Mide, corrige, deja el porqué en el commit y anótalo en la bitácora bajo "Desviaciones". Ya pasó una vez: `sphereWithExtent` resultó ser el radio y no el diámetro.
8. **Orden:** hitos R1 → R7 en orden. Los marcados **Must** son el mínimo del release; **Should** se hacen si hay tiempo; **Could** son opcionales.

---

## 3. Convenciones (no las cambies sin anotarlo)

| Concepto | Definición |
|---|---|
| **C** | Cámara fija de las fotos: `escena.camaraC`. Aspecto 1 |
| **N** | Lado de las fotos en píxeles: `fotos.tamaño` (256) |
| **Píxel (i, j)** | `i` = columna, de izquierda a derecha; `j` = fila, **de arriba hacia abajo** (convención de texturas de Metal). Índice lineal `k = j·N + i` |
| **UV del píxel** | `u = (i + 0.5)/N`, `v = (j + 0.5)/N`, el centro del píxel |
| **NDC del píxel** | `x = 2u − 1`, `y = 1 − 2v` (en NDC, y crece hacia arriba) |
| **Rayo r(i, j)** | Vector unitario en el mundo, desde C hacia el centro del píxel. En el espacio de la cámara es `normalize(x·tan(fov/2)·aspecto, y·tan(fov/2), −1)`, llevado al mundo con la base (derecha, arriba, −adelante) de C |
| **d(i, j)** | Distancia radial de C al punto visible: lo que guarda `fotos.distancia`. Vale 0 en el fondo |
| **Válido** | Píxel con `ID ≠ 0`. El ID es la fuente de verdad del fondo, no `d == 0` |
| **Pivote d_b** | Mediana de `d` sobre los píxeles válidos que correspondan (ver R3) |
| **s** | Factor de inversión, en [0, 1]. 0 = todo aplanado en el pivote; 1 = inversión completa |
| **Pieza** | La malla rejilla con las posiciones invertidas |
| **θ** | Ángulo, en grados, entre los vectores (C − P) y (visor − P), con P = C + adelante_C · D y D = pivote global. Es "cuánto se movió el observador respecto a C, visto desde la pieza" |

---

## 4. Hitos

### R1 — Fotos una sola vez + autoprueba · **Must**

**Objetivo:** las fotos dejan de tomarse en cada frame. Se toman una vez y la
CPU puede leerlas.

Requisitos:
- R1.1 Las fotos se toman al iniciar: un command buffer propio, `commit()` y `waitUntilCompleted()`, antes del primer frame. Como las texturas están en `.shared` (chip Apple), después de esperar la CPU las puede leer directamente.
- R1.2 Un lector `LectorFotos` (o métodos en `FotosC`) que copie las tres texturas a arreglos Swift con `getBytes(_:bytesPerRow:from:mipmapLevel:)`: `[Float]` para distancia, `[UInt16]` para ID y `[SIMD4<UInt8>]` (o equivalente) para color. Orden fila por fila, con la fila 0 arriba.
- R1.3 Un modo de depuración que vuelva a tomar las fotos en cada frame (un `Bool` en DEBUG). Sirve para verlas en la captura de GPU de Xcode.
- R1.4 **Autoprueba de arranque** (solo DEBUG): imprime en consola una línea por chequeo con ✓/✗ y el valor medido, y expone el resultado para mostrarlo en la interfaz (R5):
  - Distancia en el píxel (128, 128) ≈ 4.0 (±0.01).
  - ID en (128, 128) = 1 (esfera); ID en (0, 0) = 0 (fondo, esquina superior izquierda); algún píxel de la fila N−1 con ID = 3 (piso).

Aceptación: la app arranca, la consola muestra los chequeos en ✓ y el
rendimiento no cambia de forma visible.

---

### R2 — Ver las fotos en pantalla · **Must**

**Objetivo:** las tres fotos se ven como miniaturas sobre el visor.

Requisitos:
- R2.1 Tres miniaturas (por ejemplo, 160×160 puntos cada una) en una franja inferior o lateral del área Metal, con etiqueta: "Color", "Distancia", "ID".
- R2.2 Color: la textura tal cual.
- R2.3 Distancia: escala de grises normalizada entre `d_min` y `d_max` de los píxeles válidos (cerca = claro, lejos = oscuro). El fondo, negro. Los límites se calculan en la CPU (R1) y se pasan como uniform.
- R2.4 ID: colores falsos fijos por ID (0 = negro, 1, 2, 3… = colores distintos y bien diferenciados).
- R2.5 **Trampa conocida:** `r16Uint` es una textura de enteros. En el shader se declara `texture2d<ushort>` y se lee con `read(uint2)` usando coordenadas de píxel, **no** con `sample()`: las texturas enteras no admiten filtrado. Para la distancia (`r32Float`) usa `sample` con filtro `nearest`, o `read`.
- R2.6 Implementación sugerida: un pipeline de "miniatura" que dibuja un cuadrado con 6 vértices generados en el vertex shader (sin vertex buffer), uno por foto, ajustando `setViewport` para cada miniatura. Si eliges otra forma, explica el porqué en la bitácora.

Aceptación: las tres miniaturas se ven, con la orientación correcta (el piso
abajo, no al revés) y el cubo a la derecha de la esfera, igual que en la escena.

---

### R3 — Núcleo puro y probado · **Must**

**Objetivo:** toda la matemática del pipeline vive en código puro (sin Metal)
y con pruebas automáticas.

Requisitos:
- R3.1 Carpeta `ReverspectiveLab/Core/` con código que **solo** importa `simd`/`Foundation`, sin Metal. Mueve aquí `Camara.swift` y `MatrixMath.swift` (son puras). La app los sigue usando igual.
- R3.2 `Package.swift` en la raíz del repo con un target de librería `ReverspectiveCore` (`path: "ReverspectiveLab/Core"`) y un target de pruebas `ReverspectiveCoreTests` (`Tests/ReverspectiveCoreTests`), para correr `swift test` desde la terminal. La app compila esos mismos archivos (el proyecto usa carpetas sincronizadas). **Si esta configuración choca con el `.xcodeproj`,** usa en su lugar un target XCTest en Xcode y explica la decisión en la bitácora.
- R3.3 **Rayos:** una función que dé el rayo `r(i, j)` desde C, según las convenciones de la sección 3.
- R3.4 **Mediana:** de un conjunto de distancias, ignorando los píxeles no válidos.
- R3.5 **Inversión**, como función pura `(d, ID, estrategia, s) → d'`, más los pivotes precalculados:
  - **Global:** `D = mediana(d de todos los válidos)`; `d' = D + (D − d)·s`.
  - **Por objeto:** `d_b(k) = mediana(d de los píxeles con ese ID)`; `d' = d_b(k) + (d_b(k) − d)·s`. Cada objeto invierte su relieve alrededor de su propio pivote y conserva su distancia promedio.
  - **Recorte:** si `d' < d_min`, con `d_min = 0.05 · D`, se fija `d' = d_min` y el píxel se cuenta como "recortado". Es la restricción `d < d_b(1 + s)/s` del diseño (que garantiza `d' > 0`), con un margen para no pegar vértices a C.
- R3.6 **Rejilla** (`Rejilla`): genera **una sola vez** (depende solo de N) los índices de la malla como **tiras de triángulos** (`triangleStrip`), una tira por fila de quads, separadas por el índice de reinicio `0xFFFFFFFF`. Índices de 32 bits. El orden de los vértices debe ser **antihorario visto desde C**, para que las caras traseras sean detectables más adelante.
- R3.7 **Posiciones de la pieza:** `p'(i, j) = C + r(i, j) · d'(i, j)` para los píxeles válidos. Las posiciones de los no válidos dan igual (ver R4.3).

Pruebas mínimas (`swift test`):
- Rayo del centro de la imagen ≈ `normalize(objetivo − posición)` de C (con N par, prueba el promedio de los 4 píxeles centrales, o usa el NDC (0, 0) directamente).
- Ida y vuelta: proyectar `C + r(i, j)·5` con la `viewProjection` de C devuelve el centro del píxel (i, j), con error < 0.01 píxel. Pruébalo en las 4 esquinas y en el centro.
- Inversión: `d = d_b → d' = d_b`; `s = 0 → d' = d_b` para todo d; para s > 0, d' es estrictamente decreciente en d; se respeta el recorte.
- Mediana: casos pares, impares e ignorando los no válidos.
- Rejilla con N = 256: 2·(N−1)·N índices de vértice (= 130 560) más (N−2) índices de reinicio; ningún índice ≥ N²; 2·(N−1)² = 130 050 triángulos. Con N = 3, el resultado exacto escrito a mano.
- Orientación: en N = 2 o 3, el primer triángulo es antihorario en NDC.

Aceptación: `swift test` en verde y la app compila y se ve igual que antes.

---

### R4 — La pieza invertida en el visor · **Must**

**Objetivo:** dibujar la pieza (la rejilla con las posiciones invertidas),
texturizada con la foto de color.

Requisitos:
- R4.1 `Pieza` (en `Rendering/`): tiene los buffers de la malla rejilla:
  - **Buffer de posiciones** (dinámico, `.shared`): se reescribe cuando cambia la estrategia o `s`. Se calcula en la CPU con el núcleo (R3). 65 536 vértices es poco; no hace falta un compute shader.
  - **Buffer estático**: UV y la marca de "válido" (0/1). No cambia mientras no cambien las fotos.
  - **Buffer de índices**: el de R3.6, creado una vez.
  - Usa dos `bufferIndex` distintos en un `MTLVertexDescriptor` propio de la pieza. La malla de la escena sigue usando `VertexLayout`.
- R4.2 Shaders `vs_pieza` / `fs_pieza`: el color sale de muestrear `fotos.color` en la UV (filtro lineal), **sin iluminación**, porque la luz ya está "pintada" en la foto.
- R4.3 **Fondo:** ningún triángulo que toque un vértice no válido debe verse. Los índices **no** dependen del contenido de las fotos (R3.6), así que no se pueden quitar del buffer de índices. Solución sugerida: interpolar la marca "válido" y hacer `discard_fragment()` si es < 0.999. Otra opción válida: en el vertex shader, mover esos vértices fuera del volumen de recorte.
- R4.4 Triángulos entre objetos distintos (por ejemplo, el borde de la esfera contra el piso): **se dibujan**. Son las "paredes" de la reverspectiva y van texturizados, estirados.
- R4.5 **Autoprueba desde C** (DEBUG): dibujar la pieza desde C en una textura de N×N y compararla con `fotos.color` en los píxeles válidos. Diferencia media absoluta < 3/255 por canal. Se agrega al reporte de R1.4.
- R4.6 Cull mode `.none` por ahora: las caras traseras son información para R6, no algo que ocultar.

Aceptación: desde C (R5 "Ir a C"), la pieza es indistinguible de la escena
original. Al orbitar unos ±10° se nota el movimiento invertido. La autoprueba
R4.5 en ✓.

---

### R5 — Interfaz de la demo · **Must**

**Objetivo:** los controles del guion de la sección 1.

Requisitos:
- R5.1 Estado compartido SwiftUI ↔ Renderer en una clase `@Observable` (por ejemplo `EstadoVisor`). El `Renderer` lo lee en cada frame. Un cambio de estrategia o de `s` marca la pieza como "sucia" y las posiciones se recalculan **una vez**, no en cada frame.
- R5.2 Panel lateral derecho (unos 280 puntos), con secciones:
  - **Vista:** selector segmentado "Escena original" / "Pieza invertida".
  - **Inversión:** selector de estrategia (Global / Por objeto) y slider `s` de 0 a 1 (por defecto 1) mostrando su valor.
  - **Cámara:** botón **"Ir a C"**, que pone el visor en la posición de C mirando a P (sección 3); botón "Reiniciar órbita"; texto con **θ** en grados con 1 decimal.
  - **Datos:** pivote(s) en uso, % de píxeles recortados y el resultado de la autoprueba (✓/✗ con detalle al pasar el cursor).
- R5.3 La órbita del visor gira alrededor de P (sección 3), no alrededor del origen, para que orbitar sea "caminar alrededor de la pieza".
- R5.4 Las miniaturas de R2 siguen visibles en los dos modos.

Aceptación: se puede ejecutar el guion de la demo, pasos 1 a 3 y 5 (sin paredes).

---

### R6 — Paredes · **Should**

**Objetivo:** hacer visibles los triángulos estirados, que son los que rompen
la ilusión.

Requisitos:
- R6.1 Definición: un triángulo es **pared** si la diferencia relativa de `d'` entre dos de sus vértices supera un umbral τ (por defecto 0.08, ajustable en el panel), o si sus vértices tienen IDs distintos. Se calcula en la CPU junto con las posiciones (R4.1), y por eso depende de la estrategia y de `s`.
- R6.2 Toggle **"Resaltar paredes"**: las paredes se tiñen de rojo (mezcla 60 % rojo con la textura). Implementación sugerida: una marca por vértice ("toca una pared"), interpolada; si es > 0, se tiñe. Es aproximado en el borde y eso está bien; documéntalo.
- R6.3 En el panel: **% de triángulos válidos que son pared**.
- R6.4 Toggle opcional para marcar en azul las **caras traseras** respecto al visor (`[[front_facing]]` en el fragment shader). Requiere la orientación correcta de R3.6.

Aceptación: al orbitar, las paredes rojas aparecen en los contornos (alrededor
de la esfera y del cubo) y crecen con θ. Con la estrategia "Por objeto" hay
**menos** paredes entre objetos que con "Global".

---

### R7 — Estrategia híbrida · **Could (definición confirmada por Santiago)**

**Por qué dos factores.** La descripción original ("pivote por objeto, y además
se invierte el orden entre objetos") es, con un solo factor s, matemáticamente
idéntica a la global:
`D + (D − d_b)·s + (d_b − d)·s = D + (D − d)·s`.

**Definición (confirmada).** Las tres estrategias salen de una sola fórmula:

`d' = [D + (D − d_b(k))·s_orden] + (d_b(k) − d)·s_relieve`

- `D` = mediana global; `d_b(k)` = mediana del objeto k (el ID del píxel).
- `s_orden = s_relieve` → **global**.
- `s_orden = −1` → **por objeto** (cada objeto se queda en su distancia promedio).
- Valores intermedios (por ejemplo `s_orden = 0.5`) → **híbrida**. Sirve para separar el efecto local del global.

Requisitos:
- R7.1 En el núcleo (R3), implementa **las tres** estrategias con esta función general, y deja "Global" y "Por objeto" como casos especiales con nombre. Agrega pruebas que confirmen que la fórmula general reproduce exactamente las dos de R3.5 con esos valores de `s_orden`.
- R7.2 Agrega "Híbrida" al selector de estrategia, con un segundo slider `s_orden` (rango −1 a 1, por defecto 0.5) visible solo en ese modo. El slider `s` existente es `s_relieve`.
- R7.3 El recorte de R3.5 aplica igual.

Si R7.1 sale barato, puedes hacerlo junto con R3; la interfaz (R7.2) va
después de R6.

---

### R8 — Extras · **Could**

- R8.1 Botón **"Guardar captura"**: guarda el área Metal como PNG en `~/Pictures/ReverspectiveLab/` con fecha y hora, y en el nombre la estrategia, `s` y θ. Es para las diapositivas.
- R8.2 Barrido automático de θ: mueve el visor de −40° a +40° en pasos de 1° alrededor de P (en el plano horizontal) y exporta un CSV con `θ, %paredes` por estrategia. Es la primera versión de θ_max. **Solo si todo lo anterior está listo.**

---

### R9 — Ajustes antes del tag · **Must** (agregado después de la prueba a mano)

Resultado de la prueba a mano de Santiago: desde C, la pieza se ve **borrosa**
y la silueta de la esfera tiene un **serrucho muy marcado**. La autoprueba R4.5
da 0.00/255, pero compara a la resolución de la foto (N×N); en pantalla esa
foto se amplía 4–6 veces.

- R9.1 **Resolución.** Sube `N` a 1024 (fotos y rejilla). Mide y anota en la bitácora: el tiempo de `tomarFotos`, el tiempo de recalcular la pieza (cambio de `s`) y los FPS orbitando. Si recalcular la pieza tarda más de 150 ms o el visor baja de 60 FPS, usa 768 y anota por qué. Ajusta las autopruebas a N: el píxel central es (N/2, N/2) y la fila de piso es N−1. Revisa que las pruebas de la rejilla sigan pasando con N genérico.
- R9.2 **Antialiasing en el visor.** MSAA 4× en la pantalla: `MTKView.sampleCount = 4` y `rasterSampleCount = 4` en **todos** los pipelines que dibujan en la vista (escena, pieza, miniaturas). Las pasadas fuera de pantalla (fotos, autopruebas) no cambian. No uses MSAA en la foto de ID: los enteros no se promedian.
- R9.3 **Definición de pared.** Quita de R6.1 la regla "IDs distintos = pared": pared es solo un salto relativo de `d'` > τ. Así el % de paredes compara estrategias por lo que cambian. Vuelve a medir la tabla de R6 y deja la expectativa "Por objeto < Global" como **resultado a registrar**, no como criterio. Que no se cumpla es un hallazgo: en los bordes de oclusión, "Por objeto" hace saltos más grandes.
- R9.4 **Que los docs no entren en la app.** Ni `docs/`, ni el README, ni su captura se copian al bundle. Revisa `project.pbxproj` (Build Phases → Copy Bundle Resources, o excepciones de la carpeta sincronizada). Hay un cambio local de Santiago en `project.pbxproj` que agrega `docs/` al target: no lo commitees. Avísale para que lo descarte.
- R9.5 **Verificación limpia.** `xcodebuild clean build` + `swift test` + autopruebas en ✓, **cada comando por separado y cortando en el primer fallo**. Hasta que eso pase, no se hace ningún merge.
- R9.6 **No crees el tag.** Deja escrito en la bitácora el comando exacto `git tag -a v0.2.0 -m "…"`. Santiago lo corre después de su prueba a mano.
- R8 se descarta para v0.2. Guardar en `~/Pictures` pide tocar el sandbox; para las diapositivas basta ⌘⇧4.

## 5. Fuera de alcance de este release

- Gafas 3D / visionOS / estéreo.
- Cargar escenas USDZ/OBJ arbitrarias (la escena de prueba basta).
- Compute shaders para la inversión.
- Estudio con personas, y el θ_max "medido".
- Refactor a ECS.

## 6. Deuda permitida (anótala en la bitácora, no la arregles si no hace falta)

- El loop de dibujo duplicado entre `Renderer` y `PasadaFotos`. Si al agregar la pieza aparece una **tercera** copia, entonces sí extrae una función compartida.

## 7. Definición de terminado

- [ ] Hitos Must (R1–R5) completos; Should (R6) si fue posible.
- [ ] `xcodebuild … build` y `swift test` en verde en el último commit.
- [ ] Autopruebas de arranque en ✓.
- [ ] Ningún error de validación de Metal durante el guion de la demo.
- [ ] `docs/BITACORA.md` con una entrada por hito y una sección final **"Cómo correr la demo"** de 5 pasos.
- [ ] `README.md` actualizado: qué es, cómo compilar y una captura de pantalla (si R8.1 existe, generada con ella).
- [ ] Cada hito integrado a `main` con `--no-ff` y su rama borrada.
- [ ] Tag anotado `v0.2.0` sobre `main`, con un mensaje que liste los hitos incluidos y las desviaciones.
- [ ] No hagas `push`, salvo que Santiago lo pida.

## 8. Trampas conocidas (léelas antes de R2 y R4)

| Trampa | Síntoma | Qué hacer |
|---|---|---|
| Texturas enteras con `sample()` | Error de validación o ceros | `texture2d<ushort>` + `read(uint2)` |
| Fila 0 arriba vs y hacia arriba en NDC | Miniaturas o pieza de cabeza | Respetar la sección 3; prueba de ida y vuelta (R3) |
| Leer las fotos antes de que la GPU termine | Ceros o datos viejos | `waitUntilCompleted()` antes de `getBytes` |
| `Uniforms` distinto entre Swift y Metal | Basura o colores raros | Al tocar un struct, cambiar los dos lados en el mismo commit; tamaño con `MemoryLayout.stride` |
| Índice de reinicio | Triángulos uniendo filas | `0xFFFFFFFF` con índices `uint32` y tipo `.triangleStrip` (en Metal el reinicio siempre está activo para tiras) |
| `d'` ≤ 0 | Vértices detrás de C, triángulos gigantes | Recorte de R3.5 |
| Órbita alrededor del origen | La pieza "se escapa" al orbitar | Orbitar alrededor de P (R5.3) |
