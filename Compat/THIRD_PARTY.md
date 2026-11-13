# Componentes de terceros y distribución

Revisión documental del 13 de noviembre de 2026. Esta lista no autoriza por
sí misma la redistribución de un paquete ni sustituye la revisión del acuerdo
de la versión concreta. Dar crédito no reemplaza los permisos de licencia.

## Base abierta del prototipo

El código nuevo de `native/` tiene licencia MIT. El prototipo utiliza SDL3
como biblioteca separada; los binarios de SDL3 usados en las pruebas están
en la carpeta de compilación ignorada y no se incluyen en este directorio.

| Componente | Licencia upstream revisada | Implicación para el proyecto |
|---|---|---|
| SDL3 | zlib | Conservar avisos; identificar cambios; no atribuirse la autoría original. Tiene renderer Metal. |
| Wine | LGPL-2.1-or-later | Conservar licencia y avisos y satisfacer las obligaciones aplicables sobre fuentes y cambios al redistribuir el motor. No basta enlazar al sitio del autor. |
| FEX | MIT | Conservar aviso de copyright y licencia. Una adaptación o dependencia puede tener condiciones adicionales. |
| DXMT actual | LGPL-2.1-or-later | Revisar la versión exacta y sus fuentes; las versiones antiguas no tienen necesariamente la misma licencia. Solo se evaluó como candidato, no se integró. |
| MetalSharp Wine: material propio | AGPL-3.0 según el repositorio | No asumir que la licencia de sus scripts cubre todos los componentes del paquete; su distribución mezcla licencias abiertas y redistribuibles propietarios. El subconjunto curado se usa en una integración local; no se ha publicado. |

## Componentes propietarios: resultado de la revisión

La revisión detallada, los documentos y las cláusulas están en
[LICENSE-REVIEW.md](LICENSE-REVIEW.md).

- **Visual C++ Runtime 2015–2022, candidato 14.44.35211.0:** redistribución
  condicionada a los derechos de Visual Studio y a su sección de código
  distribuible. Community puede conceder derechos gratuitamente a usuarios
  que cumplan sus condiciones; no se ha comprobado la licencia del
  distribuidor de Penguin. El acuerdo del runtime por sí solo permite uso,
  pero no concede permiso general para entregarlo a terceros. No incluir aún.
- **Metal Shader Converter 4.0 beta 3:** la copia del acuerdo revisada
  (EA1844, 31/05/2023), sección 2B, concede distribución de sus bibliotecas
  `.dylib` para conversión de shaders. Es un candidato opcional para macOS,
  sujeto al resto de condiciones: hardware Apple, conservar avisos y no
  modificar el software. No extiende ese permiso a distribuir libremente
  la herramienta de línea de comandos.
- **D3DMetal/GPTK 3.0 y 4.0:** las copias revisadas del acuerdo EA18380
  (17/08/2023) tienen el mismo texto. El uso interno para desarrollar,
  probar o evaluar videojuegos para productos Apple encaja en 2A(i).
  La distribución del software Apple está limitada a fines no comerciales
  en 2A(iii), y 2C permite separar únicamente el Framework completo o
  componentes de `/redist`. No se aprueba para ejecutar aplicaciones
  Windows arbitrarias. El usuario declara fines no comerciales y desarrollo de videojuegos:
  un modo específico con ese alcance puede evaluarse bajo esas condiciones,
  sin extender el permiso a aplicaciones Windows arbitrarias.

No se han instalado estos componentes propietarios, aceptado sus acuerdos,
modificado sus binarios ni añadido redistribuibles al instalador. Las copias
Apple se obtuvieron de espejos del acuerdo: al obtener el binario real se
debe contrastar su licencia adjunta y su versión; no asumir derechos sobre
versiones futuras. Los términos de DXC, Windows SDK, fuentes de Microsoft
u otros archivos del motor no quedan aprobados por esta revisión del runtime.

Penguin puede mantener código abierto usando APIs de macOS como Metal.
Eso no convierte el framework del sistema de Apple ni un redistribuible
propietario adicional en software abierto. Si se permite un componente
propietario gratuito, debe identificarse como tal y distribuirse únicamente
cuando la licencia exacta lo autorice.

## Fuentes primarias

- SDL3: https://github.com/libsdl-org/SDL/blob/main/LICENSE.txt
- Renderer Metal: https://github.com/libsdl-org/SDL/blob/main/src/render/metal/SDL_render_metal.m
- Wine: https://github.com/wine-mirror/wine/blob/master/LICENSE
- FEX: https://github.com/FEX-Emu/FEX/blob/main/LICENSE
- DXMT: https://github.com/3Shain/dxmt/blob/main/LICENSE
- Composición de MetalSharp Wine: https://github.com/metalsharp/MetalSharp-Wine/blob/main/docs/LICENSES.md
- Microsoft: https://learn.microsoft.com/en-us/cpp/windows/redistributing-visual-cpp-files
- Metal Shader Converter: https://developer.apple.com/metal/shader-converter/

## LLVM-MinGW test toolchain

The compilation tests use upstream LLVM-MinGW 20261104, macOS universal/UCRT,
from https://github.com/mstorsjo/llvm-mingw/releases/tag/20261104 .
The toolchain is downloaded under ignored build output, not shipped in Penguin.
Its distribution contains LLVM (Apache-2.0 WITH LLVM-exception), MinGW-w64
components and their individual license notices. Preserve the upstream license
files and inspect the complete distribution before packaging it; this test does
not relicense any of its components under Penguin's GPL or the prototype's MIT.

## Integración local posterior

El paquete de integración puede incluir LLVM-MinGW 20261104, GNU Make 4.4.1
y un subconjunto curado de MetalSharp Wine 6.5 ARM64/FEX. Conserva avisos
y licencias upstream; GNU Make incluye además su tar de fuentes fijado. Se
excluyen FMOD, shims Intel, instaladores Microsoft, SDK de shaders, el conversor
Apple y las descargas opcionales de Mono/Gecko. El inventario y los hashes se
registran en `penguin-runtime.json`; véase `WINDOWS-MODE.md`.

Esto no aprueba su publicación: falta recopilar las fuentes correspondientes
completas y recetas de los componentes copyleft, y completar la revisión de
dependencias. Ningún instalador con este motor se ha publicado. La observación
anterior de herramientas no incluidas se refiere al estado previo a esta
integración local.
