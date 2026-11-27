# Penguin cpp 0.5.5

## Cambios y adiciones

- **Guardado seguro:** fuentes, proyectos y preferencias se reemplazan de forma atómica. Cancelar o fallar un guardado conserva los cambios pendientes y evita cerrar el proyecto como si se hubiera guardado correctamente.
- **Compilar y ejecutar:** F11 solo ejecuta después de una compilación correcta; F9 no hereda una ejecución pendiente. Se comprueba el código de salida del compilador y su último diagnóstico. Detener y reiniciar controlan sus procesos.
- **Objetos separados:** fuentes C/C++ con el mismo nombre conservan objetos distintos, también junto a las fuentes. Limpiar reconoce ejecutables Mach-O.
- **Opciones coherentes:** Cancelar descarta las ediciones del diálogo. Las preferencias se guardan juntas y los errores de persistencia se comunican.
- **Entorno Windows recuperable:** una preparación privada incompleta se conserva como respaldo antes de reintentar. El estado «listo» exige registros del runtime guardados y un self-test correcto. Los errores del asistente se pueden copiar.
- **Caracteres y teclado:** perfiles de consola UTF-8, DOS/OEM 437, ANSI 1252 y control por el programa. Penguin coordina el CRT y las páginas de consola al compilar; restaura el teclado y el estilo de la terminal al terminar. Para cuadros hechos con bytes como `char(218)`, elegir OEM 437 y recompilar.
- **Funciones heredadas:** se retira el importador Code::Blocks incompleto, el formulario de formato sin uso y las acciones internas obsoletas. Los recursos `.rc`/`.res` no admitidos producen un error explícito en vez de omitirse. Los metadatos `.dev`, los iconos y los recursos del formato antiguo se conservan.
- **GitHub y novedades:** Actualizaciones enlaza al repositorio y a las notas de versión, incluso si falla la consulta. La versión de Acerca de es un enlace a su publicación. Las entregas futuras requieren notas con cambios y pendientes.
- **Bienvenida Linux:** los botones Nuevo documento, Abrir documento y Opciones mantienen su orden al redimensionar; el panel deja de desplazarlos hacia arriba.
- **Acerca de simplificado:** creador destacado, enlaces a documentación/licencia y créditos separados, sin el texto completo de la GPL dentro del diálogo.
- **GitHub Actions:** caché y artefactos actualizados a acciones con Node.js 24, retirando el aviso de retirada de Node.js 20.
- **Cabecera adaptable:** el fondo azul de Acerca de ocupa todo el ancho y el logotipo permanece centrado y proporcional.
- **Linux con UCRT:** el `.deb` amd64 incluye LLVM-MinGW 20261104 con versión y SHA-256 fijados. El modo automático prefiere ese compilador a MinGW/MSVCRT del sistema. Se verifica el texto UTF-8 de `printf` y `std::cout` con el runtime privado.
- **Paquetes completos:** incluyen el nuevo código de preparación de consola, además del compilador, Make y runtime ya incluidos en la 0.5.0 completa.

## Qué mejora para windows.h y otras bibliotecas

`windows.h` y `conio.h` siguen usando compilación cruzada MinGW y el runtime Windows; esta versión mejora la fiabilidad de compilar/ejecutar, la recuperación tras errores y la coherencia de texto, teclado y colores. No añade una traducción universal de Win32 ni garantiza todas sus funciones. `math.h`, `stdlib.h` y la biblioteca estándar continúan disponibles según el compilador seleccionado. `bits/stdc++.h` conserva su encabezado de compatibilidad. `graphics.h`/WinBGIm y bibliotecas arbitrarias todavía requieren una integración específica.

## Descargas y actualización

### Linux: Ubuntu 24.04 y base de Mint 22, amd64

APT instala Penguin y sus dependencias. LLVM-MinGW/UCRT viene dentro del paquete; el motor WineHQ 11 privado y Make se instalan por APT. Este motor no reemplaza el Wine del sistema.

Para actualizar desde Terminal:

```bash
sudo apt update
sudo apt install --only-upgrade penguin-cpp
```

El botón **Actualizar** realiza ambos pasos. `apt update` por sí solo únicamente refresca los índices.

Para una instalación manual sin repositorio, descarga e instala juntos los dos paquetes `.deb`. WineHQ 11 se acompaña de sus fuentes exactas y recetas Debian.

### macOS 26 o posterior: Apple Silicon

- **PKG y DMG completos:** incluyen LLVM-MinGW, GNU Make y Wine ARM64/FEX. Este motor no necesita Rosetta.
- **DMG nativo:** incluye el IDE, sin el entorno Windows completo.

El botón **Actualizar** conserva tu edición: una instalación completa descarga el DMG completo. Desde la 0.5.5, pide autorización de administrador cuando debe reemplazar una app instalada por PKG.

Si tienes un PKG antiguo con el actualizador anterior, instala el nuevo PKG encima una vez. También puedes instalarlo encima de la edición nativa para añadir el entorno Windows. **No hace falta desinstalar ni borrar preferencias o la carpeta privada de Windows.**

### Cambiar el perfil de consola

Después de elegir UTF-8, DOS/OEM 437, ANSI 1252 o control por el programa, vuelve a compilar tu programa. Puedes pulsar **Compilar y ejecutar (F11)**.

Penguin incorpora el perfil al ejecutable durante la compilación. El cambio se aplica al nuevo `.exe`; uno que ya estaba compilado conserva su configuración anterior. **No tienes que recompilar ni reinstalar Penguin.**

### Dependencias y fuentes

El motor macOS conserva el perfil revisado `penguin-windows-foss-1`. Siguen excluidos los componentes Apple GPTK/conversor, Microsoft opcional y FMOD.

Linux utiliza WineHQ 11 fijado en `packaging/linux-runtime-lock.json`. Sus fuentes exactas están en `WineHQ-11.0.0.0-noble-SOURCES.tar.gz`.

## Validación

La evidencia de compilaciones, pruebas de errores, consola, formularios y paquetes está en [QA_STAGE_6.md](https://github.com/JuanFranG/Penguin-cpp/blob/v0.5.5/QA_STAGE_6.md). Los cambios anteriores se detallan en los informes de etapas 1–2, 3–4 y 5 del repositorio. Las limitaciones se mantienen explícitas; una comprobación de estructura o self-test no acredita todas las bibliotecas ni todas las pantallas.

## Límites y pendientes

- Linux/MinGW del sistema puede usar MSVCRT, que no ofrece locale UTF-8 completo. La consola configura UTF-8, pero las conversiones multibyte del CRT requieren UCRT para ese soporte. Los compiladores incluidos de macOS y Linux usan UCRT; una ruta personalizada a un MinGW antiguo conserva ese límite.
- La preparación inicial macOS todavía registra una aserción del motor; el self-test posterior pasa. Queda pendiente investigar ese diagnóstico.
- Compatibilidad Windows experimental; no hay garantía para todo Win32, videojuegos, llamadas contradictorias de página de códigos o texto mezclado.
- Recursos Windows, depuración/perfilado de ejecutables Windows y WinBGIm no están integrados. Un Makefile nativo personalizado puede gestionar sus recursos.
- Los paquetes macOS usan firma ad hoc y el PKG no tiene firma Developer ID ni notarización. No se presenta como validado en un Mac limpio ni en macOS futuro.
- La inspección no cubre todas las combinaciones de idiomas, fuentes, resoluciones, impresión/PDF y exportaciones. La lectura de preferencias malformadas conserva sus límites anteriores.

[Todos los cambios desde 0.5.0](https://github.com/JuanFranG/Penguin-cpp/compare/v0.5.0...v0.5.5).
