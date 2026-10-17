# Penguin cpp: estado y hoja de ruta

Penguin cpp es un IDE de C/C++ **nativo para Linux**: editor con resaltado,
navegador de clases, autocompletado, proyectos, plantillas, compilación con
gcc/g++ y depuración con gdb. Expande a Linux Embarcadero Dev-C++, que solo
funciona en Windows.

Este documento explica de dónde viene, qué se ha hecho hasta ahora y qué
falta.

*Última actualización: 16 de octubre de 2026.*

---

## Objetivo

- **Propósitos educativos y de divulgación**:
  - Que estudiantes y docentes tengan en Linux, nativo y libre, el IDE con el
    que mucha gente aprende C y C++.
  - Documentar abiertamente cómo se lleva un IDE de Windows a Linux.
- **Producto final: un paquete `.deb`** para Debian, Ubuntu, Linux Mint y
  derivadas. Se instala con `apt` y deja el IDE listo para compilar y
  depurar. Todas las fases apuntan a eso; la fase 8 arma el paquete.
- **Después: macOS** (fase 9), con el mismo código. Se hace una vez que la
  versión de Linux esté completa.

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
| Interfaz | LCL con **GTK2** para la primera ejecución (el widgetset por defecto de Lazarus en Linux y el más probado). Apenas el IDE abra se prueba **Qt6**, y si funciona bien queda como el oficial (ver fase 4) |
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
sudo apt install lazarus fpc g++ gdb make git python3
```

Compilar el IDE. El ejecutable `penguin-cpp` queda en la raíz del repo, junto a
`Lang/`, `Templates/` y `Help/`:

```bash
lazbuild --ws=gtk2 Source/penguin-cpp.lpi
./penguin-cpp
```

Si usas conda, desactívalo antes (`conda deactivate`): sus bibliotecas
pueden interferir con el enlazado.

Pruebas de consola:

| Prueba | Qué comprueba | Necesita |
|---|---|---|
| `Source/Tests/ParserTest/build.sh --run` | El parser de C++ con las cabeceras reales del sistema (`<iostream>`, `<vector>`…) y el preprocesador (`#if/#elif/#else`) | fpc, g++ |
| `Source/Tests/PlatformTest/build.sh --run` | Procesos, carpeta de configuración, abrir archivos y monitor de archivos | fpc |
| `Source/Tests/LfmCheck/check.sh` | Que cada formulario (`.lfm`) solo use clases, propiedades, valores y eventos que existen | lazbuild, python3 |

---

## Estado por fase

Cada fase se trabaja en su rama, que parte de la anterior, y se pasa a `main`
al publicarla. Hoy `main` incluye las fases 1 a 4 (`fase4/lazarus`).

| Fase | Rama | Estado |
|---|---|---|
| 0 · Preparación | `main` | ✅ Hecha |
| 1 · Quitar lo que no se puede portar | `fase1/quitar-windows` | ✅ Hecha |
| 2 · Parser de C++ en Free Pascal | `fase2/parser-fpc` | ✅ Hecha, probada en Mint |
| 3 · Capa de sistema | `fase3/capa-sistema` | ✅ Hecha, probada en Mint |
| 4 · Port a Lazarus y formularios | `fase4/lazarus` | 🔄 Compila; falta la primera ejecución |
| 4b · Identidad visual y temas | `fase4/lazarus` | 🔄 Icono listo; temas después de la primera ejecución |
| 5 · Editor (SynEdit de Lazarus) | `fase4/lazarus` | 🔄 Adelantada dentro de la fase 4 |
| 6 · Compilación con el gcc de Linux | — | ⏳ Pendiente |
| 7 · Depurador (GDB/MI) | — | ⏳ Pendiente |
| 8 · Paquete `.deb` y pulido | — | ⏳ Pendiente |
| 9 · macOS | — | ⏳ Después del `.deb` |

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
- Pendiente de la tabla original: **instancia única** (abrir un archivo en el
  IDE que ya está abierto). `Instances.pas` se quitó y falta reemplazarlo con
  un socket local o similar. El socket tiene que ser privado del usuario
  (en `$XDG_RUNTIME_DIR`, permisos 0700); si no, otro usuario podría mandarle
  archivos a abrir.

### Fase 4 · Port a Lazarus y formularios 🔄
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

Falta:
- **Primera ejecución en Linux Mint** y corregir lo que falle al arrancar y
  al abrir cada ventana.
  - Intento 1: se detuvo al cargar los iconos ("Bitmap with unknown
    compression"). Diez listas de imágenes seguían en el formato de
    Windows/Delphi y Lazarus leía mal su máscara; se convirtieron al formato
    de Lazarus, y el verificador de formularios ahora lo detecta.
- **Verificación de memoria y seguridad:** lo que se puede hacer sin
  interfaz gráfica está hecho; quedan las pruebas en Mint (ver abajo).
- **Decidir la biblioteca gráfica: GTK2 o Qt6** (pendiente, ver abajo).
- **Hecho cuando:** el IDE abre, se ven los menús, se puede abrir, editar y
  guardar un archivo, y quedó decidida la biblioteca gráfica.

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
| 4 | **Conversiones de posiciones del editor** (texto ↔ pantalla) | ⏳ Mint, con el modo Debug: tabulaciones y caracteres UTF-8 de varios bytes (á, ñ, emoji) |
| 5 | **Hilos y su ciclo de vida** | ✅ El lector de gdb podía leer de un pipe ya liberado al cerrar el IDE o al reiniciar la depuración; ahora se espera a que termine. El monitor de archivos y los menús emergentes se revisaron y están bien. ⏳ Probar una sesión de depuración en Mint (fase 7) |
| 6 | **Funciones que podían devolver basura** | ✅ `Templates` (borraba registros con cadenas usando `FillChar`), `FormatList`, `GetForInit` y `FormatMemory` |
| 7 | **Fugas y errores en la parte de GTK** | ⏳ Mint: valgrind sobre una sesión corta del IDE (con la unidad `cmem`, para que valgrind vea las asignaciones) |

Seguridad:

| # | Qué | Resultado |
|---|---|---|
| 1 | **Archivos temporales con nombre fijo en `/tmp`** | ✅ Los formateadores copiaban tu código a `/tmp/<nombre del archivo>` (y `DummyInput.txt`), sin borrarlo; otro usuario podía dejar un enlace con ese nombre. Ahora usan `~/.cache/penguin-cpp/tmp/` (permisos 0700) y borran la copia |
| 2 | **Cómo se lanzan los programas** | ✅ Ningún comando pasa por `/bin/sh`, así que `$(...)`, `;` y comillas invertidas en nombres de archivo son texto literal. ⚠️ Pero un nombre con `"` puede agregar argumentos, y los Makefiles sí pasan por el shell: ver fase 6 |

Para probar en Mint con el modo Debug:

```bash
lazbuild --bm=Debug Source/penguin-cpp.lpi
./penguin-cpp-debug
```

Al cerrarlo, la terminal muestra la memoria no liberada con archivo y línea.
Si lazbuild da un "Internal error" del compilador después de cambios, se
compila todo de nuevo con `-B`.

Los pendientes de seguridad de otras fases están en su lugar: la instancia
única (fase 3), los nombres de archivo en los comandos, `INTERNAL_DEL` y los
proyectos de terceros (fase 6), y el mantenimiento de GTK2 (abajo).

#### Biblioteca gráfica: GTK2 o Qt6 (pendiente)
La biblioteca gráfica es la que dibuja las ventanas, botones y menús. En
Lazarus el código y los formularios son los mismos para todas; se elige al
compilar (`--ws=gtk2`, `--ws=qt6`…). Cambiarla no es reescribir nada, pero sí
cambia las dependencias del `.deb`, algunos tamaños de los controles y las
rarezas de cada una, así que hay que volver a probar todo.

| | GTK2 (hoy) | GTK3 | Qt5 | Qt6 |
|---|---|---|---|---|
| Estado en Lazarus | El más probado | Verde en 3.0; mejor en 4.x, con detalles | Maduro | Maduro (comparte código con Qt5) |
| Mantenimiento de la biblioteca | Abandonada desde 2020 (sigue funcionando y viene en Mint 22) | Mantenida | Sin soporte libre desde 2023; las distribuciones la parchean | Activa |
| Wayland | Solo a través de XWayland | Nativo | Nativo | Nativo |
| Pantallas HiDPI | Pobre | Bien | Bien | La mejor |
| Temas con la paleta del icono | Formato viejo (`gtkrc`); depende del tema del escritorio | Lazarus lo expone poco | Paleta y hojas de estilo para toda la app | Igual que Qt5 |
| Dependencia extra | Normalmente ya instalada | Ninguna | `libqt5pas` | `libqt6pas` + Qt6 |

Plan:
1. **Primera ejecución con GTK2.** Si algo falla, sabemos que es nuestro
   código y no la biblioteca gráfica.
2. **Justo después, compilar con Qt6** en Mint y comparar las dos versiones:
   - `apt policy libqt6pas-dev` dice si el paquete está disponible.
   - `lazbuild --ws=qt6 Source/penguin-cpp.lpi` compila la versión Qt6.
3. **Si Qt6 funciona bien, queda como la oficial** antes de los ajustes
   visuales, los temas (fase 4b) y el `.deb`. Razones:
   - Se mantiene, y el `.deb` tiene que servir por años.
   - Funciona nativo en Wayland y en pantallas HiDPI.
   - Permite aplicar la paleta de Penguin cpp a toda la app, igual en
     cualquier escritorio.
4. **Si no, se queda GTK2** (o Qt5 como alternativa), y se vuelve a evaluar
   más adelante.

GTK3 no se recomienda todavía en Lazarus.

### Fase 4b · Identidad visual y temas 🔄
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

Falta: **tema claro y tema oscuro** con los tonos del icono.

| Color | Hex | Uso |
|---|---|---|
| Azul claro | `#DAEEFC` | Fondos de paneles (claro) |
| Azul marino | `#18395E` | Barras y encabezados; base del oscuro |
| Tinta marina | `#092543` | Texto y contornos |
| Azul medio | `#5789C2` | Selección, acentos |
| Amarillo | `#FDB50B` | Acento: pestaña activa, marcadores |
| Blanco | `#FFFFFF` | Fondo del editor (claro) |

- Esquemas de color del editor **"Penguin claro"** y **"Penguin oscuro"**,
  junto a los 15 que ya trae (Classic, Monokai, Visual Studio Dark…).
- Colores propios en los paneles del IDE: bienvenida, árbol del proyecto,
  navegador de clases y mensajes.
- Variante clara de las tiras de iconos para el tema oscuro.
- Menús, botones y diálogos los dibuja la biblioteca gráfica. Con Qt6 la
  paleta se aplica a toda la app; con GTK2 siguen el tema del escritorio
  (o un tema GTK2 propio). Por eso los temas van después de decidir entre
  GTK2 y Qt6 (fase 4).
- El selector "Tema" de Opciones del entorno elige entre *Claro / Oscuro / Del
  sistema*.
- Se hace después de la primera ejecución en Mint: hay que ver el IDE
  funcionando para ajustar los colores.
- **Hecho cuando:** se cambia entre claro y oscuro desde Opciones del entorno
  y todo el IDE (editor, paneles, iconos) se ve con la paleta.

### Fase 5 · Editor 🔄
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
- Probar el resaltado, el autocompletado, los tooltips y buscar/reemplazar.
- **Plegado de código para C++**: el resaltador C++ de Lazarus no lo trae.
- **Impresión** y exportar a RTF/TeX (la exportación a HTML sigue).
- **Hecho cuando:** funciona todo lo anterior, como en el original.

### Fase 6 · Compilación con el gcc de Linux ⏳
- `Compiler.pas`:
  - Quitar `.exe` y `windres`; en Linux no hay archivos de recursos `.rc`.
  - Generar Makefiles con rutas POSIX.
  - Detectar `gcc`, `g++`, `clang` y `make` en el PATH.
- Conjuntos de compilador por defecto para Linux, en lugar de los de
  MinGW/TDM.
- Portar `ConsolePauser` (`Source/Tools/ConsolePauser`) a POSIX.
- Ejecutar los programas en una terminal configurable
  (`x-terminal-emulator`, `gnome-terminal`, `konsole`…).
- Usar el AStyle y el clang-format instalados en el sistema.
- Revisar las rutas con `\` escritas a mano que quedan (`main.pas`,
  `Compiler.pas`, `Project.pas`, `Utils.pas`).
- Seguridad (pendiente):
  - **Nombres de archivo en los comandos:** los comandos se arman como texto
    con los nombres entre comillas dobles y se parten en argumentos sin shell.
    Un archivo llamado `a" -o /home/u/.bashrc "b.cpp` (que puede venir en un
    proyecto descargado) agregaría argumentos y gcc escribiría sobre ese
    archivo. Pasar cada argumento por separado a `TProcess`, o rechazar
    nombres con `"`.
  - **Makefiles:** `make` ejecuta cada receta con `/bin/sh`, así que ahí un
    archivo llamado `$(…).cpp` **sí ejecutaría código**. El generador de
    Makefiles tiene que citar cada nombre para el shell (comillas simples,
    con `'` escrito como `'\''`).
  - **`INTERNAL_DEL`:** hoy el ejecutable borra los archivos que le pasen (lo
    usa `make clean`). Solo borra los que se le indican, sin comodines ni
    carpetas. Reemplazarlo por `rm -f` en los Makefiles y quitar ese modo.
  - **Proyectos de terceros (`.dev`):** un proyecto puede traer su propio
    Makefile y opciones de compilación, y compilarlo es ejecutar lo que
    diga. Pasa en cualquier IDE, pero conviene avisar al abrir un proyecto
    ajeno que use Makefile propio.
- **Hecho cuando:** se compila y ejecuta un proyecto de consola y uno de
  varios archivos, y los errores del compilador aparecen en la lista y se
  pueden clicar.

### Fase 7 · Depurador ⏳
- `Debugger.pas` ya lanza gdb con `TProcess`, pero usa `--annotate=2`, un
  modo obsoleto de gdb.
- Plan: reescribir `DebugReader.pas` sobre **GDB/MI**
  (`--interpreter=mi`), que es estable.
- La ventana CPU (desensamblado y registros) sale de gdb, así que se puede
  portar.
- El IDE habla con el depurador a través de una interfaz propia, separada de
  gdb, para poder agregar lldb en macOS (fase 9) sin rehacer esta fase.
- **Hecho cuando:** funcionan los breakpoints, el paso a paso, las variables
  vigiladas, la pila de llamadas y ver valores al pasar el ratón.

### Fase 8 · Paquete `.deb` y pulido ⏳
El producto final del proyecto es un `.deb` que se instala con
`sudo apt install ./penguin-cpp_<versión>_amd64.deb`.

- **Rutas de instalación** (requiere cambios en el código):
  - Hoy el IDE busca `Lang/`, `Templates/` y `Help/` junto al ejecutable
    (`devCFG.pas`). Instalado, el ejecutable va en `/usr/bin` y los datos en
    `/usr/share/penguin-cpp/`, así que hay que enseñarle a buscarlos ahí.
    Otra opción es instalar todo en `/usr/lib/penguin-cpp/` con un enlace
    en `/usr/bin`.
  - Lanzador `.desktop` en `/usr/share/applications`.
  - Iconos en `/usr/share/icons/hicolor` (ya generados en
    `Source/Images/AppIcon/hicolor`).
  - Asociación con archivos `.c`, `.cpp`, `.h` y proyectos `.dev`.
  - Fuentes Heebo y Source Code Pro en `/usr/share/fonts`.
- **Dependencias del paquete**: `gcc`, `g++`, `make`, `gdb` y GTK2
  (`libgtk2.0-0`). Recomendadas: `astyle` y `clang-format`.
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

### Fase 9 · macOS ⏳
Lazarus también compila para macOS con la interfaz nativa (Cocoa), así que se
usa el mismo código. Se reutilizan tal cual el parser, el editor, los
proyectos, las plantillas, los formularios, `devPlatform` (que ya abre
archivos con `open` en macOS), el monitor de archivos y los Makefiles.

| Parte | Linux | macOS | Dificultad |
|---|---|---|---|
| Interfaz | GTK2 | Cocoa. Está menos pulido en Lazarus; el menú va en la barra superior, con *Preferencias* y *Salir* en el menú de la app | Media |
| Atajos | Ctrl | ⌘ Cmd: traducir los atajos | Baja |
| Compilador | gcc/g++ | El clang de Apple (`xcode-select --install`), con el mismo formato de errores | Baja |
| **Depurador** | gdb | **gdb no funciona en Macs con Apple Silicon.** Hace falta otro motor sobre lldb (por ejemplo lldb-dap) | **Alta** |
| Terminal | x-terminal-emulator | Terminal.app | Baja |
| Configuración | `~/.config/penguin-cpp` | `~/Library/Application Support/penguin-cpp` | Baja |
| Lista de procesos | `/proc` | No existe; se usa `ps` | Baja |
| Distribución | `.deb` | `.app` dentro de un `.dmg`, para Apple Silicon e Intel | Media |

- **Compilador de Pascal:** FPC 3.2.2 no puede enlazar apps Cocoa con el
  linker actual de Apple (error "malformed method list"). Hace falta un FPC
  más nuevo (la rama de correcciones de la 3.2) y probablemente Lazarus 4.
- **Firma de Apple:**
  - Para que macOS no muestre el aviso de "desarrollador no identificado",
    hay que firmar y notarizar la app con una cuenta Apple Developer (99 USD
    al año).
  - Sin ella funciona igual, pero cada usuario tiene que autorizarla a mano
    la primera vez.
  - La App Store queda descartada: sus condiciones no son compatibles con la
    GPL.
- **Esfuerzo:** unas 4 a 6 semanas, casi todo en el depurador y en los
  detalles de Cocoa.
- **Hecho cuando:** en un Mac con Apple Silicon y en uno con Intel:
  - El `.dmg` instala la app.
  - Se compila, ejecuta y depura un "Hola mundo".

---

## Otros pendientes

- **Identidad propia** (la GPL cubre el código, no las marcas; "Embarcadero" y
  "Delphi" son marcas registradas):
  - El enlace "buscar actualizaciones" de *Acerca de* todavía apunta a
    Embarcadero.
  - Los textos de *Acerca de* todavía dicen "About Embarcadero Dev-C++" y
    "fork by". Vienen de los archivos de idioma (`Lang/*.lng`).
  - `SECURITY.md` todavía es el del proyecto original (versiones 6.x y un
    contacto del equipo de Embarcadero).
- **Limpieza**, preguntando antes de borrar:
  - `Source/VCL/SynEdit` y `Source/VCL/SVGIconImageList`, que ya no se usan.
  - Los proyectos de Delphi (`devcpp.dpr/.dproj`, `DevCpp.dpk/.dproj`,
    `ClassBrowsing.dpk/.dproj`).
  - `FormatterOptionsFrm`, que no lo usa nada.
  - Los iconos e imágenes del original que ya no se usan (`devcpp.ico`,
    `Source/devcpp_Icon.ico`, `Source/Images/devcpplogo.png`…).
- **Avisos de compilación**: revisar los ~150 que da hoy.
- **Fuentes de Windows** en los formularios (MS Sans Serif, Tahoma, Courier
  New, Segoe UI): cambiarlas por las del sistema.
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
