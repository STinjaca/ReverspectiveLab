# Bitácora — ReverspectiveLab

Una entrada por hito. Qué se hizo, qué conceptos nuevos aparecen y dónde
mirarlos. Las desviaciones respecto a `REQUISITOS-v0.2.md` van al final.

---

## R1 — Fotos una sola vez + autoprueba

**Qué se hizo**

- Las fotos de C ya no se toman en cada frame: se toman una vez al crear el
  `Renderer`, antes del primer frame.
- Después de tomarlas, la CPU las copia a arreglos de Swift (`FotosLeidas`):
  color, distancia e ID, fila por fila con la fila 0 arriba.
- En DEBUG hay un interruptor, `Renderer.fotosEnCadaFrame`, para volver a
  tomarlas en cada frame. Sirve para verlas en la captura de GPU de Xcode.
- Al arrancar en DEBUG corre una autoprueba con valores conocidos de la
  escena. La consola muestra:

  ```
  Autoprueba de arranque:
    ✓ Distancia en (128, 128) ≈ 4.0 — medido 4.0006466
    ✓ ID en (128, 128) = 1 (esfera) — medido 1
    ✓ ID en (0, 0) = 0 (fondo) — medido 0
    ✓ Fila 255 tiene piso (ID 3) — 256 de 256 píxeles
  ```

**Conceptos nuevos**

- **`commit()` y `waitUntilCompleted()`.** `commit()` manda el command buffer
  a la GPU y vuelve enseguida: la GPU trabaja en paralelo. `waitUntilCompleted()`
  bloquea el hilo hasta que la GPU termina. Hay que esperar antes de leer
  una textura desde la CPU; si no, se leen ceros o datos viejos.
- **`getBytes(_:bytesPerRow:from:mipmapLevel:)`.** Copia los píxeles de una
  textura a memoria de la CPU. `bytesPerRow` es cuánto ocupa una fila en el
  destino: aquí `ancho × bytes por píxel`, sin relleno. Funciona sin pasos
  extra porque las texturas están en `.shared` (en un chip Apple, CPU y GPU
  comparten la memoria).
- **`[T](unsafeUninitializedCapacity:)`.** Crea un arreglo de Swift y deja
  escribir directamente en su memoria. Así `getBytes` copia una sola vez,
  sin un búfer intermedio.
- **`#if DEBUG`.** Código que solo se compila en el esquema Debug. La
  autoprueba y `fotosEnCadaFrame` no existen en Release.
- **`static` dentro de `init`.** Antes de `super.init()` todavía no se puede
  usar `self`, así que `tomarFotos` es `static` y recibe lo que necesita
  como parámetros. Así `fotosLeidas` puede ser `let`.

**Dónde mirar**

- `Rendering/Renderer.swift` → `tomarFotos`, `fotosEnCadaFrame`, `autoprueba`.
- `Rendering/FotosC.swift` → `leer()`, `copiar`, `FotosLeidas`.
- `Rendering/Autoprueba.swift` → los chequeos y por qué se espera cada valor.

**Deuda que sigue**

- El loop de dibujo está duplicado en `Renderer.draw` y `PasadaFotos.tomar`
  (permitido por §6 de los requisitos).

---

## R2 — Ver las fotos en pantalla

**Qué se hizo**

- Abajo a la izquierda del visor hay tres miniaturas de 160×160 puntos:
  **Color** (la foto tal cual), **Distancia** (grises: cerca claro, lejos
  oscuro, fondo negro) e **ID** (colores falsos: esfera roja, cubo verde,
  piso azul, fondo negro).
- Se verificó la orientación con una captura: el piso queda abajo y el cubo
  a la derecha de la esfera, igual que en la escena.

**Conceptos nuevos**

- **Dibujar sin vertex buffer (`[[vertex_id]]`).** `drawPrimitives(.triangle,
  vertexStart: 0, vertexCount: 6)` llama al vertex shader 6 veces y le pasa
  el número de vértice. El shader saca las esquinas de un arreglo fijo. Para
  un cuadrado que llena la pantalla no hace falta subir datos.
- **`setViewport`.** Dice en qué rectángulo del drawable cae el espacio NDC
  (−1…1). Se cambia el viewport antes de cada miniatura y el mismo cuadrado
  sale en tres lugares. Se da en **píxeles** y con y desde **arriba**; por
  eso se multiplica por la escala de la pantalla (2 en Retina).
- **Texturas de enteros (`texture2d<ushort>` + `read`).** La foto de ID es
  `r16Uint`. No se puede `sample()`, porque el sampler mezcla vecinos y
  mezclar IDs no tiene sentido. `read(uint2)` lee un píxel exacto en
  coordenadas de píxel.
- **Depth state `.always` sin escritura.** Las miniaturas se dibujan en el
  mismo encoder que la escena, que tiene buffer de profundidad. Con
  `.always` y sin escribir, quedan siempre encima sin estorbar la escena.
- **`pushDebugGroup`/`popDebugGroup`.** Ponen nombre a un grupo de órdenes
  en la captura de GPU de Xcode, para encontrarlas fácil.
- **`overlay` de SwiftUI.** Las etiquetas son `Text` de SwiftUI encima de la
  vista Metal (escribir texto en Metal es mucho trabajo). Usan las mismas
  medidas en puntos que las miniaturas (`Miniaturas.lado`, …), y
  `allowsHitTesting(false)` deja pasar los gestos a la vista Metal.

**Dónde mirar**

- `Shaders/Shaders.metal` → `vs_miniatura`, `fs_miniatura`, `colorDeID`.
- `Rendering/Miniaturas.swift` → pipeline, viewport por miniatura.
- `Rendering/FotosC.swift` → `rangoDistancias()` (d_min y d_max en la CPU).
- `App/ContentView.swift` → las etiquetas.

**Decisiones**

- Un solo fragment shader con un `tipo` (0, 1, 2) en vez de tres pipelines:
  las tres fotos comparten el cuadrado y el viewport, y así hay un solo
  lugar que leer.
- El gris de la distancia va de 1.0 (lo más cerca) a 0.15 (lo más lejos),
  no a 0. Así el punto más lejano no se confunde con el fondo negro.

---

## R3 — Núcleo puro y probado

**Qué se hizo**

- Carpeta `ReverspectiveLab/Core/` con toda la matemática del pipeline, sin
  Metal: `Camara` y `MatrixMath` (movidos aquí), rayos, mediana, inversión,
  rejilla y posiciones de la pieza.
- `Package.swift` en la raíz: con `swift test` se corren 20 pruebas desde la
  terminal, sin abrir Xcode ni la app. El paquete apunta a la misma carpeta
  `Core/` que compila la app (carpeta sincronizada), así que no hay copias.
  No chocó con el `.xcodeproj`.
- **R7.1 adelantado:** la inversión ya usa la fórmula general de las tres
  estrategias. "Global" y "Por objeto" son casos con nombre, y hay una prueba
  que confirma que reproducen las fórmulas de R3.5.

**Conceptos nuevos**

- **Swift Package Manager.** `Package.swift` describe *targets*: una
  librería (`ReverspectiveCore`) y un target de pruebas. `swift test`
  compila los dos y corre las pruebas. `.build/` es su carpeta de trabajo y
  está en `.gitignore`.
- **Swift Testing (`import Testing`).** Una prueba es una función con
  `@Test`; `#expect(condición)` la revisa y, si falla, muestra los valores.
  `@Test(arguments: [...])` corre la misma prueba con varios casos (las 4
  esquinas, varias estrategias…).
- **`@testable import`.** Deja que las pruebas usen lo que no es `public`.
  Así el núcleo no necesita marcar todo como público.
- **`extension Camara`.** Agrega métodos a un tipo desde otro archivo. Los
  rayos viven en `Rayos.swift`, pero se usan como `camaraC.rayo(i:j:n:)`.
- **Tiras de triángulos con reinicio.** En `.triangleStrip`, cada índice
  nuevo forma un triángulo con los dos anteriores. Una fila de N columnas
  sale con 2N índices en vez de 6(N−1). `0xFFFFFFFF` corta la tira, y Metal
  invierte solo los triángulos impares para que todos queden con la misma
  orientación.

**Dónde mirar**

- `Core/Rayos.swift` → del píxel (i, j) al rayo en el mundo, paso a paso.
- `Core/Mediana.swift` → por qué mediana y no promedio.
- `Core/Inversion.swift` → `Estrategia`, `Pivotes`, la fórmula general y el recorte.
- `Core/Rejilla.swift` → el orden de los índices y la orientación.
- `Core/GeometriaPieza.swift` → `p' = C + r·d'`.
- `Tests/ReverspectiveCoreTests/` → una prueba por propiedad; la de ida y
  vuelta (`RayosTests`) es la que protege contra imágenes de cabeza.

**Decisiones**

- `Estrategia` ya tiene el caso `.hibrida`, pero la interfaz lo va a mostrar
  hasta R7.
- Los vértices de fondo quedan sobre su rayo a la distancia del pivote
  global (no en el origen ni en C): no se ven, pero no producen números
  raros si algún día se dibujan por error.

---

## R4 — La pieza invertida en el visor

**Qué se hizo**

- `Pieza` (en `Rendering/`) lleva la malla rejilla a la GPU: un vértice por
  píxel, en las posiciones que calcula el núcleo, con la foto de color como
  textura y sin iluminación.
- El `Renderer` tiene un `modo` (`.escena` / `.pieza`). La interfaz para
  cambiarlo llega en R5.
- El loop que dibuja la escena pasó a su propio método, `dibujarEscena`.
- Nueva autoprueba: se dibuja la pieza desde C y se compara con la foto de
  color. Resultado: **0.00/255** de diferencia media en 36 129 píxeles.

**Conceptos nuevos**

- **`MTLVertexDescriptor` con dos buffers.** Un vértice puede armarse con
  datos de varios buffers. Aquí la posición viene del buffer 0 (cambia con
  cada inversión) y la UV y la marca de válido del buffer 1 (fijos). El
  descriptor dice qué atributo sale de qué buffer, con qué offset y stride.
- **`SIMD3<Float>` mide 16 bytes, no 12.** Swift la alinea como un float4.
  Por eso el stride del buffer de posiciones se mide con
  `MemoryLayout<SIMD3<Float>>.stride`, y no se escribe a mano.
- **`drawIndexedPrimitives` con `.triangleStrip` y `.uint32`.** Toda la malla
  sale en una sola llamada; el `0xFFFFFFFF` de la rejilla separa las filas.
- **`discard_fragment()`.** El fragment shader puede decidir no pintar un
  píxel. La marca "válido" (1 en objetos, 0 en fondo) se interpola en el
  triángulo; si queda por debajo de 1, el triángulo toca el fondo y se
  descarta. Así se borra el fondo sin cambiar los índices.
- **Buffer nuevo en vez de sobrescribir.** La GPU puede estar dibujando un
  frame anterior con el buffer de posiciones. Si se escribe encima mientras
  lo lee, sale un frame mezclado. Crear uno nuevo es lo más simple: el
  command buffer en vuelo retiene el viejo y después se libera solo.
- **Dibujar en una textura y leerla (autoprueba).** Igual que las fotos: un
  render pass a mano sobre una textura `.shared`, `waitUntilCompleted` y
  `getBytes`.
- **Regla top-left de rasterización.** Un píxel cuyo centro cae justo sobre
  el borde de un triángulo se pinta solo si es el borde de arriba o el de la
  izquierda. Así dos triángulos vecinos no pintan dos veces el mismo píxel.
  Es lo que deja sin pintar la última fila y la última columna de la pieza
  (ver Desviaciones).

**Dónde mirar**

- `Rendering/Pieza.swift` → buffers, `descriptorVertices`, `actualizar`, `dibujar`.
- `Shaders/Shaders.metal` → `vs_pieza`, `fs_pieza`.
- `Rendering/Renderer.swift` → `ModoVista`, el `switch modo` en `draw`.
- `Rendering/Autoprueba.swift` → `revisarPiezaDesdeC`.

**Deuda que sigue**

- El loop de la escena sigue duplicado entre `Renderer.dibujarEscena` y
  `PasadaFotos.tomar`. La pieza no lo usa (dibuja con una sola llamada), así
  que no apareció una tercera copia.

---

## R5 — Interfaz de la demo

**Qué se hizo**

- Panel a la derecha (280 puntos) con cuatro secciones: **Vista** (escena
  original / pieza invertida), **Inversión** (estrategia y `s`), **Cámara**
  ("Ir a C", "Reiniciar órbita" y θ con un decimal) y **Datos** (pivotes en
  uso, % recortados y la autoprueba, con el valor medido al pasar el cursor).
- `EstadoVisor` es el estado que comparten SwiftUI y el `Renderer`. Ahí
  viven el modo, los parámetros de la inversión y la cámara del visor.
- La órbita gira alrededor de **P** (el centro de la pieza visto desde C),
  no del origen. El visor arranca en C mirando a P.
- P y θ están en el núcleo (`Core/Angulo.swift`), con pruebas.
- Verificado con capturas a ±10°: en la escena, al orbitar −10° el cubo se
  pega a la esfera y a +10° se separa; en la pieza pasa **al revés**. Esa
  es la ilusión.

**Conceptos nuevos**

- **`@Observable`.** Marca una clase para que SwiftUI vigile sus
  propiedades: cada vista que lee una propiedad se redibuja cuando esa
  propiedad cambia. No hace falta avisar a mano.
- **`@State` y `@Bindable`.** `@State` en `ContentView` hace que el
  `EstadoVisor` viva lo mismo que la ventana. `@Bindable` en el panel deja
  sacar *bindings* (`$estado.parametros.s`) para conectar pickers y sliders
  directamente a las propiedades.
- **Estado compartido con Metal.** El `Renderer` no es una vista de SwiftUI:
  simplemente guarda una referencia al mismo `EstadoVisor` y lo lee en cada
  `draw`. Las dos partes corren en el hilo principal, así que no hay
  carreras.
- **Detectar "sucio" comparando.** `ParametrosInversion` es `Equatable`. En
  cada frame, el `Renderer` compara los parámetros del estado con los que
  usó la última vez; si cambiaron, recalcula la pieza una vez. Así la
  interfaz no tiene que avisar a nadie.
- **Propiedad calculada (`var theta: Float? { … }`).** θ no se guarda: se
  calcula cada vez que se lee, a partir de la cámara actual. Nunca queda
  desactualizado.
- **`atan2(|a×b|, a·b)` para ángulos.** Da el ángulo entre dos vectores sin
  los problemas de `acos` cerca de 0° (pérdida de precisión, o NaN si el
  redondeo deja el coseno en 1.0000001).

**Dónde mirar**

- `App/EstadoVisor.swift` → `preparar`, `irAC`, `reiniciarOrbita`, `theta`.
- `App/PanelControl.swift` → el panel.
- `Rendering/Renderer.swift` → `actualizarPiezaSiCambio`, `aplicar(_:)`.
- `Core/Angulo.swift` → `puntoP`, `anguloTheta`.

**Decisiones**

- "Ir a C" pone el visor exactamente en C (posición y distancia). "Reiniciar
  órbita" vuelve a θ = 0 pero conserva el zoom. En esta escena el visor
  arranca en C, así que al principio los dos hacen lo mismo.
- La pieza se recalcula también en modo escena, para que el % de
  recortados del panel esté al día aunque no se esté viendo la pieza.
- El selector de estrategia muestra solo Global y Por objeto; "Híbrida"
  llega con su slider en R7.
- `ModoVista` pasó de `Renderer.swift` a `EstadoVisor.swift`, porque ahora
  es parte del estado compartido.

---

## R6 — Paredes

**Qué se hizo**

- El núcleo detecta las **paredes** (`Core/Paredes.swift`): un triángulo
  con sus tres vértices válidos es pared si d' salta más que τ entre dos
  vértices (diferencia relativa al más cercano) o si cambia el ID. Se
  calcula en la CPU junto con las posiciones, cada vez que cambian la
  estrategia, `s` o τ.
- Panel, sección **Paredes**: "Resaltar paredes" (60 % rojo), slider τ
  (por defecto 0.08) y "Caras traseras en azul". En **Datos**, el % de
  triángulos válidos que son pared.
- Nueva autoprueba: desde C no se ve ninguna cara trasera. Es sensible: si
  se voltea la orientación, falla con 36 222 píxeles azules.

Medido en la escena de prueba (τ = 0.08):

| Estrategia | s | % paredes | bordes entre objetos con salto > τ | salto medio en esos bordes | saltos dentro de un objeto |
|---|---|---|---|---|---|
| Global | 1 | 3.2 % | 281 de 473 | 0.91 | 1 816 |
| Global | 0.5 | 0.8 % | 219 de 473 | 0.47 | 82 |
| Por objeto | 1 | 3.5 % | 473 de 473 | 2.90 | 2 042 |
| Por objeto | 0.5 | 1.6 % | 473 de 473 | 2.08 | 654 |

**Conceptos nuevos**

- **Aprovechar el relleno de `SIMD3`.** La marca de pared viaja en la `w`
  del buffer de posiciones (`SIMD4<Float>`: xyz = posición, w = pared). Una
  `SIMD3` ya ocupaba 16 bytes, así que no cuesta memoria extra. En el
  `MTLVertexDescriptor`, el atributo 3 lee un `float` en el offset 12 del
  mismo buffer.
- **`[[front_facing]]`.** Un parámetro del fragment shader que dice si el
  triángulo se ve por delante. Lo decide el orden en que aparecen sus
  vértices en pantalla, comparado con `setFrontFacing`. Metal toma por
  defecto el sentido horario; la rejilla es antihoraria vista desde C, así
  que se pide `.counterClockwise`.
- **Marca por vértice interpolada.** La GPU no sabe de triángulos "pared":
  cada vértice dice si toca una pared (0/1) y el rasterizador interpola.
  Por eso el rojo se derrama un poco en los triángulos vecinos que
  comparten esos vértices. Es aproximado a propósito; para la demo basta.
- **`mix(a, b, t)`.** Mezcla lineal en Metal: `a·(1 − t) + b·t`. Con t = 0.6
  queda 60 % del color de tinte.

**Dónde mirar**

- `Core/Paredes.swift` → la definición y por qué la diferencia es relativa.
- `Shaders/Shaders.metal` → `fs_pieza` (tintes) y `PiezaUniforms`.
- `Rendering/Pieza.swift` → `descriptorVertices` (atributo 3), `crearBufferPosiciones`.
- `Rendering/Autoprueba.swift` → `revisarCarasDesdeC`, `dibujarDesdeC`.

**Cómo se verificó**

- Las capturas automáticas de esta parte no sirvieron: la ventana de la app
  recibía gestos del trackpad mientras estaba al frente, y θ no quedaba
  donde se pedía. Por eso la orientación se verifica con la autoprueba y
  los porcentajes se midieron en la CPU (no dependen de la cámara). Falta
  confirmar a mano, orbitando, que el rojo aparece en los contornos y
  crece con θ.

---

## R7 — Estrategia híbrida

**Qué se hizo**

- R7.1 ya estaba hecho desde R3: el núcleo usa una sola fórmula,
  `d' = [D + (D − d_b)·s_orden] + (d_b − d)·s_relieve`, y "Global" y "Por
  objeto" son casos con nombre (`ParametrosInversion.sOrden`). Una prueba
  confirma que reproduce exactamente las dos fórmulas de R3.5. El recorte
  aplica igual a las tres.
- R7.2: el selector de estrategia muestra **Híbrida**. En ese modo aparece
  un segundo slider, `s_orden` (−1 a 1, por defecto 0.5). El slider `s` de
  siempre es `s_relieve`. En Datos se ven D y los pivotes por objeto.

**Conceptos nuevos**

- **`ForEach(Estrategia.allCases, …)`.** `CaseIterable` le da al enum la
  lista de todos sus casos. El selector se arma solo, y si algún día se
  agrega una estrategia aparece sin tocar el panel.
- **Vistas condicionales (`if` dentro de `body`).** SwiftUI permite `if` en
  la descripción de la vista: el slider de `s_orden` existe solo cuando la
  estrategia es híbrida.

**Dónde mirar**

- `Core/Inversion.swift` → `distanciaInvertida`, `ParametrosInversion.sOrden`.
- `App/PanelControl.swift` → sección Inversión y `pivotes`.

**Para probar a mano**

- Con Híbrida, `s_orden = s` debe verse igual que Global, y `s_orden = −1`
  igual que Por objeto (el % de paredes del panel debe coincidir).

---

## Desviaciones

- **R4.5 compara solo el interior de la imagen.** Contando todos los píxeles
  válidos, la diferencia daba 2.44/255: pasaba, pero justo. El diagnóstico
  mostró que salía toda de 383 píxeles negros, todos en el borde de la
  imagen y ninguno junto al fondo. La malla va del centro del primer píxel
  al centro del último, así que la última fila y la última columna caen
  sobre su borde derecho e inferior, y la regla top-left no las pinta. Se
  excluye el anillo de un píxel del borde; el resultado es 0.00/255.
- **R6, aceptación: "con Por objeto hay menos paredes entre objetos que con
  Global" no se cumple en esta escena.** Se dejó la definición de R6.1 tal
  cual y se midió (tabla en la entrada de R6). Dos razones:
  1. Con R6.1, todo triángulo con IDs distintos es pared. El número de
     paredes entre objetos (473) es el mismo en las dos estrategias: no
     puede bajar.
  2. Si se miran solo los saltos de d' en esos bordes, "Por objeto" los
     hace **más grandes**, no más chicos (salto medio 2.90 contra 0.91 con
     s = 1). La global solo invierte el signo de las diferencias:
     `Δd' = −s·Δd`. "Por objeto" pone cada objeto en su propio pivote (piso
     3.75, esfera 4.25, cubo 5.83), y en la silueta de la esfera el piso de
     atrás termina mucho más cerca que el borde de la esfera.
  Queda para que Santiago decida: cambiar la definición de pared, cambiar
  la expectativa o usar la híbrida (R7) para estudiarlo. No se forzó el
  resultado.

---

## Cómo correr la demo

1. Abrir `ReverspectiveLab.xcodeproj` y correr en Debug (⌘R). Revisar que
   el panel diga **Autoprueba ✓ 6/6**. Se ve la escena original con las
   tres fotos en miniatura: color, distancia en grises e ID en colores.
2. En **Vista**, elegir **Pieza invertida** y pulsar **Ir a C**. La pieza se
   ve idéntica a la escena, aunque su relieve está al revés.
3. Orbitar despacio unos ±10° (θ en el panel). La escena parece girar en
   sentido contrario: la esfera "convexa" es en realidad un cuenco y sigue
   al observador.
4. Orbitar más y activar **Resaltar paredes**. Aparecen en rojo los
   triángulos estirados donde se rompe la ilusión; el panel muestra θ y el
   % de paredes.
5. Mover el slider **s** (0 = plano, 1 = inversión completa) y cambiar la
   **estrategia** (Global / Por objeto / Híbrida) para ver cómo cambian las
   paredes. Ojo: en esta escena Por objeto no da menos paredes que Global
   (ver Desviaciones).
