# Fiabilidad: etapas 1 y 2

Validación de desarrollo del 26 de noviembre de 2026, posterior a la auditoría
sobre `49f5e92`. Los paquetes 0.5.0 publicados no se modifican con este trabajo.

## Etapa 1: archivos y proyectos

Las fuentes se escriben en un archivo temporal del mismo directorio. Solo se
reemplaza el destino tras escribir todos los bytes, copiar permisos/metadatos y
sincronizar el archivo. Un error limpia el temporal y conserva el destino
anterior. Se mantienen los enlaces simbólicos; un archivo con varios enlaces
duros requiere Guardar como para evitar romper silenciosamente sus alias.

Guardar y Guardar como devuelven fallo ante cancelación o error. La identidad y
la codificación del editor se actualizan tras escribir correctamente. Un archivo
existente vaciado también exige confirmar su cierre si tiene cambios. Guardar
todo y cerrar proyecto respetan el resultado; el destructor del INI no guarda
cambios descartados. Abrir otro proyecto se detiene si el anterior permanece
abierto. El estado modificado también registra cambios en proyectos de solo
lectura. Renombrar comprueba la operación en disco antes de actualizar las
referencias y no borra previamente el destino.

## Etapa 2: compilación y procesos

La compilación combina el código de salida real, los diagnósticos y la
cancelación para determinar el éxito. Un proceso ausente o una salida distinta
de cero produce un error visible. El último diagnóstico se entrega aunque no
termine en salto de línea. La acción posterior (ejecutar/depurar/perfilar) se
limpia por intento, antes de invocarla. Un F11 fallido no ejecuta un binario
anterior ni deja una ejecución pendiente para el siguiente F9.

El ejecutor espera y retira el hilo anterior al reiniciarse. Una terminación
antigua no cambia el estado de la nueva ejecución. Los procesos supervisados
usan un grupo propio y se detienen con sus descendientes; el recorrido de
Terminal en macOS contempla su sesión independiente. Los fallos de lanzamiento
se muestran en el registro del IDE.

Sin carpeta de objetos, `util.c` y `util.cpp` generan `util.c.o` y `util.cpp.o`.
Las carpetas de salida comunes mantienen sus nombres con hash. Los comandos
personalizados sugeridos usan el mismo cálculo. Limpiar reconoce ejecutables
Mach-O además de ELF/PE y conserva archivos ordinarios con el mismo nombre.

## Pruebas reproducibles

`Source/Tests/SafetyTest/build.sh --run` necesita FPC, Python 3 y un sistema
Unix. En macOS, usar FPC 3.2.4 y `FPCFLAGS="-B -k-no_fixup_chains -Cr -Co -Ct -CR -Sa -gh -gl"`.

- Ocho pruebas de archivos: escritura completa/vacía, fallo real a mitad de
  escritura (`RLIMIT_FSIZE`), solo lectura, permisos/xattrs, enlace simbólico,
  enlace duro, destino inválido y commit/descarte de INI.
- Resultado de proceso: salida 7 sin diagnóstico, ejecutable ausente, señal,
  última línea sin LF, cancelación y desaparición del proceso hijo.
- Ejecutor real con stubs únicamente para dependencias visuales no utilizadas:
  diez reinicios supervisados, cincuenta cancelaciones inmediatas y finalización
  natural, reinicio desde el callback de terminación y fallo de lanzamiento; compilado con comprobaciones de rango y detector de fugas.
- En macOS, un seudoterminal privado comprueba entrada de teclado y parada de
  descendientes iniciados desde una sesión separada. `open` y `osascript` están
  simulados: no abre ni cierra ventanas del usuario.

`Source/Tests/SafetyTest/integration.sh` necesita macOS/Cocoa y Lazarus 3.8
(`LAZBUILD` admite la ruta del compilador y de Lazarus). Usa la ventana, los
editores, el proyecto y el compilador reales, con respuestas deterministas en
la frontera de los diálogos. Comprueba cancelación/error/éxito de Guardar como,
archivo vaciado, solo lectura, renombrado fallido y con sobrescritura, fallo de
Guardar como de proyecto, cierre fallido/cancelado/descartado, errores de
compilación y la secuencia F11 fallido → F9. También prueba Limpiar con un
encabezado Mach-O y un archivo ordinario. No es una inspección visual de los
diálogos nativos. Se desactiva DWARF en este ejecutable de prueba para evitar un
error interno de FPC al describir la subclase Cocoa de prueba.

MakefileTest construye, ejecuta y limpia proyectos reales con y sin carpeta de
objetos, incluyendo `src/util.c` y `src/util.cpp`, espacios y metacaracteres.
SafetyTest se añade a los workflows Linux y macOS. La integración Cocoa es
opcional y separada de las pruebas de consola.

Resultado local: ocho pruebas de archivos, 32 comprobaciones de procesos/terminal,
37 de integración Cocoa y 53 de MakefileTest correctas. Compilaciones Cocoa
Release y Debug correctas, sin errores de Pascal. El linker mantiene los avisos
conocidos de alineación de las tablas threadvar de FPC. Los helpers de archivos
y ejecución también compilan con FPC 3.2.2; eso no acredita una ejecución Linux.

## Límites

- La escritura es atómica por archivo; Guardar todo no es una transacción global
  entre todos los archivos. Un archivo guardado antes de otro fallo permanece
  guardado. No se acredita recuperación frente a corte eléctrico, ni edición
  concurrente por otro proceso.
- Los procesos que deliberadamente se desacoplan mediante otra sesión/grupo
  pueden escapar del seguimiento. No se persiguen procesos ajenos por nombre.
- No se borran automáticamente los objetos de nomenclaturas antiguas que hayan
  quedado en disco; el Makefile nuevo deja de utilizarlos.
- Estas pruebas no sustituyen una instalación real, ni toda combinación visual,
  ni la ejecución nativa de Linux. La salida de consola, páginas de códigos y colores
  Windows se tratan después en [las etapas 3 y 4](QA_STAGES_3_4.md).
