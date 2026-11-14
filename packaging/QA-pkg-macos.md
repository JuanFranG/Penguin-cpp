# Validación del instalador macOS

13 de noviembre de 2026. Equipo de prueba: Apple Silicon, macOS 27.2.
Requisito del producto: **macOS 26.0 o posterior, Apple Silicon**.

## Estado de la integración completa

Se construyó el producto local de integración de 901.918.261 bytes (860 MiB):
`build/pkg-validation/Penguin-cpp-macOS26-full-UNSIGNED-INTEGRATION.pkg`.
No se instaló ni publicó; carece de firma Developer ID y notarización.
Se extrajo el producto completo: `codesign --verify --deep --strict` pasó,
el compilador reubicado compiló `self-test.cpp` y el motor extraído lo ejecutó
con salida `PENGUIN_WINDOWS_READY pid=32 sum=6` y código 0, reutilizando solo
el prefix desechable de pruebas. El requisito del plist sigue siendo 26.0.

Se añadió `build-macos-pkg.py --runtime ... --tools ...`, con LLVM-MinGW
20261104, GNU Make 4.4.1 y el subconjunto curado de MetalSharp Wine 6.5
ARM64/FEX. `--stage-app` permite revisar el mismo contenido sin instalarlo.
El motor curado conserva 169 Mach-O ARM64 simples y excluye las rutas opcionales
Microsoft/FMOD/Apple, shims Intel, Mono y Gecko. Los avisos y licencias se
conservan; falta completar las fuentes correspondientes y la revisión de
dependencias antes de publicar. Véase `Compat/WINDOWS-MODE.md`.

La aplicación prepara automáticamente un prefix privado y compila/ejecuta
un ejemplo con progreso y reintento. Automatic es el modo inicial; Native y
Windows siguen disponibles. La primera apertura y Compile & Run se probaron
en una configuración aislada sin directorio de desarrollo Apple seleccionado.
El ejemplo generó el marcador esperado. No se instaló el producto con Installer
ni se reprodujo un Mac físicamente limpio.

Las CLT ya no son necesarias para compilar en el entorno Windows del paquete: GNU
Make va incluido. Sí siguen siendo necesarias para el desarrollo nativo macOS.
El self-test curado comprueba Win32/conio/math/stdlib/STL y GDI en memoria. Una
aserción de Wine durante el primer arranque sigue registrada aunque el ejemplo
termine con código 0; esto no acredita todas las APIs ni los videojuegos.

También se corrigió el repintado de las vistas LCL en AppKit y el ancho adaptable
de los selectores. Se observaron las barras a 1440 y 1000 puntos sin solapamiento.
Release y Debug compilaron; las pruebas de configuración y comandos pasaron
sin fugas. Cinco pruebas del instalador por terminal pasaron.
9.824 comprobaciones estructurales de los 37 formularios pasaron; no equivalen
a probar visualmente cada traducción.

Los resultados siguientes describen el paquete inicial de 209 MiB y la auditoría
del archivo original; no deben confundirse con la integración curada posterior.

## Validación inicial (histórica)

Es técnicamente viable distribuir Penguin y sus herramientas permitidas en un
`.pkg`. Se ha construido un producto Installer real de aproximadamente 209 MiB,
con Penguin y LLVM-MinGW, sin instalarlo en `/Applications` ni publicarlo.
No es todavía el instalador completo de compatibilidad Windows.

Artefacto local:
`build/pkg-validation/Penguin-cpp-0.3.0-macOS26-UNSIGNED-VALIDATION.pkg`.
El número 0.3.0 procede del código actual: este artefacto no sustituye ni modifica
el release 0.3.0 publicado anteriormente.

## Qué se puede incluir

| Componente | Resultado de esta revisión |
|---|---|
| Penguin y AStyle | Incluidos. Mantener GPL, MIT y avisos; preparar fuentes correspondientes antes de distribución pública. |
| LLVM-MinGW 20261104 | Incluido para validación. Compila tras extraerse y cambiar de ruta. Se conservaron 24 archivos upstream de licencias/avisos sin cambios. Mantener las condiciones particulares de LLVM, MinGW y sus utilidades. |
| Prototipo SDL3/Metal | Su código tiene licencia MIT y SDL3 usa zlib; no está integrado ni incluido como backend Windows en este `.pkg`. |
| Wine/FEX | Los núcleos abiertos son candidatos; no se incluye el archivo completo de MetalSharp Wine porque contiene componentes adicionales pendientes de revisión. |
| Microsoft VC++, fuentes y shader compilers | Excluidos. Instalar y redistribuir son permisos distintos; no se ejecutó ningún instalador ni se acreditaron derechos de distribución para Penguin. |
| FMOD | Excluido. La licencia estándar de Engine no permite distribuirlo como parte de un motor o conjunto de herramientas; no basta declarar uso no comercial. Verificar también la procedencia de los shims del archivo, sin confundirlos con la biblioteca original. |
| Apple SDK / Command Line Tools / herramientas Metal | No copiar ni redistribuir el conjunto instalado en este Mac. Mantener la instalación oficial de Apple y su aceptación de términos separadas. El IDE aún necesita las CLT para su entorno nativo, make y depuración. |
| Metal Shader Converter / GPTK | Fuera del `.pkg` de prueba. Cualquier incorporación requiere aplicar su acuerdo específico; no se puede tratar como un SDK genérico o software íntegramente abierto. |

La atribución por sí sola no concede permisos. Este informe es una evaluación
técnica de licencias, no una certificación jurídica.

Fuentes primarias:

- [Licencias incluidas en LLVM-MinGW](https://github.com/mstorsjo/llvm-mingw).
- [Microsoft: redistribución de Visual C++](https://learn.microsoft.com/en-us/cpp/windows/redistributing-visual-cpp-files).
- [FMOD EULA, sección 1.2, punto 2](https://www.fmod.com/legal).
- [Xcode y Apple SDKs Agreement](https://www.apple.com/legal/sla/docs/xcode.pdf).
- [Empaquetado de software Mac](https://developer.apple.com/documentation/xcode/packaging-mac-software-for-distribution).
- [Notarización](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution).

## Comprobaciones realizadas

- Release y Debug compilados con destino Mach-O `minos 26.0`.
- FPC 3.2.x produce tablas threadvar sin alineación compatible con chained fixups.
  Se fijó `-no_fixup_chains` para el enlace Darwin; permanecen advertencias del
  enlazador sobre esas tablas. Las pruebas del núcleo con comprobaciones de
  ejecución y heaptrc pasaron sin fugas. La copia Cocoa con este destino arrancó
  y mostró su asistente inicial; esto no equivale a probar todas sus funciones.
- `Info.plist`: `LSMinimumSystemVersion=26.0`.
- AStyle recompilado con `-mmacosx-version-min=26.0`.
- El instalador por terminal rechaza macOS anterior a 26 antes de descargar o
  reemplazar archivos. Cinco pruebas de instalación/rechazo/recuperación pasaron.
- CI Cocoa configurado para el runner `macos-26`; no se ha ejecutado ese cambio
  en GitHub durante esta validación local.
- `pkgbuild` y `productbuild` generaron el producto con contenido local, sin
  descargas ni scripts de instalación de terceros.
- Distribution declara ARM64 y macOS >=26; Installer pudo consultar sus opciones
  con `-showChoicesXML` y habilitó el paquete en este equipo.
- El script previo solo comprueba versión, hardware, volumen y aplicación cerrada.
  Pasó en el equipo actual fuera del aislamiento que bloquea sysctl/pgrep.
- Destino fijo `/Applications/Penguin cpp.app`; sin reubicación automática.
- Sustitución del bundle declarada como `upgrade`; configuración y proyectos no
  forman parte del payload. No se ofrece garantía de recuperación ante un fallo
  real del Installer: esa prueba aún no se ha realizado.
- Extracción del producto y verificación de integridad de la app con
  `codesign --verify --deep --strict` correctas. Es una firma ad hoc del código,
  no una firma Developer ID del instalador.
- El compilador extraído generó un PE Windows x64 con `windows.h`, `conio.h`
  y el encabezado común `bits/stdc++.h`, desde una ruta con espacios.

## Auditoría adicional del motor

Se inventariaron 7.134 archivos regulares del archivo ARM64 investigado, con
184 Mach-O ARM64 simples y 4.458 PE de Windows. Estos PE Intel son destinos o
componentes de Windows; no deben confundirse con ejecutables anfitriones Intel.

También aparecieron ocho Mach-O Intel simples en assets/shims/FMOD. Que el
launcher principal sea ARM64 no demuestra que todas sus rutas opcionales
funcionen sin Rosetta. Se marcaron 26 archivos para revisión de procedencia y
licencias. El inventario por nombre/cabecera no es un análisis completo de carga
de dependencias ni una conclusión de que todos esos archivos se ejecuten.

Evidencia local: `build/pkg-validation/runtime-inventory.json`.
La prueba de consola ARM64/FEX anterior terminó con código 0; la primera creación
del prefix emitió una aserción de Wine. No se ha aprobado el motor completo,
ni su ruta gráfica Windows, ni su comportamiento futuro en macOS 28.

## Pendiente antes de publicar

- Motor curado y redistribuible, con fuentes/avisos adecuados y rutas gráficas y
  de consola probadas. No empaquetar todo el archivo de MetalSharp Wine sin esa
  revisión ni activar un runtime inexistente por defecto.
- Primera instalación y actualización reales mediante Installer, con fallo
  simulado, usuario estándar y datos existentes; disponer de un Mac limpio.
- Prueba real en macOS 26.0; ejecutar en 27.2 no la sustituye.
- Firma Developer ID Installer y notarización para la distribución habitual
  mediante Gatekeeper. `pkgutil --check-signature` confirma que el artefacto
  de validación no tiene firma. No se ha desactivado Gatekeeper ni quitado
  cuarentena para aprobarlo.
- Incrementar versión y completar la integración del actualizador si se adopta
  `.pkg` como formato de distribución. Hoy el actualizador macOS usa `.dmg`.

## Revisión del flujo incluido y de Terminal

El generador exige por defecto los tres componentes fijados y rechaza un
paquete incompleto antes de crear el producto. `--native-only` hace explícita
la validación del IDE sin motor. El diálogo compacto muestra Entorno listo
tras comprobar el compilador, Make y el motor; las rutas y GPTK son avanzados.

La aplicación se inició directamente por su ejecutable en Terminal, con una
configuración aislada y una nueva huella de entorno para forzar la preparación.
El self-test terminó con `PENGUIN_WINDOWS_READY pid=32 sum=6`, y el diálogo
mostró Environment ready sin introducir rutas. Installer habilitó el producto
mediante `-showChoicesXML`; no se ejecutó una instalación real sobre la app del
usuario. Un recibo de paquete completo obliga a comprobar componentes incluso
si falta el manifiesto; las nuevas pruebas cubren esa distinción.

El actualizador rechaza sustituir una app con entorno incluido por un DMG
nativo sin dicho entorno. Seis pruebas de instalación/recuperación/rechazo
pasaron. Eso protege el entorno existente, pero aún no proporciona un canal
público de actualizaciones completas: el motor continúa fuera de los assets
públicos hasta completar las obligaciones documentadas de redistribución.
