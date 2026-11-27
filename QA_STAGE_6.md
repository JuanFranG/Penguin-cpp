# Penguin cpp 0.5.5 — validación de entrega

La fase 6 reúne las correcciones de las etapas 1–5, comprueba su integración y
prepara los artefactos. Este informe diferencia las pruebas realizadas y sus límites.

## Mejoras de uso de bibliotecas Windows

`windows.h` se compila con MinGW y se ejecuta mediante el runtime Windows, sin
reescribir el programa. `conio.h` conserva esa misma ruta. Los cambios de esta
versión evitan ejecutar un binario anterior cuando falla el compilador, conservan
el trabajo al guardar, recuperan una preparación privada incompleta y coordinan
CRT/entrada/salida de consola con perfiles UTF-8, OEM 437 y ANSI 1252. Las llamadas
explícitas del programa conservan prioridad. Un perfil no corrige codificaciones
mezcladas ni implementa APIs Win32 que el runtime no soporte.

`math.h`, `stdlib.h` y la biblioteca estándar siguen disponibles según el destino.
El encabezado `bits/stdc++.h` común sigue incluido. No se añadió WinBGIm ni
compatibilidad general con todas las bibliotecas Windows. Los recursos `.rc` y
`.res` no admitidos fallan de forma explícita; sus metadatos `.dev` se conservan.

## Actualizaciones y notas

- Acerca de: panel compacto con Juan Francisco Gonzalez Pacheco destacado como
  creador, versión enlazada a su publicación y enlaces a GitHub, documentación y
  GPL-2.0-or-later. La licencia completa no ocupa el diálogo; los créditos
  históricos y de asistencia de IA están en un botón separado.
- Actualizaciones: enlaces permanentes a GitHub y a novedades. Al detectar una
  publicación válida, el segundo apunta a ella; si falla la red, conserva el de
  la versión instalada. No es necesario aceptar instalar para leer los cambios.
- Cada versión requiere sus notas con cambios, validación y límites. El workflow
  de publicación prepara un borrador hasta completar los artefactos.
- El constructor del PKG copia explícitamente `console-startup.c`. Los paquetes
  nativos lo incorporan como recurso versionado. La actualización conserva el
  canal completo o nativo de la instalación anterior.

## Resultados de validación

- Local macOS: Default/Debug y suites ParserTest, PlatformTest, GdbMITest,
  GdbEngineTest, DapEngineTest, MakefileTest, UpdateTest, WindowsGameTest y
  SafetyTest correctas (GDB real se omite si no está instalado).
- Ocho pruebas de selección de canal, reemplazo, recuperación y cancelación de
  permisos del instalador; la autorización se pide antes de tocar la app anterior.
- Actualización con bundles reales: copia completa 0.5.0 → 0.5.5 correcta;
  un DMG nativo se rechaza y conserva 0.5.0. Se usan hdiutil/codesign/ditto reales,
  copias desechables y transporte GitHub sustituido por archivos locales.
- Consola real macOS: seis casos (C/C++ × UTF-8/OEM 437/ANSI 1252), con acentos,
  cuadros, entrada, cursor, colores y restauración del modo de terminal correctos.
- Cabecera de Acerca de a 480 y 640 puntos: panel azul de ancho completo e imagen
  proporcional. Captura Qt5 inspeccionada; comprobaciones de geometría Cocoa y Qt5.
- Diálogos reales Cocoa: links de novedades con versión disponible y fallo de red;
  Acerca de compacto; controles sin solapamiento. Se guardan capturas del arnés.
- Bienvenida: `PanelRight.AutoSize` movía los botones al origen en Qt5. Se
  desactivó y se comparte la distribución de filas; regresión a 1024×768 y
  1440×900 para Nuevo/Abrir/Opciones y acciones secundarias.
- PKG: extracción completa, verificación de firma de la app y presencia/hash de
  `console-startup.c`, self-test, bits/stdc++.h, licencias y actualizador; manifiesto
  revisado y binarios ARM64 del compilador, Wine y Make.
- [CI Linux/Qt5](https://github.com/JuanFranG/Penguin-cpp/actions/runs/45912623921): Release/Debug, suites, formularios, plegado,
  empaquetado/lintian, instalación, arranque y retirada del `.deb` correctos.
  Se comprueban los seis casos reales de consola con LLVM-MinGW/UCRT y Wine.
- APT firmado con clave desechable: instalada 0.3.0, retiradas sus herramientas
  Windows; `apt update` conserva 0.3.0 y `apt-get install --only-upgrade`
  instala 0.5.5, Wine y el compilador incluido sin indicar rutas.
- [CI macOS 26/Cocoa](https://github.com/JuanFranG/Penguin-cpp/actions/runs/45912624020): compilaciones, suites, integración del IDE,
  formularios/plegado, DMG y estructura de Installer correctos.
  El motor completo se valida localmente; el runner no reproduce ese motor.

## Límites que requieren otro entorno

Se instaló realmente el PKG completo con autorización del usuario mediante
Installer: la copia de `/Applications` pasó de 0.4.0 a 0.5.5 y el recibo del sistema
confirmó la versión. Se respaldó la app anterior. Desde la app instalada, un
arranque directo con HOME/configuración temporales preparó el entorno privado,
escribió `ready` y ejecutó el self-test `PENGUIN_WINDOWS_READY` con resultado correcto.
La instalación se realizó en Apple Silicon/macOS 27.2.1. El hash del ejecutable
instalado coincide con el de la app del PKG local validado. Ambos DMG pasan `hdiutil verify`
y la app completa pasa `codesign --verify --deep --strict` con firma ad hoc.
Una copia con cuarentena fue rechazada por `spctl`: no hay Developer ID/notarización.
No se considera una instalación en un Mac limpio ni acredita notarización o
aceptación automática por Gatekeeper. Se mantiene macOS mínimo 26.0/ARM64.

No se acredita compatibilidad con macOS futuro ni todas las combinaciones de
pantallas, idiomas, fuentes, impresión/PDF y exportaciones. Se mantienen los
límites de lectura de preferencias malformadas y de APIs del runtime. Los
paquetes macOS siguen siendo experimentales, con firma ad hoc y sin Developer ID.

## Compilador de Linux y alcance del texto

La prueba con GCC/MinGW del sistema detectó que MSVCRT convierte incorrectamente
algunos bytes UTF-8 de `printf`, aunque `WriteConsoleA/W` funcione. No se ocultó
esa diferencia: el `.deb` amd64 incorpora el LLVM-MinGW UCRT oficial 20261104,
con SHA-256 `919380403de87dca3c581c2053230cd298af5e891286628ba0613b7fed370926`.
La detección existente prefiere ese árbol incluido. Sus licencias se conservan;
el código MinGW-w64/gendef corresponde a las fuentes fijadas ya distribuidas.
Un compilador personalizado con MSVCRT sigue teniendo sus límites originales.

El lector de la prueba PTY reconoce las secuencias de cursor que Wine intercala
entre letras antes de enviar la entrada; mantiene las comprobaciones reales de
texto, teclado, colores y salida. Esto corrige el arnés sin relajar el contrato.

La matriz de Linux con UCRT detectó además pérdida de salida C++ al convertir
UTF-8 byte a byte en Wine 9. Por ello se incorpora un motor WineHQ 11
privado, con binarios originales fijados por SHA-256, licencias y fuentes exactas
junto a sus recetas Debian. El paquete separado permite la distribución APT
sin superar el límite de tamaño por archivo de GitHub Pages. La prueba exige
texto C++ completo y el self-test real del entorno; no se omiten esas aserciones.

La [prueba independiente de WineHQ 11](https://github.com/JuanFranG/Penguin-cpp/actions/runs/45912624034)
pasa los seis casos y el self-test del entorno. La matriz también pasa con el
runtime reubicado y sin símbolos de depuración instalado desde su `.deb`.
UTF-8 activa la conversión multibyte del CRT en C y C++; OEM/ANSI conservan sus
páginas específicas. Ambas pruebas mantienen las aserciones de texto completo,
entrada, atributos, cursor y restauración de la terminal.

Las acciones de caché y artefactos usan Node.js 24 directamente; la ejecución
macOS ya no contiene la advertencia de retirada de Node.js 20. La nota sobre
capacidad de runners ARM64 corresponde a la infraestructura de GitHub.

## Ensamblado público de macOS en CI

La subida local de varios GB resultó demasiado lenta. El flujo manual
`Complete macOS release` reensambla el PKG y DMG públicos desde el DMG nativo
0.5.5 ya validado y únicamente los árboles de dependencias del PKG 0.5.0,
fijado por SHA-256. No reutiliza el ejecutable ni los recursos propios antiguos.
Comprueba que Source/Compat/Lang/Templates y el constructor coinciden con el tag;
valida las firmas ad hoc, el contenido del PKG y ejecuta su self-test con un
prefix temporal. Publica un manifiesto de hashes y el registro. El contenedor
público se genera en CI; Installer real se probó con el candidato local 0.5.5.
