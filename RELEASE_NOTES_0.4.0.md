# Penguin cpp 0.4.0

## Cambios y adiciones

- **Interfaz macOS:** corregido el repintado de vistas Cocoa que ocultaba barras y controles. Los selectores del compilador, clases y funciones aprovechan el ancho disponible y se reorganizan al reducir la ventana.
- **Compatibilidad Windows experimental:** selección Automático / Nativo / Windows, detección de encabezados Windows y dependencias locales, proyectos y archivos sueltos, compilación con LLVM-MinGW/MinGW y ejecución mediante Wine. Objetos `.win.o` y ejecutables `.exe` separados de los nativos.
- **Preparación del entorno:** carpeta privada por usuario, prueba de compilación y ejecución, progreso, cancelación, reintento y registro de diagnóstico. El flujo se activa cuando las herramientas necesarias están disponibles.
- **Bibliotecas y plantillas:** encabezado común `bits/stdc++.h` para compiladores que no lo suministren y plantillas de hilos adaptadas a entornos Unix. El ejemplo de comprobación cubre Win32, conio, math, stdlib, STL y GDI en memoria.
- **Empaquetado:** macOS **26.0 o posterior, Apple Silicon**. Nuevas herramientas para construir `.pkg` de validación, GNU Make fijado y un motor ARM64/FEX curado. Linux amd64 declara las dependencias de MinGW/Wine mediante APT.
- Se mantienen las funciones de la 0.3.0: buscar/instalar actualizaciones, adjuntar a procesos nativos, correcciones de colisiones de objetos y sustitución de la aplicación con recuperación ante fallos.

## Descargas e instalación

- **Linux amd64:** instalar el `.deb` con `sudo apt install ./penguin-cpp_0.4.0_amd64.deb`, o actualizar desde el [repositorio APT](https://juanfrang.github.io/Penguin-cpp/).
- **macOS:** descargar el DMG ARM64 y copiar Penguin cpp a Aplicaciones. Requiere macOS 26+. La aplicación lleva firma ad hoc; no está notarizada con Developer ID. El desarrollo nativo necesita las herramientas oficiales de Apple.
- **Alcance del paquete macOS publicado:** IDE nativo y código de integración. **No incluye el motor Wine/FEX ni el entorno completo de Windows.** El `.pkg` completo de integración permanece local hasta completar las obligaciones sobre fuentes y la revisión de sus dependencias. Para usar el modo experimental con esta descarga hay que proporcionar un compilador Windows y un motor compatibles.
- Los archivos `*_symbols` contienen símbolos de diagnóstico. No son instaladores.

## Comprobaciones

- Compilaciones Cocoa normal y Debug verificadas localmente en Apple Silicon.
- 9.824 comprobaciones estructurales de 37 formularios sin problemas; barras revisadas a 1440 y 1000 puntos.
- Pruebas de configuración, detección de fuentes, argumentos, ejecutables PE y prefijos; cinco pruebas del instalador por terminal.
- En la integración local completa, preparación inicial y Compilar y ejecutar comprobados con un ejemplo Windows. El compilador y el motor extraídos del `.pkg` ejecutaron el self-test con salida esperada y código 0.

## Pendientes y límites conocidos

- Completar fuentes correspondientes, recetas y revisión de dependencias del motor curado antes de distribuir el paquete Windows completo. Se excluyen de ese prototipo los componentes opcionales Microsoft, FMOD y el conversor Apple.
- Primera instalación/actualización real del `.pkg`, recuperación ante fallo, Gatekeeper con cuarentena, usuario estándar y Mac limpio; pruebas físicas en macOS 26. La validación local no acredita compatibilidad futura con macOS 28.
- El primer inicio de un prefix puede registrar una aserción interna de Wine aunque el ejemplo termine correctamente. No se garantiza compatibilidad total con las APIs de Windows ni con videojuegos.
- `graphics.h`/WinBGIm y bibliotecas de terceros arbitrarias no vienen con MinGW/Wine. El prototipo nativo SDL/Metal es limitado y no está enlazado automáticamente al modo Windows.
- Depuración, adjuntar y perfilado Windows pendientes; esas acciones permanecen reservadas a procesos nativos. El análisis Automático es heurístico: para inclusiones ambiguas debe seleccionarse Windows manualmente.
- Falta una revisión visual exhaustiva de todos los formularios, traducciones, fuentes y resoluciones, así como impresión/PDF, exportaciones, perfilador y todas las plantillas. Las comprobaciones estructurales no sustituyen esas pruebas.

Los cambios desde la versión anterior pueden consultarse en [la comparación 0.3.0…0.4.0](https://github.com/JuanFranG/Penguin-cpp/compare/v0.3.0...v0.4.0).
