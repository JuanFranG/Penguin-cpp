# Penguin cpp 0.5.7

## Cambios y adiciones

- **Proyectos en macOS:** el diálogo Nuevo proyecto vuelve a mostrar sus plantillas y permite seleccionarlas. Se corrigen las categorías vacías y la selección inicial.
- **Interfaz legible:** más espacio para etiquetas de opciones, búsqueda incremental sin superposición ni fondo incorrecto, botones completos al quitar archivos y crear plantillas, y etiquetas separadas de los selectores de ClangFormat.
- **Compilación coherente:** abrir un archivo perteneciente al proyecto mediante Archivo → Abrir conserva su pertenencia al proyecto. Compilar usa la construcción del proyecto completo, incluida la implementación de las funciones declaradas en headers.
- **Errores de formato:** si falta clang-format, no se intenta ejecutar una vista previa. Si el proceso falla, el diagnóstico se muestra separado del código de ejemplo y no sobrescribe su archivo temporal.
- **Depurador:** los controles se redistribuyen según el ancho disponible. La ventana CPU oculta las opciones Intel/AT&T en ARM64 y deja espacio para el nombre de la función.
- **Manual ampliado:** versiones web en español e inglés con 47 vistas reales de la aplicación en inglés. Incluye proyectos, archivos .cpp/.h, guards, rutas de inclusión y bibliotecas, banderas de compilación/enlazado, puntos de interrupción, variables vigiladas, registros y pila de llamadas.
- **Ejemplo descargable:** proyecto C++ con main.cpp, calculator.cpp y calculator.h; calcula y muestra Result: 5. La CI compila y ejecuta ese mismo ejemplo.

## Validación

La compilación nativa Cocoa y las regresiones de interfaz pasan localmente. La comprobación de recursos realiza 9.390 verificaciones sin problemas. Se prueban la selección de plantillas, la búsqueda inicializada antes de mostrarla, los errores del formateador y la pertenencia de archivos al proyecto. El ejemplo compila con -std=c++17 -Wall -Wextra -Werror y muestra Result: 5. Los validadores del manual comprueban las dos versiones, imágenes, enlaces y tema automático; la vista móvil se revisó a 390 puntos. GitHub Actions supera las comprobaciones de Linux/Qt5, Cocoa, consola Windows, empaquetado y actualización APT desde una versión antigua.

## Límites y pendientes

Los instaladores de 0.5.7 incluyen estas correcciones. Las copias anteriores de 0.5.6 deben actualizarse; no es necesario borrar las preferencias. Algunas capturas proceden de 0.5.6 y otras del código corregido; su procedencia está documentada. El selector auxiliar de biblioteca de iconos conserva un problema de recursos heredados. No se afirma cobertura de todas las traducciones, resoluciones o diálogos nativos del sistema.

La compatibilidad Windows continúa experimental: esta versión no amplía el soporte de WinBGIm, SDK externos ni depuración Windows. macOS requiere 26+ y Apple Silicon. Firma Developer ID, notarización y una instalación en Mac limpio siguen pendientes.
