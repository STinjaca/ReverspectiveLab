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

## Desviaciones

_(ninguna por ahora)_
