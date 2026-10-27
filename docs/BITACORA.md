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

## Desviaciones

_(ninguna por ahora)_
