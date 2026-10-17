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
| Interfaz | LCL con **GTK2**, el widgetset por defecto de Lazarus en Linux y el más maduro. Qt5/Qt6 quedan como opción futura |
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
| 5 · Editor (SynEdit de Lazarus) | `fase4/lazarus` | 🔄 Adelantada dentro de la fase 4 |
| 6 · Compilación con el gcc de Linux | — | ⏳ Pendiente |
| 7 · Depurador (GDB/MI) | — | ⏳ Pendiente |
| 8 · Paquete `.deb` y pulido | — | ⏳ Pendiente |

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
  un socket local o similar.

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
- **Hecho cuando:** el IDE abre, se ven los menús y se puede abrir, editar y
  guardar un archivo.

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
  - Iconos en `/usr/share/icons/hicolor`.
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

---

## Otros pendientes

- **Identidad propia** (la GPL cubre el código, no las marcas; "Embarcadero" y
  "Delphi" son marcas registradas):
  - El enlace "buscar actualizaciones" de *Acerca de* todavía apunta a
    Embarcadero.
  - Faltan logo e iconos propios (`devcpp.ico`, pantalla de bienvenida).
  - `SECURITY.md` todavía es el del proyecto original (versiones 6.x y un
    contacto del equipo de Embarcadero).
- **Limpieza**, preguntando antes de borrar:
  - `Source/VCL/SynEdit` y `Source/VCL/SVGIconImageList`, que ya no se usan.
  - Los proyectos de Delphi (`devcpp.dpr/.dproj`, `DevCpp.dpk/.dproj`,
    `ClassBrowsing.dpk/.dproj`).
  - `FormatterOptionsFrm`, que no lo usa nada.
- **Avisos de compilación**: revisar los ~150 que da hoy.
- **Fuentes de Windows** en los formularios (MS Sans Serif, Tahoma, Courier
  New, Segoe UI): cambiarlas por las del sistema.
- Más adelante: probar con Lazarus 4.x.

---

## Licencia y créditos

Penguin cpp se distribuye bajo la **GNU GPL versión 2 o posterior**
(`LICENSE`, `COPYING.txt`), la misma licencia del código del que parte. Si se
distribuyen binarios, también hay que publicar el código fuente.

Créditos del código de origen:
- Bloodshed Dev-C++: Colin Laplace y colaboradores.
- Orwell Dev-C++: Johan Mes y colaboradores.
- Embarcadero Dev-C++: Embarcadero Technologies y colaboradores.

Componentes de terceros:
- SynEdit de Lazarus (MPL/GPL).
- La LCL de Lazarus (LGPL modificada, compatible con la GPL).
- AStyle (MIT).
- Las fuentes Heebo y Source Code Pro (SIL OFL).
