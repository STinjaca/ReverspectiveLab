# ReverspectiveLab — guía para Claude Code

App macOS (SwiftUI + Metal + ModelIO) que genera reverspectivas a partir de
escenas 3D. Proyecto final de Computación Visual Interactiva (Uniandes).
Autor: Santiago. Él escribe gran parte del código y está aprendiendo Swift y
Metal: el código tiene que poder leerse y aprenderse.

## Estructura
- `App/` — SwiftUI: ventana, `MetalView` (NSViewRepresentable) y panel.
- `Rendering/` — todo lo que toca Metal: `Renderer`, `FotosC`, `PasadaFotos`, …
- `Scene/` — escena de prueba, objetos, layout de vértices.
- `Core/` — matemática pura (solo simd/Foundation, **sin Metal**), con pruebas en `swift test`.
- `Shaders/Shaders.metal` — todos los shaders.
- `docs/` — requisitos por release y `BITACORA.md`.

## Comandos
- Compilar: `xcodebuild -project ReverspectiveLab.xcodeproj -scheme ReverspectiveLab -destination 'platform=macOS' build`
- Pruebas del núcleo: `swift test`

## Convenciones
- Nombres del dominio en español (`camaraC`, `fotos`, `pivote`, `pieza`); los términos de API de Apple quedan en inglés.
- Doc comments `///` que explican el **porqué**. Comentarios cortos en español.
- Un commit por cambio lógico; cada commit compila. Mensajes en inglés, en imperativo.
- Ramas: una por hito (`feat/<hito>-<nombre>`), creada desde `main`. Se integra con `git merge --no-ff` al pasar sus criterios, y luego se borra. Nunca hacer commits directamente en `main`. Los releases son tags anotados sobre `main` (`v0.2.0`), no ramas.
- Sin dependencias externas.
- Structs Swift ↔ Metal (`Uniforms`, `SceneUniforms`, …): se cambian **los dos lados en el mismo commit**, con tamaños medidos con `MemoryLayout<T>.stride`.
- Píxel (i, j): i = columna, j = fila desde **arriba**. NDC y hacia arriba. Detalle en `docs/REQUISITOS-v0.2.md` §3.
- Distancias de las fotos: **radiales** (`distance(punto, C)`), no el z-buffer.
- Si un requisito resulta incorrecto al medirlo, corrígelo, deja el porqué en el commit y anótalo en `docs/BITACORA.md` → "Desviaciones".

## Invariantes que no se rompen
- La cámara C de las fotos es fija y está separada de la cámara del visor.
- Desde C, la pieza invertida se ve igual que la escena original (hay una autoprueba).
- Los índices de la rejilla dependen solo de N, no del contenido de las fotos.
