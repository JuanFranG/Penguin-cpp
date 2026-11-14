# Penguin cpp 0.5.0

## Cambios y adiciones

- **Entorno incluido sin rutas:** el diálogo de compatibilidad muestra el estado real del entorno. En el paquete completo se detectan el compilador, GNU Make y el motor Windows, con estado «Entorno listo» después de comprobarlos. Las rutas personalizadas y GPTK quedan en Opciones avanzadas.
- **Configuración:** botón para restaurar el entorno incluido; validación conserva correctamente la configuración del proyecto; información traducida al inglés y a las variantes españolas.
- **Paquete completo por defecto:** el generador de `.pkg` exige LLVM-MinGW, GNU Make y el motor curado fijados. Si falta alguno, falla antes de crear el instalador. El paquete que solo contiene el IDE requiere `--native-only` explícito.
- **Inicio desde Terminal:** el arranque directo del ejecutable hace la misma preparación del entorno que el arranque gráfico. Si una copia marcada como completa pierde un componente o su manifiesto, Penguin exige reparar la instalación. Compilar Windows se detiene si la preparación falla o se cancela.
- **Protección al actualizar:** se rechaza reemplazar una instalación completa por un DMG que solo contiene el IDE nativo. Así se evita borrar sus herramientas durante la actualización.
- **CI macOS:** selección explícita del backend y de la configuración de Free Pascal 3.2.4; el flujo anterior acababa usando el backend 3.2.2 de Homebrew.
- Se mantienen las mejoras de la 0.4.0: barras adaptables, corrección de repintado Cocoa, modos Automático/Nativo/Windows, objetos Windows separados y encabezado común `bits/stdc++.h`.

## Descargas y alcance

- **Linux amd64:** `sudo apt install ./penguin-cpp_0.5.0_amd64.deb`, o actualizar desde el [repositorio APT](https://juanfrang.github.io/Penguin-cpp/). APT resuelve las dependencias MinGW/Wine del paquete.
- **macOS nativo:** DMG para **macOS 26.0 o posterior y Apple Silicon**. El desarrollo nativo necesita las herramientas oficiales de Apple. Firma ad hoc, sin notarización Developer ID.
- **El `.pkg` COMPLETO sí incluye las herramientas de compatibilidad:** LLVM-MinGW, GNU Make y Wine ARM64/FEX dentro de Penguin. Prepara el entorno automáticamente al abrir la aplicación, también desde Terminal. Se verificó extrayendo el instalador, compilando y ejecutando su ejemplo Windows. No requiere instalar esas herramientas por separado.
- **El [PKG completo](https://github.com/JuanFranG/Penguin-cpp/releases/download/v0.5.0/Penguin-cpp-0.5.0-COMPLETE-UNSIGNED.pkg) y el [DMG completo](https://github.com/JuanFranG/Penguin-cpp/releases/download/v0.5.0/Penguin-cpp-0.5.0-COMPLETE-UNSIGNED.dmg) están publicados**, junto a sus [fuentes correspondientes](https://github.com/JuanFranG/Penguin-cpp/releases/download/v0.5.0/Penguin-cpp-0.5.0-COMPAT-SOURCES.tar.gz), recetas, parches y avisos. Perfil revisado `penguin-windows-foss-1`; experimental, sin firma Developer ID ni notarización.
- **El archivo `Penguin-cpp-0.5.0-arm64.dmg` contiene solo el IDE nativo**. El DMG `COMPLETE-UNSIGNED` incluye el mismo entorno que el PKG completo. El instalador curl instala la edición nativa cuando no hay una instalación completa previa.

| Archivo 0.5.0 | ¿Incluye el entorno Windows completo? | Dónde está |
|---|---|---|
| `Penguin-cpp-0.5.0-arm64.dmg` | No; IDE nativo | Asset público de GitHub |
| `Penguin-cpp-0.5.0-COMPLETE-UNSIGNED.pkg` | Sí; compilador, Make y Wine ARM64/FEX | Asset público de GitHub (experimental) |
| `Penguin-cpp-0.5.0-COMPLETE-UNSIGNED.dmg` | Sí; mismo entorno del PKG completo | Asset público de GitHub (experimental) |

- El motor de la integración completa es ARM64/FEX y no depende de Rosetta. Esto no garantiza ejecución en futuras versiones de macOS.
- El nuevo paquete completo selecciona el DMG `COMPLETE-UNSIGNED` al actualizar; la edición nativa conserva su canal nativo. Siete pruebas simuladas cubren selección, recuperación y rechazo de descargas incompletas. Falta una actualización real a una versión futura. Una copia anterior con la misma versión debe instalar este PKG una vez.

## Instalar, ejecutar y desinstalar

El paquete completo incluye las herramientas dentro de la app. Puede instalarse gráficamente o desde Terminal:

```sh
sudo installer -pkg /ruta/al/paquete-completo.pkg -target /
open -a "Penguin cpp"
# También se comprueba el entorno al iniciar directamente:
"/Applications/Penguin cpp.app/Contents/MacOS/penguin-cpp"
```

Cierra Penguin antes de instalar o actualizar. Installer no inicia Wine como root: la preparación ocurre con el usuario que abre la aplicación.

Para desinstalar, cierra Penguin y mueve **Penguin cpp.app** a la Papelera; las herramientas incluidas se eliminan con ella. La configuración y el entorno privado quedan en `~/Library/Application Support/penguin-cpp`. Borrar esa carpeta opcionalmente elimina también los programas y datos almacenados dentro del entorno Windows.

## Validación y pendientes

- Probado localmente el estado «Entorno listo» sin introducir rutas y el arranque directo desde Terminal, forzando una nueva comprobación de compilación y ejecución.
- Pruebas de configuración, detección de dependencias y recibos de paquetes completos; siete pruebas del instalador/recuperación, incluida la protección frente a una descarga nativa incompleta.
- Revisión de fuentes y dependencias del perfil fijado: 93 entradas, 88 archivos de fuentes y 474 avisos; verificación de hashes y aplicación de parches de seis componentes. Se verificó la firma ad hoc de la app extraída y la compilación/ejecución Win32/conio/math/stdlib/STL/GDI con un prefix nuevo. No se recompilaron aquí todas las dependencias.
- Permanecen excluidos Microsoft opcional, FMOD, conversor Apple, Mono/Gecko y `lib/linuxhost` (sin licencia identificada; sin su soporte de módulos anticheat). Véase la [revisión del perfil](https://github.com/JuanFranG/Penguin-cpp/blob/main/Compat/REDISTRIBUTION.md). Los hashes se publican en `SHA256SUMS-COMPLETE.txt`.
- Pendientes: instalación y actualización reales del `.pkg` en un Mac limpio, usuario estándar, fallos simulados, Gatekeeper con cuarentena y pruebas físicas en macOS 26. La consulta de Installer y la extracción del paquete no sustituyen esas pruebas.
- Wine puede registrar una aserción interna durante la primera creación del prefix aunque el ejemplo termine correctamente. No se garantiza compatibilidad total con Windows o videojuegos.
- `graphics.h`/WinBGIm y bibliotecas de terceros arbitrarias no están integradas automáticamente. El prototipo SDL/Metal sigue siendo limitado y separado. No se añadieron nuevas funciones gráficas en esta versión.
- Depuración/perfilado Windows y revisión visual exhaustiva de formularios, traducciones, fuentes, resoluciones, impresión/exportaciones y todas las plantillas siguen pendientes.

[Todos los cambios desde 0.4.0](https://github.com/JuanFranG/Penguin-cpp/compare/v0.4.0...v0.5.0).

## Documentación y colaboración

El [README](https://github.com/JuanFranG/Penguin-cpp/blob/main/README.md) y
el [ROADMAP](https://github.com/JuanFranG/Penguin-cpp/blob/main/ROADMAP.md)
reflejan las versiones recientes, las diferencias entre Linux/macOS, la
instalación y desinstalación, y los pendientes del entorno completo.
Se reconoce la asistencia de **Claude Opus 5.5** (Anthropic) y
**Chat GPT 6.1 Sol** (OpenAI), manteniendo la autoría y las decisiones de
Juan Francisco Gonzalez Pacheco.
