# Penguin cpp: estado y hoja de ruta

Penguin cpp es un IDE de C/C++ **nativo para Linux**: editor con resaltado,
navegador de clases, autocompletado, proyectos, plantillas, compilación con
gcc/g++ y depuración con gdb. Expande a Linux Embarcadero Dev-C++, que solo
funciona en Windows.

Este documento explica de dónde viene, qué se ha hecho hasta ahora y qué
falta.

*Última actualización: 28 de octubre de 2026. Versión 0.2.0.*

---

## Objetivo

- **Propósitos educativos y de divulgación**:
  - Que estudiantes y docentes tengan en Linux, nativo y libre, el IDE con el
    que mucha gente aprende C y C++.
  - Documentar abiertamente cómo se lleva un IDE de Windows a Linux.
- **Producto final: un paquete `.deb`** para Debian, Ubuntu, Linux Mint y
  derivadas. Se instala con `apt` y deja el IDE listo para compilar y
  depurar. Todas las fases apuntan a eso; la fase 8 arma el paquete.
- **Después: macOS** (fase 9, en curso), con el mismo código, para Macs con
  Apple Silicon.

---

## De dónde viene

Dev-C++ tiene una historia larga de forks:

1. **Bloodshed Dev-C++** (Colin Laplace).
2. **Orwell Dev-C++** (Johan Mes).
3. **Embarcadero Dev-C++**, hecho con Delphi y la VCL. Solo funciona en
   Windows, con MinGW/TDM-GCC.

Penguin cpp toma ese código como punto de partida, importado con todo su
historial en el commit `3832494`. El remoto `upstream` apunta al repositorio
original para poder comparar.

A partir de ahí el proyecto sigue su propio camino. Ya no compila con
Delphi ni apunta a Windows: usa Lazarus/Free Pascal, la LCL, el gcc del
sistema y las convenciones de Linux.

Penguin cpp **no es un producto de Embarcadero** ni está afiliado a ninguno
de los proyectos anteriores. Se conservan sus avisos de copyright, como pide
la GPL (ver [Licencia y créditos](#licencia-y-créditos)).

---

## Decisiones técnicas

| Tema | Decisión |
|---|---|
| Lenguaje | Free Pascal 3.2.2 en `{$MODE DELPHI}`, para cambiar lo mínimo la sintaxis del código original |
| Entorno | Lazarus 3.0, la versión que trae Linux Mint 22 / Ubuntu 24.04 |
| Delphi | **Solo Lazarus.** El proyecto ya no compila con Delphi. Algunas unidades todavía tienen ramas `{$IFDEF FPC} … {$ELSE}` que se pueden limpiar |
| Interfaz | LCL con **Qt5** (`--ws=qt5`). La primera ejecución fue con GTK2; Qt6 no está en Linux Mint 22 / Ubuntu 24.04, así que se pasa a Qt6 con Mint 23 (ver fase 4) |
| Editor | SynEdit de Lazarus en lugar del SynEdit de Delphi, con una capa de compatibilidad (`SynEditCompat.pas`, `TSynEditEx` en `Editor.pas`) |
| Iconos | Las listas SVG se renderizaron una sola vez a tiras PNG (`Source/Images/IconLists`), que se incrustan como recursos |
| Configuración | `~/.config/penguin-cpp/` (respeta `$XDG_CONFIG_HOME`), o `config/` junto al programa en modo portable |
| Procesos | `TProcess`; abrir archivos y URLs con `xdg-open` (todo en `devPlatform.pas`) |
| Distribución | Paquete **`.deb`** (Debian, Ubuntu, Linux Mint y derivadas, amd64) |
| Licencia | GPL v2 o posterior. Los archivos nuevos llevan cabecera `SPDX-License-Identifier: GPL-2.0-or-later` |

---

## Cómo compilar y probar (Linux)

Requisitos (Mint 22 / Ubuntu 24.04):

```bash
sudo apt install lazarus fpc g++ gdb make git python3 lcl-qt5-3.0 libqt5pas-dev
```

Compilar el IDE con Qt5. El ejecutable `penguin-cpp` queda en la raíz del
repo, junto a `Lang/`, `Templates/` y `Help/`:

```bash
lazbuild -B --ws=qt5 Source/penguin-cpp.lpi
./penguin-cpp
```

Con `--bm=Debug` se compila `penguin-cpp-debug`, con las comprobaciones de
memoria (ver la fase 4). `--ws=gtk2` sigue funcionando.

Si usas conda, desactívalo antes (`conda deactivate`): sus bibliotecas
pueden interferir con el enlazado.

Pruebas de consola:

| Prueba | Qué comprueba | Necesita |
|---|---|---|
| `Source/Tests/ParserTest/build.sh --run` | El parser de C++ con las cabeceras reales del sistema (`<iostream>`, `<vector>`…) y el preprocesador (`#if/#elif/#else`) | fpc, g++ |
| `Source/Tests/PlatformTest/build.sh --run` | Procesos, carpeta de configuración, abrir archivos, monitor de archivos y que el compilador hable en inglés | fpc |
| `Source/Tests/MakefileTest/build.sh --run` | Los nombres en los Makefiles de los proyectos: compila, ejecuta y limpia con make y cc un proyecto con espacios, apóstrofos, `$(…)`, comillas invertidas, una subcarpeta y una carpeta de objetos relativa | fpc, make, cc |
| `Source/Tests/LfmCheck/check.sh` | Que cada formulario (`.lfm`) solo use clases, propiedades, valores y eventos que existen, y que cada evento tenga los parámetros de su tipo | lazbuild, python3 |
| `Source/Tests/FoldTest/build.sh --run` | Dónde abre y cierra el plegado de C++ (llaves, regiones, llaves en cadenas y comentarios) y que `Tests/Folds/main.cpp` quede balanceado | lazbuild |

En GitHub, cada push compila el IDE con Qt5 (Release y Debug) y pasa estas
cinco pruebas en Ubuntu 24.04 (`.github/workflows/build.yml`).

---

## Estado por fase

Cada fase se trabaja en su rama, que parte de la anterior, y se pasa a `main`
al publicarla. Hoy `main` incluye las fases 1 a 6 (`fase6/compilador`).

| Fase | Rama | Estado |
|---|---|---|
| 0 · Preparación | `main` | ✅ Hecha |
| 1 · Quitar lo que no se puede portar | `fase1/quitar-windows` | ✅ Hecha |
| 2 · Parser de C++ en Free Pascal | `fase2/parser-fpc` | ✅ Hecha, probada en Mint |
| 3 · Capa de sistema | `fase3/capa-sistema` | ✅ Hecha, probada en Mint; la instancia única se agregó en `fase6/compilador` |
| 4 · Port a Lazarus y formularios | `fase4/lazarus` | ✅ Abre, funciona y cierra bien en Mint con Qt5, con Buscar, Reemplazar e Ir a línea |
| 4b · Identidad visual y temas | `fase4/lazarus`, `fase6/compilador` | ✅ Icono, paleta en paneles, menús y diálogos (Qt5) y esquemas Penguin claro y oscuro, probados en Mint |
| 5 · Editor (SynEdit de Lazarus) | `fase5/editor` | ✅ Hecha, probada en Mint: impresión, exportación a RTF/TeX y plegado |
| 6 · Compilación con el gcc de Linux | `fase6/compilador` | ✅ Hecha, probada en Mint: gcc, archivos sueltos, proyectos, terminal, errores, instancia única y formateadores |
| 7 · Depurador (GDB/MI) | `fase7/depurador` | ✅ Hecha, probada en Mint, con la revisión general de errores de rango y de memoria |
| 8 · Paquete `.deb` y pulido | `fase8/paquete` | 🔄 El paquete se arma, se revisa con lintian, se instala y se desinstala en el CI; falta probarlo en un Linux Mint limpio |
| 9 · macOS (Apple Silicon) | `fase9/macos` | 🔄 Bloques 0-5 hechos: compila, ejecuta, depura con `lldb-dap`, perfila con LLVM y se empaqueta en un `.dmg`. Faltan el CI de macOS y algunas pruebas en el Mac |

### Siguiente ciclo de trabajo

Estado al 18 de octubre de 2026, probado en Linux Mint 22 con Qt5:
- ✅ gcc en la lista de compiladores, F11 compila y ejecuta en una terminal,
  y los errores aparecen en la lista y llevan a su línea.
- ✅ Instancia única, formateadores, paleta de Qt5 y esquemas Penguin.
- ✅ Buscar, Reemplazar e Ir a línea.
- ✅ Los `.dev` abren sin corromper la memoria (heaptrc: 0 errores; era un
  evento con los parámetros de Delphi, ver la fase 6).
- Corregido después de esa prueba, falta probarlo:
  - **Compilar un proyecto:** con una carpeta de objetos relativa (`obj`),
    make intentaba crear `../../../../../main.o` (permiso denegado).
  - **`Range check error`** al compilar o depurar un proyecto guardado con
    otro compilador, y el `Access violation` que seguía al ignorarlo.
  - **Opciones del compilador:** `Access violation` al abrirlas (la lista de
    opciones de la LCL no da sus propiedades durante `BeginUpdate`), y la
    lista "Compilador a configurar" cortada.
  - **Cuadros con título** (`TGroupBox`) en todos los diálogos: el contenido
    quedaba unos 16 píxeles más abajo y la última fila cortada.
  - La marca roja del error, el icono basura de Nuevo proyecto y el hilo que
    vigila archivos, que se volvía a crear al cerrar.

**1. Probar en Mint:** compilar, ejecutar y limpiar un proyecto de varios
archivos; abrir Opciones del compilador y del proyecto; y mirar que los
cuadros con título de los diálogos se vean completos.

**2. `Access violation` al cerrar después del primer arranque** (sin
`~/.config/penguin-cpp`, con el asistente inicial): Qt5 falla al destruir una
pestaña (`TQtTabWidget.DetachEvents`). Con la configuración ya creada cierra
sin errores. No se pudo reproducir fuera de Linux; hace falta la traza de
gdb, que muestra la parte de Qt:
`rm -rf ~/.config/penguin-cpp` y luego
`gdb -batch -ex "handle SIGSEGV stop nopass" -ex run -ex bt ./penguin-cpp-debug`,
y también saber si pasa sin abrir ningún archivo.

**3. Revisión general de las fases 1 a 6** (18 de octubre), por bloques:
- ✅ **A. Correcciones seguras:** la ayuda ya no carga jQuery por `http`
  desde Google (usa su copia local); `~/.config/penguin-cpp` es privada
  (0700), porque guarda los proyectos de confianza y las carpetas de
  trabajo; "Abrir con programa externo" pasa el archivo como un argumento
  aparte (un nombre con `"` agregaba argumentos); se quitaron
  `TTemplate.Save` (sin uso, con un nombre vacío) y las directivas de Delphi
  de `main.pas`.
- ✅ **B. Funciones de Windows en el código** (ver la fase 6).
- ✅ **C. Mensajes del compilador en inglés:** gcc, make y el enlazador se
  ejecutan con `LC_MESSAGES=C` (sin `LC_ALL` ni `LANGUAGE`, que lo
  anularían), porque el IDE lee sus mensajes: con gcc en español quedaban
  sin archivo ni línea, y la detección de compiladores busca las palabras
  "gcc version" y las carpetas de cabeceras en su salida. La codificación
  del usuario no cambia, y el programa que se compila corre en su idioma.
- ✅ **D. Traducción al español completa:** se tradujeron los 191 textos
  que faltaban en `Spanish.lng` y `SpanishCastellano.lng` (153 en
  `SpanishColombia.lng`); los que faltan todavía (46) ya no los usa el
  código. Siete textos en inglés que hablaban de Windows, de Dev-C++ o de
  WebUpdate se reescribieron (AStyle y clang-format dicen cómo instalarlos
  con `apt`), y Acerca de enlaza a Clang en vez de TDM-GCC. Se quitó
  `Hebrew.lng`, que era de una versión muy antigua (otros números de
  mensaje); queda `Hebrew.tips`, los consejos del día, que no se pueden
  elegir sin ese idioma.
- ✅ **E. Pruebas automáticas:** `Tests/MakefileTest` compila, ejecuta y
  limpia con make y cc un proyecto con nombres difíciles y una carpeta de
  objetos relativa (habría detectado `../../main.o`); para eso los nombres
  del Makefile pasaron a `MakeNames.pas`, sin LCL. El CI de GitHub Actions
  compila el IDE y pasa las cinco pruebas en cada push; falta ver su
  primera ejecución.
- **F. Ayuda para Linux:** sus páginas hablan de Windows, de `devcpp.exe` y
  de MinGW, y enlazan a Embarcadero. Puede ir con la fase 8.

**4. Fase 7:** el depurador sobre GDB/MI.

### Fase 0 · Preparación ✅
- Repositorio en GitHub con el historial completo del original y el remoto
  `upstream` para comparar.
- El proyecto de Lazarus (`.lpi`/`.lpr`) se creó a mano en la fase 4, en vez
  de usar el asistente de conversión.

### Fase 1 · Quitar lo que no se puede portar ✅
Se quitó todo lo que solo existe en Windows:
- Estilos VCL, vcl-styles-utils y DDetours. El aspecto lo pone el escritorio.
- El servidor DDE y las asociaciones de archivos en el registro. Se
  reemplazarán con un archivo `.desktop` al empaquetar.
- La consola embebida (`ConsoleAppHost`). Se reemplazará con una terminal
  externa.
- FastMM5. Free Pascal trae su propio gestor de memoria.
- El reporte de errores con ensamblador x86 (`ExceptionFrm`).
- Packman, PackMaker, Abbrevia y los paquetes `.devpak`. En Linux las
  bibliotecas vienen del gestor de paquetes.
- Binarios de Windows (`AStyle.exe`, `clang-format.exe`), instaladores NSIS
  y herramientas auxiliares.

### Fase 2 · Parser de C++ en Free Pascal ✅
- Se pasaron a Free Pascal `CBUtils`, `CharUtils`, `StatementList`,
  `CppTokenizer`, `CppPreprocessor` y `CppParser`.
- `IntList` se reescribió: el original tenía una licencia no comercial,
  incompatible con la GPL.
- Se corrigieron dos errores del original:
  - Las cadenas `#if/#elif/#else` podían tomar más de una rama.
  - Una división por cero en `#if` cortaba el análisis de todo el archivo.
- Prueba de consola `ParserTest`: indexa `<iostream>`, `<vector>` y
  `<string>` de libstdc++ sin errores.

### Fase 3 · Capa de sistema ✅
- **`devPlatform.pas`**: ejecutar programas y leer su salida (`TProcess`),
  abrir documentos (`xdg-open`) y carpeta de configuración XDG.
- **Monitor de archivos portable**: revisa los archivos cada 500 ms, en vez de
  usar las notificaciones de Windows.
- Linux distingue mayúsculas de minúsculas, así que:
  - Los nombres de unidades en los `uses` coinciden con los nombres de
    archivo (162 referencias).
  - El parser compara nombres de archivo con las reglas de cada sistema.
- Prueba de consola `PlatformTest`.
- ✅ **Instancia única** (`devInstance.pas`, falta probarla en Mint): abrir un
  archivo con el IDE ya abierto (`penguin-cpp main.cpp`, como hace el
  explorador de archivos) se lo pasa al IDE abierto, que lo abre y se pone
  al frente. El original usaba un mensaje de Windows; aquí el primer IDE
  escucha en un socket Unix en `$XDG_RUNTIME_DIR` (permisos 0700), así que
  ningún otro usuario puede mandarle archivos. Hay uno por archivo de
  configuración (el modo portable y `-c` son otro IDE), y un socket que dejó
  un cierre inesperado se detecta y se reemplaza.

### Fase 4 · Port a Lazarus y formularios ✅
Hecho:
- `penguin-cpp.lpi`/`.lpr`. El IDE completo **compila y enlaza** con la LCL.
- Los 39 `.dfm` pasaron a `.lfm`:
  - Se quitaron unas 700 líneas de propiedades que solo existen en Delphi.
  - `TRichEdit` pasó a `TMemo` y las listas SVG a `TImageList` con PNG.
  - Las pestañas del editor usan los botones de cerrar del sistema.
- Verificador de formularios (`Tests/LfmCheck`): 38 formularios, 10 047
  comprobaciones, 0 problemas.
- Unidades de sistema portadas:
  - `devExec` y `Debugger` lanzan los procesos con `TProcess`.
  - La lista de procesos lee `/proc`.
  - Los archivos de idioma (`.lng`) se convierten desde su página de
    códigos de Windows.
  - La pantalla completa y el arrastrar y soltar archivos usan la LCL.
- **Primera ejecución en Linux Mint** (GTK2): el IDE abre, guarda el idioma y
  la configuración, y al cerrar no deja fugas. Lo que falló al arrancar se
  corrigió:
  - Los iconos no cargaban ("Bitmap with unknown compression"): diez listas
    de imágenes seguían en el formato de Windows/Delphi. Se convirtieron, y
    el verificador de formularios ahora lo detecta.
  - Los esquemas de color salían vacíos (todo negro): venían de un recurso de
    Windows que Linux no lee (`ColorSchemes.pas`).
  - El idioma no se guardaba: la lectura de la configuración no conocía los
    tipos de Free Pascal para textos y booleanos.
  - Las barras de herramientas quedaban desordenadas: pasaron a un
    `TFlowPanel` que acomoda las barras según el ancho.
- La pantalla de bienvenida se traduce desde los archivos de idioma.

Falta:
- ✅ **Buscar, Reemplazar e Ir a línea** funcionan en Mint.
- **Verificación de memoria y seguridad:** hecha (ver abajo, con la revisión
  general del 18 de octubre). Queda valgrind, opcional.
- ✅ **Qt5**: cierra sin errores y sin memoria sin liberar.
- **Hecho cuando:** el IDE abre, se ven los menús, se puede abrir, editar,
  buscar y guardar un archivo, y cierra sin errores con Qt5.

#### Verificación de memoria y seguridad
Free Pascal protege más que C (las cadenas se manejan solas y puede comprobar
rangos), pero el código portado tenía puntos débiles: punteros, hilos,
código de 64 bits y procesos externos. Lo que se puede hacer sin interfaz
gráfica ya se hizo en la Mac; lo que necesita el IDE corriendo queda para
Mint.

Memoria:

| # | Qué | Resultado |
|---|---|---|
| 1 | Modo de compilación **Debug** con comprobaciones (`-Cr -Co -Ct -CR -Sa -gh -gl`) | ✅ `lazbuild --bm=Debug Source/penguin-cpp.lpi` genera `penguin-cpp-debug`: un índice fuera de rango es un error con archivo y línea, y al cerrar lista la memoria no liberada. Queda **usarlo en las primeras ejecuciones en Mint** |
| 2 | **31 conversiones entre punteros y enteros** | ✅ Todas guardaban números (índices, PIDs), ninguna un objeto; pasaron a `PtrInt`, el entero del tamaño de un puntero |
| 3 | **El parser de C++** con comprobaciones y entradas dañadas | ✅ Se corrigieron 4 lecturas fuera de la cadena, 3 cuelgues (macros recursivas, resultados negativos en `#if`) y una fuga en cada análisis. Con la lectura fuera de rango corregida, el parser encuentra 10 698 declaraciones en las cabeceras del sistema (se cortaba en 247). `Tests/ParserTest/fuzz.py` prueba 39 casos dañados y cientos de mutaciones; todos pasan |
| 4 | **Conversiones de posiciones del editor** (texto ↔ pantalla) | ✅ Los acentos (á, ñ) se escriben bien en Mint. Pendiente menor: pegar un emoji y moverse con las flechas a su alrededor |
| 5 | **Hilos y su ciclo de vida** | ✅ El lector de gdb podía leer de un pipe ya liberado al cerrar el IDE o al reiniciar la depuración; ahora se espera a que termine. El monitor de archivos y los menús emergentes se revisaron y están bien. ⏳ Probar una sesión de depuración en Mint (fase 7) |
| 6 | **Funciones que podían devolver basura** | ✅ `Templates` (borraba registros con cadenas usando `FillChar`), `FormatList`, `GetForInit` y `FormatMemory` |
| 7 | **Fugas y errores en la parte de GTK** | ⏳ Opcional, antes del `.deb`: valgrind (una herramienta que vigila cada lectura y escritura de memoria del programa) sobre una sesión corta del IDE, con la unidad `cmem` para que vea las asignaciones. heaptrc ya da 0 fugas |

Seguridad:

| # | Qué | Resultado |
|---|---|---|
| 1 | **Archivos temporales con nombre fijo en `/tmp`** | ✅ Los formateadores copiaban tu código a `/tmp/<nombre del archivo>` (y `DummyInput.txt`), sin borrarlo; otro usuario podía dejar un enlace con ese nombre. Ahora usan `~/.cache/penguin-cpp/tmp/` (permisos 0700) y borran la copia |
| 2 | **Cómo se lanzan los programas** | ✅ Ningún comando del IDE pasa por `/bin/sh`, así que `$(...)`, `;` y comillas invertidas en nombres de archivo son texto literal; un nombre con `"` se rechaza. Los Makefiles citan cada nombre (fase 6). Queda gdb, que arranca el programa con sus argumentos a través del shell (fase 7) |
| 3 | **Revisión general (18 de octubre)** | ✅ Corregido: compilar sin compilador instalado (puntero nulo); el análisis de C++ dejaba entrar clics y pintado mientras liberaba sus declaraciones (`ProcessMessages`); cerrar durante una compilación; una carrera al detener el programa; "Limpiar" podía borrar otro archivo llamado como el fuente sin extensión; imprimir nunca usa `/tmp`; un `Invalid type cast` al arrancar en el modo Debug (el navegador de clases como `TTreeView`), que cortaba la carga de los compiladores. Las traducciones con menos `%d` que el inglés no fallan (`Format` ignora lo que sobra) |

Para probar en Mint con el modo Debug:

```bash
lazbuild --bm=Debug Source/penguin-cpp.lpi
./penguin-cpp-debug
```

Al cerrarlo, la terminal muestra la memoria no liberada con archivo y línea.
Si lazbuild da un "Internal error" del compilador después de cambios, se
compila todo de nuevo con `-B`.

Los pendientes de seguridad de otras fases ya se resolvieron (instancia
única, Makefiles, `INTERNAL_DEL` y proyectos de terceros, en las fases 3 y
6), salvo gdb (fase 7). `SECURITY.md` resume las reglas.

#### Biblioteca gráfica (decidido: Qt5 ahora, Qt6 con Mint 23)
La biblioteca gráfica es la que dibuja las ventanas, botones y menús. En
Lazarus el código y los formularios son los mismos para todas; se elige al
compilar (`--ws=gtk2`, `--ws=qt6`…). Cambiarla no es reescribir nada, pero sí
cambia las dependencias del `.deb`, algunos tamaños de los controles y las
rarezas de cada una, así que hay que volver a probar todo.

| | GTK2 | GTK3 | Qt5 (hoy) | Qt6 |
|---|---|---|---|---|
| Estado en Lazarus | El más probado | Verde en 3.0; mejor en 4.x, con detalles | Maduro | Maduro (comparte código con Qt5) |
| Mantenimiento de la biblioteca | Abandonada desde 2020 (sigue funcionando y viene en Mint 22) | Mantenida | Sin soporte libre desde 2023; las distribuciones la parchean | Activa |
| Wayland | Solo a través de XWayland | Nativo | Nativo | Nativo |
| Pantallas HiDPI | Pobre | Bien | Bien | La mejor |
| Temas con la paleta del icono | Formato viejo (`gtkrc`); depende del tema del escritorio | Lazarus lo expone poco | Paleta y hojas de estilo para toda la app | Igual que Qt5 |
| Dependencia extra | Normalmente ya instalada | Ninguna | `libqt5pas` | `libqt6pas` + Qt6 |

Plan:
1. ✅ **Primera ejecución con GTK2.** Lo que falló era de nuestro código y ya
   está corregido.
2. ❌ **Qt6 no se puede en Linux Mint 22.** Ubuntu 24.04, su base, no trae
   `libqt6pas` ni el soporte Qt6 de Lazarus (`lcl-qt6`); aparecen en Ubuntu
   25.10 y 26.04, la base de Mint 23. Compilarlo a mano obligaría al `.deb` a
   traer su propia copia de la biblioteca.
3. ✅ **Qt5 queda como la oficial** (`sudo apt install lcl-qt5-3.0
   libqt5pas-dev`, `lazbuild -B --ws=qt5 …`). En Mint funciona mejor que
   GTK2, y trae casi todo lo que se buscaba en Qt6:
   - Funciona nativo en Wayland y en pantallas HiDPI.
   - Permite aplicar la paleta de Penguin cpp a toda la app.
   - El `.deb` solo depende de `libqt5pas1`, que está en los repositorios.
   - Qt5 ya no tiene soporte libre de Qt, pero Ubuntu 24.04 lo mantiene hasta
     2029.
4. ✅ **Error al cerrar con Qt5** ("Access violation", corregido y probado en
   Mint). gdb mostró `GETICON (this=0x0)` en `qtpagecontrol.inc`: al
   liberarse una lista de iconos, las pestañas de mensajes y de proyecto
   quitan sus iconos, y el Qt5 de Lazarus lee la ventana de cada pestaña.
   Las que nunca se mostraron no tienen, y mientras el formulario se destruye
   ya no se pueden crear. Ahora los iconos de las pestañas se quitan justo
   antes de cerrar. Las "fugas" de heaptrc eran la limpieza que el error
   cortaba.
5. **Qt6 con Mint 23**: en Lazarus, Qt5 y Qt6 comparten casi todo el código,
   así que el cambio es compilar con `--ws=qt6` y volver a probar.

GTK3 no se recomienda todavía en Lazarus.

### Fase 4b · Identidad visual y temas ✅
Hecho:
- **Icono propio** en dos versiones (`Source/Images/AppIcon/`):
  - El dibujo completo (pingüino frente al monitor) de 48 px en adelante.
  - Una versión simplificada (cabeza del pingüino y "C++") de 16 a 32 px,
    porque a esos tamaños el dibujo completo no se distingue.
  - Fondo transparente, y tamaños del estándar de Linux en
    `hicolor/<N>x<N>/apps/penguin-cpp.png`, listos para el `.deb`.
- El ejecutable lleva el icono (`penguin-cpp.ico` junto al proyecto), y todas
  las ventanas lo usan.
- La pantalla de bienvenida muestra el icono en lugar del logo de Dev-C++, y
  *Acerca de* tiene un banner de Penguin cpp. Se quitó el logo de Embarcadero.
- Las imágenes de los formularios venían en formato Delphi (`TPngImage`,
  iconos sin tamaño) y Lazarus no las habría cargado. Se convirtieron, y el
  verificador de formularios ahora revisa también esos datos.
- **Esquemas de color del editor** completos: los 14 que trae (Classic,
  Twilight, Monokai, Visual Studio Dark…) pintan todo el editor y las vistas
  previas. El resaltador C++ de Lazarus tiene 10 atributos y el de Delphi 14,
  así que los colores se asignaban por posición y quedaban corridos (el fondo
  recibía los de "Number"); ahora se asignan por nombre, y la configuración
  guardada con los colores corridos se repara sola.
- **Iconos coloridos** (los del original): elegidos como los únicos; no hace
  falta selector.
- **Paleta del icono en los paneles** (`PenguinPalette.pas`): bienvenida,
  árboles de proyecto, clases y depuración, y listas de mensajes. Si el
  esquema del editor es oscuro, los paneles usan la versión oscura, así que
  el tema claro u oscuro se elige con el esquema.

| Color | Hex | Uso en el tema claro | Uso en el tema oscuro |
|---|---|---|---|
| Azul claro | `#DAEEFC` | Fondo de los paneles | Texto |
| Azul marino | `#18395E` | Versión, enlaces, avisos "Hint" | — |
| Tinta marina | `#092543` | Texto | Fondo de los paneles |
| Azul medio | `#5789C2` | Atajos, selección, líneas del árbol | Igual, y los tipos del navegador de clases |
| Amarillo | `#FDB50B` | — | Versión, enlaces, avisos "Hint", argumentos |

- ✅ Esquemas del editor **Penguin Light** y **Penguin Dark** con esta paleta,
  junto a los 14 que ya trae, en Opciones del editor y en la configuración
  del primer arranque.
- ✅ **Paleta en toda la aplicación con Qt5** (`PenguinTheme.pas`, falta
  probarla en Mint): menús, barras, botones y diálogos toman los colores del
  icono, claros u oscuros como el esquema del editor, en el estilo Fusion de
  Qt para que se vean igual en cualquier escritorio. Con GTK2 siguen el tema
  del escritorio. La versión Qt5 se compiló en macOS (solo el enlazado
  necesita Qt).
- ✅ Fuentes de Linux en los formularios: la del escritorio (`default`) y
  `Monospace` en vez de Segoe UI, MS Sans Serif, Tahoma y Courier New; el
  editor usa DejaVu Sans Mono en vez de Consolas.
- **Hecho cuando:** con un esquema claro u oscuro, todo el IDE (editor,
  paneles, menús y diálogos) se ve con la paleta. Falta verlo en Mint.

### Fase 5 · Editor ✅
Gran parte se adelantó en la fase 4:
- `TSynEditEx` mantiene la API del editor original, que trabaja con
  posiciones en el texto de la línea. El SynEdit de Lazarus usa columnas de
  pantalla.
- Mover, duplicar y comentar líneas, con deshacer.
- Breakpoints y marcas de error en el margen, que siguen a las líneas al
  insertar o borrar.
- Resaltado de paréntesis.
- Lectura en UTF-8, o en Windows-1252 si el archivo no es UTF-8 válido; se
  guarda en la misma codificación.

Falta:
- Probar el autocompletado y los tooltips. El resaltado ya funciona.
- ✅ **Buscar, Reemplazar e Ir a línea** funcionan en Mint.
- ✅ **Plegado de código para C++** (falta probarlo en Mint). En el SynEdit
  de Lazarus el plegado lo da el resaltador, y el de C++ no lo trae:
  - `SynHighlighterCppFold.pas` (`TSynCppFoldSyn`) usa el `TSynCppSyn` de
    Lazarus para separar el texto, sin copiarlo ni cambiarlo, y abre los
    pliegues donde lo hacía Dev-C++: entre llaves (no las de cadenas ni
    comentarios) y entre `//#region` y `//#endregion`.
  - Los editores de C/C++ muestran la columna de plegado con el color
    "Folding lines" del esquema.
  - Editar → Plegar todo / Desplegar todo vuelven a funcionar, e Ir a línea
    despliega la línea buscada.
  - `Tests/FoldTest` lo comprueba.
- ✅ **Impresión** (falta probarla en Mint). El SynEdit de Lazarus no trae
  impresión, así que:
  - `PdfPrint.pas` arma páginas A4 en un PDF con fcl-pdf, que viene con Free
    Pascal: encabezado con el nombre del archivo y "página / total", números
    de línea, ajuste de líneas y tabulaciones.
  - `EditorPrint.pas` toma el texto con los colores y estilos del resaltador
    (o solo la selección).
  - El PDF va a la impresora elegida con `lp` (CUPS), o se guarda con
    "Guardar como archivo PDF…". Funciona igual con cualquier biblioteca
    gráfica.
  - La fuente es la del editor si es TrueType; si no, DejaVu Sans Mono o
    Liberation Mono (fcl-pdf 3.2.2 corre las tildes al recortar la fuente,
    así que se incrusta completa). Sin ninguna de ellas usa la Courier del
    PDF, que solo tiene ASCII.
  - Se descartó Printer4Lazarus: tiene una versión distinta para cada
    biblioteca gráfica y no compila sin interfaz, que es como se compila en
    la Mac.
  - Configurar impresión abre `system-config-printer`, si está instalado.
- ✅ **Exportar a RTF y TeX** (falta probarlo en Mint; la exportación a HTML
  ya funcionaba). El SynEdit de Lazarus solo exporta HTML, así que
  `CodeExport.pas` escribe:
  - **RTF** con los colores y estilos del resaltador, para LibreOffice Writer
    o Word. Los acentos y los emoji se guardan como Unicode.
  - **TeX**: un documento LaTeX que compila solo (`pdflatex`, con `alltt` y
    `xcolor`). Los caracteres que `pdflatex` no conoce (emoji, símbolos)
    quedan como `?`.
  - Usan los mismos fragmentos de color que la impresión
    (`EditorPrint.CollectSource`).
- **Hecho cuando:** funciona todo lo anterior, como en el original.

### Fase 6 · Compilación con el gcc de Linux 🔄
Hecho en la rama `fase6/compilador` (falta probarlo en Mint):
- ✅ **El gcc del sistema** (`devCFG.pas`, `Version.pas`):
  - Se busca `gcc` en el PATH (en Mint, `/usr/bin/gcc` del paquete
    `build-essential`) y se crean los perfiles *GCC 13.3.0 Release*, *Debug*
    y *Profiling*. También cuando la configuración guardada no tiene
    ninguno, como pasaba hasta ahora.
  - Los programas se llaman `gcc`, `g++`, `make`, `gdb` y `gprof`; sin `.exe`
    (`main.cpp` genera `main`), sin `windres` y con `.so` para las
    bibliotecas compartidas.
  - Ya no se pasan las carpetas propias de gcc con `-I`/`-L`: cambiaban el
    orden de búsqueda y rompían los `#include_next` de las cabeceras de C++.
  - Sin perfiles de 32 bits ni `-static-libgcc`, que eran para MinGW.
  - La versión se lee de `gcc -v` (y de clang, para macOS).
- ✅ **Compilar un archivo suelto** (`Compiler.pas`):
  - Las carpetas van como `"-I…"`/`"-L…"`: Free Pascal parte los comandos
    con `CommandToList`, que solo quita las comillas que rodean un
    argumento completo, y `-I"…"` llegaba a gcc con las comillas.
  - Probado con g++ real: ruta con espacios y apóstrofo, `-I` a una carpeta
    con espacios, y el mensaje de error en el formato que lee la lista.
  - Los mensajes de gcc en español (`aviso`, `nota`, `error fatal`) también
    se reconocen.
- ✅ **Ejecutar en una terminal** (`devPlatform.pas`, `devExec.pas`):
  - Se abre la terminal del escritorio (`gnome-terminal`, `mate-terminal`,
    `xfce4-terminal` o `konsole`, según `XDG_CURRENT_DESKTOP`; si no,
    `x-terminal-emulator` o `xterm`), con la opción que la hace esperar a
    que se cierre la ventana.
  - Con "Pausar programas de consola", un script de `sh` reemplaza a
    `ConsolePauser.exe`: corre el programa y muestra "El proceso terminó
    después de X segundos con el valor de retorno N" hasta Enter.
  - Los proyectos con interfaz gráfica se abren directamente.
- ✅ **Seguridad de los nombres de archivo en los comandos:** un nombre con
  `"` se rechaza con un aviso, porque cerraría el nombre y el resto pasaría
  a gcc como opciones. En la terminal, el programa y sus argumentos llegan a
  `sh` por separado: un nombre o argumento con `$(…)` es texto, no código.

- ✅ **Proyectos y Makefiles seguros** (`Compiler.pas`): cada nombre de
  archivo va escapado para `make` en las reglas (`$$`, `\ `) y entre comillas
  simples para `/bin/sh` en las órdenes (`'` como `'\''`). Probado con make
  y g++: nombres con espacios, apóstrofos, `$(…)` y comillas invertidas
  compilan, se ejecutan y se limpian, y nada de los nombres se ejecuta. Los
  nombres que `make` no admite (saltos de línea, `%`, `:`, `;`, `=`, `|`,
  `#`, `\`, `*`, `?`, `[`, `]`) detienen la compilación con un aviso. Un
  programa cuyo nombre termina en `)` se enlaza de nuevo en cada
  compilación (para make es un miembro de biblioteca), sin otro efecto.
- ✅ Sin `windres` ni archivo de recursos privado; las bibliotecas
  compartidas se compilan con `-fPIC -shared`. `make clean` usa `rm -f` y
  se quitó el modo `INTERNAL_DEL` del IDE.
- ✅ **Proyectos de terceros:** al abrir un proyecto que ejecuta comandos
  propios (Makefile propio o incluido, comandos de compilación por archivo,
  programa anfitrión, opciones con código de shell o que ejecutan
  programas, como `-wrapper`, `-fplugin`, `-specs`, `-B` o `@archivo`, o
  argumentos con caracteres del shell) el IDE muestra lo que ejecutaría y
  pregunta. La respuesta se guarda en tu configuración, no en el proyecto,
  para ese proyecto con esos mismos comandos.
- ✅ **Formateadores del sistema:** `astyle` y `clang-format` del PATH (o una
  copia junto al IDE), con su ruta entre comillas. clang-format recibía
  `--style="{…}"` con las comillas; ahora va el argumento completo entre
  comillas, y si falla se muestra su mensaje en vez de reemplazar el código.
- ✅ **Rutas de Windows:** `GetRealPath` arreglaba formas de Windows de las
  rutas absolutas y en Linux destrozaba todas (`/home/u/main.c` quedaba
  `o:e/u/main.c`): los archivos de los errores (doble clic) y el ejecutable
  de los proyectos. También se quitaron las `\` escritas a mano.
- ✅ **Terminal a elegir** en Opciones del entorno (o automática) y **clang**
  como segundo compilador si está instalado.
- ✅ **Eventos con los parámetros de Delphi:** la LCL enlaza los eventos de
  los formularios solo por nombre, así que un método escrito para un evento
  de Delphi con otros parámetros recibe los equivocados. El del árbol del
  proyecto (`OnCompare`, con el parámetro `Data` de Delphi) escribía su
  resultado en una dirección cualquiera al ordenar un proyecto de dos o más
  archivos: memoria corrupta y el IDE colgado al abrir proyectos o agregarles
  archivos. El clic en el margen de la vista previa de Opciones del editor
  tenía el mismo problema. `LfmCheck` ahora compara los parámetros de cada
  evento con los del tipo del evento.
- ✅ **La marca roja del error** se quita al mover el cursor o escribir. El
  SynEdit de Delphi avisaba del cursor con `scSelection`, y el de Lazarus con
  `scCaretX`/`scCaretY`, así que nunca se quitaba.
- ✅ **Plantillas:** Console Application, Windows Application y DLL nombraban
  sus archivos con otras mayúsculas (en Linux no se encontraban); Jackpot
  tiene ahora versión en C; DLL pasó a biblioteca compartida (`.so`), y las
  de consola ya no sugieren `getch` ni `system("pause")`.

Falta:
- **Probar los proyectos en Mint** (ver "Siguiente ciclo de trabajo").
- ✅ **Plantillas solo de Windows quitadas** (decisión de diseño: Penguin cpp
  es para Unix y Linux): *Windows Application*, *Direct3D*, *FileEditor*,
  *MDIEditor*, *WinAnim* y *Project3*, una plantilla vacía del original.
- **Plantilla OpenGL:** está hecha con WinAPI; se reescribe con freeglut o
  GLFW (fase 8) en vez de quitarla.
- ✅ **Funciones de Windows quitadas del código** (falta probarlo en Mint):
  - El programa `windres` de los compiladores, su fila en Opciones del
    compilador, la pestaña *Recursos* de los mensajes y el filtro `.rc` de
    los diálogos. Compilar un `.rc` suelto sigue avisando que en Linux no
    hay recursos. Las acciones del menú de mensajes (copiar, guardar,
    limpiar) elegían la lista por la posición de la pestaña; ahora van por
    la pestaña misma, así que quitar una no corre las demás.
  - En Opciones del proyecto, la pestaña de versión, el icono y el tema de
    XP del `.exe`. El `.dev` sigue leyendo y guardando esos datos, para no
    perderlos en un proyecto que también se compila en Windows.
  - Los tipos de proyecto se llaman aplicación gráfica, aplicación de
    consola, biblioteca estática (`.a`) y biblioteca compartida (`.so`).
  - La oferta de agregar `-lgmon` (de MinGW; en Linux el enlazado falla),
    las inserciones de código de Win32 en instalaciones nuevas y la
    importación de proyectos de Visual C++. El importador de Code::Blocks
    ya venía oculto en el original, así que el menú Importar queda oculto.
  - "Buscar compiladores" explica que busca gcc y clang en el PATH y cómo
    instalarlos; Acerca de enlaza a gcc.gnu.org.
- **Hecho cuando:** se compila y ejecuta un proyecto de consola y uno de
  varios archivos, y los errores del compilador aparecen en la lista y se
  pueden clicar.

### Fase 7 · Depurador 🔄
Rama `fase7/depurador`. El depurador del original leía la salida
`--annotate=2` de gdb, un modo que gdb ya no desarrolla, y su hilo lector
modificaba el árbol de variables de la interfaz fuera del hilo principal. Se
rehace sobre **GDB/MI** (`gdb --interpreter=mi`), la interfaz estable de gdb
para programas, por bloques:

1. ✅ **Lector de GDB/MI** (`GdbMI.pas`, sin LCL): cada línea de gdb pasa a
   un registro (respuesta, estado del programa, noticias, texto) con su árbol
   de valores. `Tests/GdbMITest` lo prueba con líneas reales de gdb y con más
   de 3000 cortes y daños: nunca falla ni pierde memoria.
2. ✅ **Motor del depurador** (pasa en el CI con gdb, sin memoria sin liberar):
   `DebugEngine.pas` es la interfaz del IDE (tipos neutros: marcos, motivo
   de parada, eventos y respuestas), y `GdbEngine.pas` su versión para gdb.
   El hilo lector solo lee y analiza; los registros pasan al hilo principal
   por una cola protegida, y cada respuesta llega a quien hizo la pregunta
   por su número (token). gdb arranca en inglés y con `mi-async on` (para
   pausar un programa que corre). gdb inicia el programa con `$SHELL`; sin
   shell (`startup-with-shell off`) parte los argumentos en cada espacio,
   con comillas o sin ellas, así que el shell se queda, siempre `/bin/sh`, y
   cada argumento va entre comillas simples: llega tal como se escribió y
   nada en él se ejecuta. `Tests/GdbEngineTest` depura de
   verdad un programa en `hola mundo.c`: breakpoint, evaluar, pila, `next`,
   `finish`, asignar, código de salida, comandos de consola, un argumento con
   `$(touch pwned)` que no se ejecuta y la pausa de un ciclo infinito. Sin
   gdb (macOS) se salta; en la Mac se probó el circuito con un gdb simulado.
3. ✅ **Terminal propia para el programa depurado** (`DebugTerminal.pas`,
   pasa en el CI): la entrada y salida de gdb son tuberías del IDE, así que
   el programa no podía leer el teclado ni mostrar su salida (`set
   new-console on` solo existe en Windows). El IDE abre la terminal del
   usuario con un pequeño script que escribe el nombre de su terminal
   (`/dev/pts/N`) en un archivo de la carpeta temporal privada, para
   `-inferior-tty-set`; espera sin leer el teclado, así lo que se escribe
   llega al programa; y al final muestra el mensaje del IDE y espera Enter.
   La prueba lo corre bajo `script(1)`: con gdb, el programa lee un número
   escrito en su terminal y responde ahí, sin mezclarse con gdb.
4. ✅ **El IDE sobre el motor** (compila; falta probarlo en Mint):
   `Debugger.pas` se reescribió sobre el motor y la terminal, y se quitó
   `DebugReader.pas`. Breakpoints (con su número de gdb, aunque el archivo
   tenga espacios), pausa al inicio de `main` como el `start` del original,
   línea activa, paso a paso, continuar, salir de la función, instrucciones,
   la caja de comandos de gdb, la pestaña Evaluar, el valor al pasar el
   ratón, modificar una variable (`a.b`, `a[2]`), señales (el aviso se
   muestra después de procesar la parada, no en medio) y el fin del programa
   (el código de salida queda en su terminal hasta Enter). Las variables
   vigiladas se evalúan en cada parada, una tras otra, y se muestran como
   árbol de sus miembros (`SplitGdbValue`, con prueba). Cada respuesta que
   espera un editor o una ventana se cancela si se cierra antes. De paso:
   `GotoBreakpoint` cambiaba `/` por `\` (en Linux no marcaba la línea
   activa) y `HasBreakPoint` comparaba punteros truncados a `integer`.
5. ✅ **Ventana CPU** (en el bloque 4; falta probarla en Mint): desensamblado
   de la función con `=>` en la instrucción actual (`-data-disassemble`),
   sintaxis Intel o AT&T, registros con su valor decimal, y la pila.
- ✅ **Revisión de memoria y seguridad de la fase 7:**
  - Pasar el ratón sobre una selección le pedía a gdb evaluarla, y gdb
    ejecuta llamadas, asignaciones y `++`/`--` en el programa: seleccionar
    `f()` o `x = 5` y pasar el ratón las ejecutaba (con "vigilar al pasar el
    ratón", en cada parada). Ahora esas expresiones se saltan
    (`MayChangeProgram`, con prueba); la pestaña Evaluar sigue evaluando todo.
  - Escribir a una tubería cuyo lector murió (gdb caído) mandaba SIGPIPE, que
    cerraba el IDE. Un manejador vacío lo evita sin cambiar la señal en los
    programas que el IDE ejecuta (`PlatformTest` prueba las dos cosas).
  - El panel del depurador corta la salida sin saltos de línea cada 64 KiB y
    guarda las últimas 5000 líneas.
  - gdb no carga el `.gdbinit` ni los scripts que traiga la carpeta de un
    proyecto (su `auto-load safe-path` no la incluye); el archivo con el
    nombre de la terminal está en la carpeta temporal privada.
  - Fuera de la fase 7, el log de Mint mostró 32 bytes perdidos en cada
    compilación: `GetFileSize` no cerraba su `FindFirst` (memoria y una
    carpeta abierta). Lo mismo en Opciones del editor y en la biblioteca de
    iconos; corregido.
6. **Adjuntarse a un proceso**, con un aviso claro cuando Linux no lo
   permite (`/proc/sys/kernel/yama/ptrace_scope`).

En macOS con Apple Silicon no hay gdb: la fase 9 usa **lldb** a través de
`lldb-dap` (el Debug Adapter Protocol, que viene con las herramientas de
Xcode) detrás de la misma interfaz del bloque 2 (`DapEngine.pas`), sin rehacer
esta fase.

- **Hecho cuando:** funcionan los breakpoints, el paso a paso, las variables
  vigiladas, la pila de llamadas y ver valores al pasar el ratón.

### Fase 8 · Paquete `.deb` y pulido 🔄
El producto final del proyecto es un `.deb` que se instala con
`sudo apt install ./penguin-cpp_<versión>_amd64.deb`.

**Hecho** (rama `fase8/paquete`):
- El IDE instalado encuentra sus archivos: el programa va en
  `/usr/lib/penguin-cpp/` (con un enlace en `/usr/bin`) y busca `Lang/`,
  `Templates/`, `Help/` e `Icons/` junto a él o, si no están, en
  `/usr/share/penguin-cpp/` (`devPlatform.GetDataDir`, probado en
  PlatformTest). Las plantillas que crea el usuario van a
  `~/.local/share/penguin-cpp/Templates/`.
- `packaging/`: descripción del paquete (`control.in`), licencias
  (`copyright`), `changelog`, lanzador `.desktop` (en el menú; en "Abrir con"
  para C y C++; abre los proyectos `.dev`), el tipo de archivo `.dev` con su
  icono y las páginas de manual en inglés y español.
- `packaging/build-deb.sh` arma `build/deb/penguin-cpp_<versión>_amd64.deb`
  y lo revisa con lintian. Dependencias: gcc, g++, make, gdb, astyle,
  clang-format, cups-client, fonts-dejavu-core y una terminal, más las
  bibliotecas que encuentra `dpkg-shlibdeps` (libqt5pas1). Las fuentes Heebo y
  Source Code Pro van en `/usr/share/fonts/truetype/penguin-cpp/`.
- El CI arma el paquete, lo revisa con lintian, lo instala con `apt`, abre el
  IDE instalado (comprueba que lee sus archivos de `/usr/share`), lo
  desinstala, revisa que no quede nada y guarda el `.deb` como artefacto.
- Responsable del paquete: Juan Francisco Gonzalez Pacheco
  <jfgonzalez@unimagdalena.edu.co>.

**Publicada:** probada en Linux Mint 22; la versión 0.1.0 está en Releases y
en el repositorio APT (<https://juanfrang.github.io/Penguin-cpp/>), firmado
con una clave que solo está en los secretos de GitHub.

Lo que se planeó:

- **Rutas de instalación** (requiere cambios en el código):
  - Hoy el IDE busca `Lang/`, `Templates/` y `Help/` junto al ejecutable
    (`devCFG.pas`). Instalado, el ejecutable va en `/usr/bin` y los datos en
    `/usr/share/penguin-cpp/`, así que hay que enseñarle a buscarlos ahí.
    Otra opción es instalar todo en `/usr/lib/penguin-cpp/` con un enlace
    en `/usr/bin`.
  - Lanzador `.desktop` en `/usr/share/applications`.
  - Iconos en `/usr/share/icons/hicolor` (ya generados en
    `Source/Images/AppIcon/hicolor`).
  - Asociación con archivos `.c`, `.cpp`, `.h` y proyectos `.dev`, con los
    iconos de `Source/Images/associations` pasados a PNG.
  - Fuentes Heebo y Source Code Pro en `/usr/share/fonts`.
- **Dependencias del paquete**: `gcc`, `g++`, `make`, `gdb` y la biblioteca
  gráfica (`libqt5pas1`). Recomendadas: `astyle`, `clang-format`, `cups-client`
  (`lp`, para imprimir) y `fonts-dejavu-core` (la fuente de los PDF).
- **Construcción**: un script que compila con `lazbuild` y arma el paquete
  (`dpkg-deb` o debhelper). El paquete se revisa con `lintian`.
- `sudo apt remove penguin-cpp` no debe dejar archivos. La configuración de
  cada usuario queda en `~/.config/penguin-cpp`.
- Probar X11, Wayland, pantallas HiDPI y tema oscuro (en Linux el tema lo
  pone GTK).
- Otros formatos (AppImage, Flatpak) quedan fuera del plan por ahora.
- **Hecho cuando:** en un Linux Mint 22 limpio:
  - El `.deb` se instala con `apt` y el IDE aparece en el menú.
  - Se compila, ejecuta y depura un "Hola mundo".
  - Se desinstala sin dejar rastros.

### Fase 9 · macOS (Apple Silicon) 🔄
Lazarus también compila para macOS con la interfaz nativa (Cocoa), así que se
usa el mismo código: todo lo de macOS va con `{$IFDEF DARWIN}` o en unidades
propias, y Linux no cambia (el CI lo sigue comprobando). Rama `fase9/macos`.

**Decisiones:** solo Apple Silicon; sin cuenta de Apple Developer: la app se
sella ad hoc (`codesign -s -`, sin identidad) y la primera vez cada usuario la
autoriza en *Privacidad y seguridad*. Sin ese sello, el programa lleva solo la
firma que le pone el enlazador, que no cubre el resto de la app, y macOS dice
que una app descargada así "está dañada". Las
pruebas se hacen en local, en el Mac del autor.

**Herramientas** (en `tools/`, fuera del repositorio, sin instalar nada en el
sistema):
- FPC 3.2.2 no puede enlazar programas Cocoa con el Xcode actual (el
  enlazador de Apple rechaza sus listas de métodos y el antiguo ya no existe).
  Se usa **FPC 3.2.4 rc2**, compilado desde su código, con **Lazarus 3.8**.
- `lazbuild` 3.0 y 3.8 dan el error interno 200611031 de FPC al compilar por
  partes: siempre con `-B`.

**Hecho:**

| Bloque | Qué | Dónde |
|---|---|---|
| 0 · Compilador | El IDE compila con FPC 3.2.4 y Lazarus 3.8. FPC 3.2.4 añadió a `System.UITypes` tipos con nombres de la LCL (`TCloseAction`, `TFontStyles`…): `System.UITypes` va antes de la LCL o se quitó | Todas las unidades de Delphi |
| 1 · Sistema | Configuración y plantillas del usuario en `~/Library/Application Support/penguin-cpp`, temporales en `~/Library/Caches`; los datos dentro de la `.app` (`Contents/Resources`); los programas corren en Terminal.app (un archivo `.command` con la pausa y el tiempo, que se cierra solo; no pide permisos); la lista de procesos sale de `ps` | `devPlatform.pas`, `devInstance.pas` |
| 2 · Compilador de C/C++ | El clang de Apple; el autocompletado lee las cabeceras del SDK (las carpetas que da el propio compilador, también en Linux); el depurador es `lldb-dap` (con `xcrun`) | `devCFG.pas`, `Version.pas` |
| 3 · Interfaz | Modo claro u oscuro de macOS según el tema; atajos con ⌘ (salvo los que macOS se reserva: ⌘Espacio, ⌘Tab, ⌘H, ⌘M, ⌘Q); teclas del Mac en el editor (⌘ y ⌥ con flechas y borrar); Menlo como fuente (Cocoa dibuja mal Heebo y Source Code Pro) y sin cursivas; zoom con ⌘ + rueda; selectores de fuente nativos; pestañas a la izquierda (Cocoa centra las suyas); la bienvenida con botones propios | `MacSupport.pas`, `PageTabs.pas`, `WelcomeTiles.pas`, `main.pas` |
| 4 · Depurador | Motor nuevo sobre `lldb-dap` (Debug Adapter Protocol): puntos de parada, parar en `main`, paso a paso, pila, pausa, evaluar y asignar, estructuras y arreglos escritos como gdb (para las vigilancias), desensamblado y registros, comandos de lldb desde el panel, errores cortos como los de gdb, la terminal del programa | `DapEngine.pas`, `Tests/DapEngineTest` |
| 2b · Perfilador | Sin gprof en macOS: se compila con `-fprofile-instr-generate` y `llvm-profdata` lee cuántas veces se llamó cada función (sin tiempos ni grafo), en la misma ventana | `ProfileAnalysisFrm.pas`, `Version.pas` |
| 5 · `.app` y `.dmg` | `packaging/build-macos.sh` arma `Penguin cpp.app` (`Info.plist` con "Abrir con" para C/C++ y proyectos `.dev`, icono `.icns`, idiomas, plantillas, ayuda) y `Penguin-cpp-<versión>-arm64.dmg` con un LEEME para abrirla la primera vez, sellada ad hoc; astyle compilado desde su código va dentro de la app; `packaging/install-macos.sh` la instala con una línea (`curl … | bash`, sin el aviso de Gatekeeper); si faltan las Command Line Tools el IDE ofrece instalarlas; zoom con el pellizco del trackpad | `packaging/`, `devPlatform.pas`, `MacSupport.pas` |

Lecciones de Cocoa: las cabeceras Cocoa de FPC detienen al compilador al
generar información de depuración (error interno 200609171), así que las
pocas funciones del sistema se declaran a mano; `TProcess` descarta los
argumentos vacíos; un control oculto no avisa cuando se mueve; ⌃Espacio es
de macOS si hay varias fuentes de entrada (se libera en Ajustes > Teclado).

**Falta:**

| Bloque | Qué | Cómo |
|---|---|---|
| 6 · CI de macOS | El CI solo prueba Linux | Un trabajo en un runner de GitHub con Apple Silicon: FPC 3.2.4 y Lazarus 3.8 (en caché), el IDE, las pruebas (con `DapEngineTest`) y el `.dmg` como artefacto; `release.yml` lo adjunta al Release y la página de GitHub Pages ofrece las dos descargas |
| Pruebas pendientes | Abrir el `.dmg` descargado (sellado ad hoc), adjuntar el depurador a un proceso (`attach`), el modo oscuro completo, la ventana CPU | En el Mac |

| Parte | Linux | macOS |
|---|---|---|
| Interfaz | Qt5 | Cocoa |
| Atajos | Ctrl | ⌘ (Command) |
| Compilador | gcc/g++ del sistema | clang de Apple (`xcode-select --install`) |
| Depurador | gdb (GDB/MI) | lldb-dap (DAP) |
| Terminal | la del escritorio | Terminal.app |
| Configuración | `~/.config/penguin-cpp` | `~/Library/Application Support/penguin-cpp` |
| Distribución | `.deb` y repositorio APT | `.app` en un `.dmg` |

- **Hecho cuando:** en un Mac con Apple Silicon, el `.dmg` instala la app y
  se compila, ejecuta y depura un "Hola mundo" (lo último ya funciona desde
  el repositorio).

---

## Otros pendientes

- **Identidad propia** (la GPL cubre el código, no las marcas; "Embarcadero" y
  "Delphi" son marcas registradas):
  - ✅ *Acerca de* y los archivos de idioma dicen Penguin cpp, y los enlaces
    llevan a este repositorio.
  - ✅ `SECURITY.md` es el de Penguin cpp: versiones con soporte, cómo
    reportar en privado y qué cuida el IDE.
- ✅ **Limpieza de lo que es solo de Windows o de Delphi** (decisión de
  diseño): los componentes VCL `Source/VCL/SynEdit` y
  `Source/VCL/SVGIconImageList`; los proyectos y opciones de Delphi (`.dpr`,
  `.dproj`, `.dpk`, `.dof`, `.cfg`, `.dcr` y sus `.res`); los scripts y
  recursos de Windows (`CleanSource.bat`, `CompileResources.bat`,
  `Icons.rc`, `DefaultFiles.rc`, cuyos colores ya están en
  `ColorSchemes.pas`, y `Fonts/InstallFonts.cmd`); los iconos del `.exe` del
  original (`devcpp.ico`, `devcpp_Icon.ico`, `packman.ico`…), y en
  `Source/Tools`, `ConsolePauser` (lo reemplaza el script de pausa de la
  terminal) y `KeywordHighlighter` (tablas del SynEdit de Delphi).
- **Se quedan para adecuarlos más adelante:**
  - `Source/Images/associations/*.ico`: los iconos de `.c`, `.cpp`, `.h` y
    `.dev`, para pasarlos a PNG como iconos de tipos de archivo del `.deb`
    (fase 8).
  - `Source/README.txt`: sus instrucciones son para Delphi, pero su tabla de
    atajos de teclado va a la ayuda.
  - `Source/Tools/LangCheck`: compara los archivos de idioma con el inglés;
    su interfaz es de WinAPI y su lógica se puede portar.
  - `Icons/*.ico`, que muestra Nuevo proyecto, y `CodeToolTip.res`, que se
    enlaza, se usan tal como están.
- **Otra limpieza**, preguntando antes de borrar: `FormatterOptionsFrm`, que
  no lo usa nada; las imágenes del original que ya no se usan
  (`Source/Images/devcpplogo.png`, `splash.bmp`, `donate.bmp`…); `Tests.pas`
  y su acción *Run Tests* (desactivada; ejecutaba todas las acciones del
  menú y borraba los compiladores configurados) y la acción oculta
  *Donate*; los datos de prueba del original en `Source/Tests` (`Document`,
  `Explorer`, un proyecto de DirectX, `Parser`, `Project`, `Fail.txt`;
  `Folds` sí se usa, en `FoldTest`). `NEWS.txt` es el historial de Dev-C++ 6.3: falta uno propio.
- **Avisos de compilación**: bajaron de 118 a 29. Se quitaron la línea de
  directivas de Delphi de `main.pas` (además de 55 avisos, apagaba la
  comprobación de rangos y desbordamientos de esa unidad incluso en el modo
  Debug) y `UITypes` pasó a `System.UITypes`. Los que quedan son de APIs
  del SynEdit de Lazarus marcadas como obsoletas (`OnSpecialLineColors`,
  `CreateHTMLFragment`, `CharIndexToRowCol`), que conviene cambiar antes de
  probar Lazarus 4.x, y algunos menores.
- ✅ **Fuentes de Windows** en los formularios: cambiadas por las del sistema.
- Más adelante: probar con Lazarus 4.x.

---

## Licencia y créditos

Penguin cpp se distribuye bajo la **GNU GPL versión 2 o posterior**
(`LICENSE`, `COPYING.txt`), la misma licencia del código del que parte. Si se
distribuyen binarios, también hay que publicar el código fuente.

Autor de Penguin cpp: **Juan Francisco Gonzalez Pacheco**: Ingeniería de Sistemas, Universidad
del Magdalena.

El port se desarrolló con la asistencia de **Claude Opus 5.5**, el modelo
de inteligencia artificial de Anthropic.

Créditos del código de origen:
- Bloodshed Dev-C++: Colin Laplace y colaboradores.
- Orwell Dev-C++: Johan Mes y colaboradores.
- Embarcadero Dev-C++: Embarcadero Technologies y colaboradores.

Componentes de terceros:
- SynEdit de Lazarus (MPL/GPL).
- La LCL de Lazarus (LGPL modificada, compatible con la GPL).
- AStyle (MIT).
- Las fuentes Heebo y Source Code Pro (SIL OFL).
