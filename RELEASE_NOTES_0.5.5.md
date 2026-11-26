# Penguin cpp 0.5.5

## Cambios y adiciones

- **Guardado seguro:** fuentes, proyectos y preferencias se reemplazan de forma
  atómica. Cancelar o fallar un guardado conserva los cambios pendientes y evita
  cerrar el proyecto como si se hubiera guardado correctamente.
- **Compilar y ejecutar:** F11 solo ejecuta después de una compilación correcta;
  F9 no hereda una ejecución pendiente. Se comprueba el código de salida del
  compilador y su último diagnóstico. Detener y reiniciar controlan sus procesos.
- **Objetos separados:** fuentes C/C++ con el mismo nombre conservan objetos
  distintos, también junto a las fuentes. Limpiar reconoce ejecutables Mach-O.
- **Opciones coherentes:** Cancelar descarta las ediciones del diálogo. Las
  preferencias se guardan juntas y los errores de persistencia se comunican.
- **Entorno Windows recuperable:** una preparación privada incompleta se conserva
  como respaldo antes de reintentar. El estado «listo» exige registros del runtime
  guardados y un self-test correcto. Los errores del asistente se pueden copiar.
- **Caracteres y teclado:** perfiles de consola UTF-8, DOS/OEM 437, ANSI 1252 y
  control por el programa. Penguin coordina el CRT y las páginas de consola al
  compilar; restaura el teclado y el estilo de la terminal al terminar. Para
  cuadros hechos con bytes como `char(218)`, elegir OEM 437 y recompilar.
- **Funciones heredadas:** se retira el importador Code::Blocks incompleto, el
  formulario de formato sin uso y las acciones internas obsoletas. Los recursos
  `.rc`/`.res` no admitidos producen un error explícito en vez de omitirse. Los
  metadatos `.dev`, los iconos y los recursos del formato antiguo se conservan.
- **GitHub y novedades:** Actualizaciones enlaza al repositorio y a las notas de
  versión, incluso si falla la consulta. La versión de Acerca de es un enlace a
  su publicación. Las entregas futuras requieren notas con cambios y pendientes.
- **Paquetes completos:** incluyen el nuevo código de preparación de consola,
  además del compilador, Make y runtime ya incluidos en la 0.5.0 completa.

## Qué mejora para windows.h y otras bibliotecas

`windows.h` y `conio.h` siguen usando compilación cruzada MinGW y el runtime
Windows; esta versión mejora la fiabilidad de compilar/ejecutar, la recuperación
tras errores y la coherencia de texto, teclado y colores. No añade una traducción
universal de Win32 ni garantiza todas sus funciones. `math.h`, `stdlib.h` y la
biblioteca estándar continúan disponibles según el compilador seleccionado.
`bits/stdc++.h` conserva su encabezado de compatibilidad. `graphics.h`/WinBGIm y
bibliotecas arbitrarias todavía requieren una integración específica.

## Descargas y actualización

- **Linux amd64:** paquete `.deb` y repositorio APT. El botón Actualizar ejecuta
  `apt-get update` y actualiza `penguin-cpp`; APT resuelve sus dependencias.
- **macOS 26+ / Apple Silicon:** DMG nativo y PKG/DMG `COMPLETE-UNSIGNED` con
  LLVM-MinGW, GNU Make y Wine ARM64/FEX. No necesita Rosetta para ese motor.
- **Desde la 0.5.0 completa:** el botón conserva el canal completo y descarga el
  DMG completo. No se requiere desinstalar ni borrar preferencias o prefix.
  Quien tenga la edición nativa y quiera añadir el entorno debe instalar el PKG
  completo encima. Cambiar el perfil de consola requiere volver a compilar.
- El motor y sus fuentes fijadas conservan el perfil `penguin-windows-foss-1`.
  Los componentes Apple GPTK/conversor, Microsoft opcional y FMOD siguen excluidos.

## Validación

La evidencia de compilaciones, pruebas de errores, consola, formularios y
paquetes está en [QA_STAGE_6.md](https://github.com/JuanFranG/Penguin-cpp/blob/v0.5.5/QA_STAGE_6.md).
Los cambios anteriores se detallan en los informes de etapas 1–2, 3–4 y 5 del
repositorio. Las limitaciones se mantienen explícitas; una comprobación de
estructura o self-test no acredita todas las bibliotecas ni todas las pantallas.

## Límites y pendientes

- Compatibilidad Windows experimental; no hay garantía para todo Win32,
  videojuegos, llamadas contradictorias de página de códigos o texto mezclado.
- Recursos Windows, depuración/perfilado de ejecutables Windows y WinBGIm no
  están integrados. Un Makefile nativo personalizado puede gestionar sus recursos.
- Los paquetes macOS usan firma ad hoc y el PKG no tiene firma Developer ID ni
  notarización. No se presenta como validado en un Mac limpio ni en macOS futuro.
- La inspección no cubre todas las combinaciones de idiomas, fuentes, resoluciones,
  impresión/PDF y exportaciones. La lectura de preferencias malformadas conserva
  sus límites anteriores.

[Todos los cambios desde 0.5.0](https://github.com/JuanFranG/Penguin-cpp/compare/v0.5.0...v0.5.5).
