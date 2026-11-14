# Revisión del perfil Windows redistribuible de Penguin cpp 0.5.0

Fecha de revisión: 13 de noviembre de 2026. Perfil: `penguin-windows-foss-1`.
El alcance es el archivo upstream ARM64 v6.5 fijado por SHA-256 en
`prepare-windows-runtime.py`, el compilador LLVM-MinGW 20261104 y Make 4.4.1.
El informe, las fuentes, los avisos y los binarios deben mantenerse juntos en
la release; no autoriza redistribuir sin revisar otras versiones o añadir sus
componentes opcionales.

## Procedencia y fuentes

- MetalSharp-Wine: tag v6.5, commit `c06b0d2c4d58d51e4f2f4367089792b9051673ba`.
  Se recogen sus árboles de fuentes fijados, no las puntas actuales de las ramas.
- Wine: `bedddb0c7bc06510cf98b6a229061b91fae9eacb`; FEX:
  `f7e653decfbdc8e3e69a4792ca23454b734eb8d3`.
- Las revisiones de Mullion, WineMetalGL, WFDXCompat, DXVK y VKD3D-Proton-MacOS,
  sus submódulos y los orígenes de sus parches se registran en SOURCE-INDEX.json.
  MoltenVK usa la base `5189f8de`, el parche del árbol VKD3D fijado y
  SPIRV-Cross `c1af57390a0dd4950af578ec2135120ac218806f` de dttdrv, no la revisión
  original que sustituye ese parche.
- Las recetas `build-deps.sh` fijan las fuentes de GNU, GStreamer 1.26.7,
  FFmpeg 8.0, SDL2 y Vulkan. Se conservan las recetas de configuración y cambios,
  incluyendo las sustituciones de pruebas de funciones y los nombres de fuentes.
- LLVM-MinGW 20261104 fija MinGW-w64
  `ee9bd87644156c41072a11ad957d1e11831a72df`. Sus fuentes cubren también
  `gendef` (GPL-3.0) y `widl`, además de las condiciones de CRT/encabezados.
- Se incluyen las fuentes de Penguin del tag v0.5.0, Lazarus 3.8 y FPC 3.2.4 rc2
  de las revisiones usadas en el ejecutable. El cambio generado del texto de
  revisión de FPC se conserva como parche.
- Make y AStyle se acompañan de sus archivos de fuentes originales y recetas.

`Penguin-cpp-0.5.0-COMPAT-SOURCES.tar.gz` contiene los archivos de fuentes,
revisiones, parches, recetas y avisos. SOURCE-INDEX.json identifica cada entrada
con su SHA-256. No se sustituye esa entrega por un enlace genérico a upstream.
Los submódulos que solo contienen binarios de pruebas de FEX no se incluyen:
BUILD_TESTING está desactivado en el motor que se distribuye.

## Condiciones conservadas

| Componentes | Licencias/medidas del perfil |
|---|---|
| Penguin | GPL-2.0-or-later; fuentes del ejecutable y de su empaquetado. |
| LCL/SynEdit y RTL | Licencias de cada unidad, incluida la LGPL modificada con excepción de enlace; fuentes y textos conservados. |
| Wine y WFDXCompat | LGPL-2.1-or-later; fork exacto, parches y recetas. |
| FEX y dependencias de su compilación | MIT/BSD/Boost y condiciones particulares; fuentes y avisos de los submódulos conservados. |
| Mullion/DXMT y VKD3D-Proton | LGPL de sus archivos, con sus fuentes, dependencias y parches. |
| WineMetalGL | LGPL-3.0; fuentes y textos LGPL/GPL correspondientes. |
| Material propio de MetalSharp y del contenedor VKD3D | AGPL-3.0, según sus avisos; árboles y recetas de las revisiones utilizadas. El código de Penguin no incorpora ese código en su ejecutable. |
| DXVK, SDL2, libpng, Innoextract | Licencias permisivas de cada componente, con sus avisos intactos. |
| MoltenVK, SPIRV y LLVM | Apache/NCSA/MIT y excepciones indicadas por cada componente; fuentes de las capas modificadas y avisos. |
| DXBC converter de DXC | Implementación abierta compilada desde DXC y su parche; no es el paquete propietario de shaders de Microsoft. Se conserva su licencia NCSA/LLVM y sus avisos. |
| Make y cabextract | GPL-3.0-or-later; fuentes exactas y recetas junto a los binarios. |
| Bibliotecas GNU, GLib, GStreamer y FFmpeg | Condiciones GPL/LGPL de sus archivos. Se proporcionan fuentes y recetas. La configuración FFmpeg observada no activa `--enable-gpl` ni `--enable-nonfree`. |
| FreeType y Liberation | Licencia FreeType/GPL y OFL respectivamente; avisos, originales y script de renombrado. No se distribuyen fuentes Microsoft. |

Los avisos legibles se instalan en `Compat/windows/runtime/share/licenses/penguin-profile/`.
Las bibliotecas siguen siendo reemplazables y recompilables; el empaquetado
solo renueva firmas ad hoc, sin añadir claves privadas necesarias para ejecutar
modificaciones propias. Cada componente conserva su licencia; el paquete no
relicencia todos sus componentes bajo la licencia de Penguin.

## Exclusiones y cambios de Penguin

- Instaladores opcionales Microsoft, FMOD, shims Intel, SDK de shaders,
  Apple Metal Shader Converter y Mono/Gecko descargables: excluidos.
- No se incorpora D3DMetal/GPTK ni el SDK de Apple.
- `lib/linuxhost`: excluido. En el árbol fijado de ese módulo opcional no se
  encontró archivo de licencia ni cabeceras que declaren sus condiciones.
  No se deduce permiso de su mera presencia en el repositorio. El perfil
  publicado no proporciona el host de módulos Linux para anticheat/EAC.
- `bin/wine` se cambia por un enlace al launcher ARM64; Penguin configura las
  variables del entorno que necesita el motor. Los binarios originales se
  mantienen sin cambios de código; se reafirman sus firmas ad hoc en el paquete.
- Se añaden avisos, un índice de fuentes, la identidad del perfil y hashes.
  Las copias descargadas originales no se modifican.

Estas exclusiones limitan algunas rutas de juegos y shaders. Publicar las
herramientas no implica compatibilidad total con Windows, `graphics.h`/WinBGIm,
videojuegos o anticheat. Se conserva el alcance experimental y las pruebas de
instalación/Gatekeeper pendientes, independientes de esta revisión de fuentes.

## Fuentes primarias

- [Release y revisiones de MetalSharp Wine 6.5](https://github.com/metalsharp/MetalSharp-Wine/releases/tag/v6.5).
- [Licencias del tag v6.5](https://github.com/metalsharp/MetalSharp-Wine/blob/v6.5/docs/LICENSES.md).
- [Recetas de dependencias fijadas](https://github.com/metalsharp/MetalSharp-Wine/blob/v6.5/scripts/build-deps.sh).
- [Recetas de LLVM-MinGW 20261104](https://github.com/mstorsjo/llvm-mingw/tree/20261104).
- Los textos de licencia completos y las revisiones adicionales se conservan
  dentro de las fuentes y en NOTICES/, sin resumir ni reemplazar sus condiciones.
