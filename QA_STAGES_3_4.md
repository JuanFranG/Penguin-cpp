# Fiabilidad: etapas 3 y 4

> Informe histórico de desarrollo. Estos cambios se reúnen en la entrega
> **0.5.5**; la evidencia de integración y sus límites están en [QA_STAGE_6.md](QA_STAGE_6.md).


Validación de desarrollo del 26 de noviembre de 2026. Continúa las
[etapas 1 y 2](QA_STAGES_1_2.md). No cambia la versión 0.5.0 publicada ni sus
paquetes. Los cambios están en el árbol de trabajo para una entrega posterior.

## Experiencia de usuario por etapa

| Etapa | Qué cambia al usar Penguin | Estado |
|---|---|---|
| 1. Archivos y proyectos | Un error al guardar conserva el archivo anterior y los cambios pendientes; cancelar el cierre conserva el proyecto. | Implementada en desarrollo. |
| 2. Compilación y ejecución | F11 no ejecuta un binario antiguo tras fallar; F9 no hereda una orden de ejecutar; Detener y reiniciar mantienen el control del proceso. | Implementada en desarrollo. |
| 3. Configuración y entorno | Cancelar opciones del proyecto no deja cambios aplicados. Los fallos de persistencia se comunican. Reintentar el entorno privado puede conservar y recuperar una preparación incompleta. | Implementada en desarrollo. |
| 4. Consola Windows | Hay perfiles coherentes para texto Unicode y bytes heredados; el teclado funciona en el runtime probado y la terminal recupera su estado al terminar. | Implementada en desarrollo; compatibilidad Windows experimental. |
| 5. Funciones heredadas | Revisar recursos Windows/importación Code::Blocks y retirar o corregir controles que prometen funciones incompletas. | Completada después: [etapa 5](QA_STAGE_5.md). |
| 6. Cobertura y entrega | Confirmar los recorridos completos en Linux/macOS, instalación/actualización reales y más combinaciones de interfaz. | Pendiente; CI y pruebas existentes son la base. |

## Etapa 3: qué se corrigió

- El diálogo de opciones edita un proyecto separado, sin poseer los editores ni
  los nodos originales. Al aceptar copia sus opciones; al cancelar descarta la
  copia. Los valores de los compiladores globales se restauran al cerrar el
  diálogo. Las matrices de opciones también se copian sin compartir almacenamiento.
- Guardar preferencias agrupa sus secciones en una escritura atómica. Un error
  conserva el INI anterior, restaura su representación interna y se propaga al
  llamador. El cierre del IDE se detiene y muestra el error si no pudo guardarlas.
  Las propiedades editadas permanecen disponibles en memoria para reintentar.
- Las opciones Windows utilizan el mismo INI que el resto de preferencias;
  guardar después la configuración general no elimina esas opciones.
- Un prefix privado incompleto se conserva como `prefix.incomplete-{GUID}` antes
  de preparar otro. Se rechazan enlaces simbólicos en esa ruta gestionada. Las
  carpetas personalizadas no se mueven automáticamente.
- La recuperación detiene y espera al wineserver correspondiente al prefix
  privado antes de moverlo. Un entorno nuevo debe guardar sus registros antes de
  recibir el marcador «listo». El caché deja de ser válido si faltan esos archivos.
- El marcador de preparación y su registro se escriben atómicamente. Su huella
  incluye el perfil, el self-test y la preparación de consola. El asistente
  supervisa los procesos hijos y muestra los errores en un cuadro copiable con
  desplazamiento, además de indicar el registro cuando existe.

## Etapa 4: cómo elegir el perfil

En **Herramientas**, abre el diálogo de compatibilidad Windows. El selector de
consola está en la vista compacta; no necesitas introducir rutas para elegirlo.

| Perfil | Uso |
|---|---|
| Unicode (UTF-8), predeterminado | Código y cadenas UTF-8, acentos y símbolos Unicode. |
| DOS / OEM 437 | Ejemplos que construyen cuadros mediante bytes como `char(218)`, `char(196)` y `char(191)`. |
| Windows ANSI 1252 | Cadenas de bytes guardadas en esa codificación de Windows. |
| Controlada por el programa | Conserva la inicialización original; no enlaza la preparación automática. |

**Vuelve a compilar con F9 o F11 al cambiar el perfil.** El perfil se guarda
para archivos sueltos o para el proyecto correspondiente. Un archivo ya compilado
no cambia por modificar el selector.

Penguin compila un objeto pequeño desde `Compat/windows/console-startup.c`
(licencia MIT). Inicializa `LC_CTYPE` y las páginas de entrada/salida antes de
`main`; no cambia la configuración numérica, las fechas ni el ACP global de
Windows. Los cambios posteriores del programa tienen prioridad. El objeto se
integra en archivos sueltos y Makefiles generados de proyectos de consola;
Limpiar lo elimina. Cambiar a «Controlada por el programa» vuelve a enlazar sin él.

El lanzador prepara la terminal Unix para el teclado que espera el runtime y
restaura el modo y los atributos al terminar. La preparación enlazada también
conserva los atributos iniciales y recupera las páginas de consola que no hayan
sido cambiadas explícitamente durante el programa. No reescribe su código fuente.

## Validación ejecutada

- Compilaciones completas Release y Debug con Lazarus 3.8/Cocoa y FPC 3.2.4.
  Permanecen los avisos conocidos del enlazador sobre alineación de threadvars de FPC.
- UpdateTest: regresiones de consulta y cancelación de actualizaciones correctas.
- SafetyTest: pruebas de archivos/procesos anteriores y ocho comprobaciones de
  configuración: falta de ruta, solo lectura, recuperación de estado, cancelación,
  anidamiento, commit de varias secciones y conservación de opciones Windows.
- WindowsGameTest: persistencia de perfiles, prefix completo/incompleto, respaldo
  de datos, rechazo de carpetas ajenas y enlaces, argumentos y arquitectura.
- Integración Cocoa: cancelar/aceptar opciones, independencia de matrices y
  opciones globales, perfiles del diálogo, geometría sin solapamientos en compacto,
  avanzado y error, y mensaje de error copiable del asistente.
- Integración Windows real: LLVM-MinGW y Wine ARM64/FEX revisado. Archivo suelto
  con espacios y metacaracteres, proyecto con carpeta de objetos con espacios,
  cambio UTF-8/OEM, modo controlado por el programa y limpieza del objeto adicional.
  Los ejecutables se ejecutaron y comprobaron su locale real.
- Recuperación real: un wineserver en un prefix temporal incompleto, preservación
  de un archivo de datos en el respaldo y preparación del nuevo entorno mediante
  el worker real. Se utilizó HOME temporal y un prefix de pruebas; no el habitual.
- Consola en PTY 120×40: **seis casos correctos**, C y C++ con UTF-8, OEM 437 y
  ANSI 1252. `printf`, `cout`, entrada con `fgets`/`cin`, `WriteConsoleA/W`, cuadros,
  acentos, posición del cursor, atributos rojo intenso sobre azul, configuración
  explícita del programa y restauración del terminal. Los atributos se comprobaron
  por API y secuencias emitidas; no es una garantía de contraste para toda paleta.

### Reproducir

Las pruebas de consola existentes se ejecutan con sus `build.sh --run`.
En macOS, usar FPC 3.2.4 y `FPCFLAGS="-B -k-no_fixup_chains -Cr -Co -Ct -CR -Sa -gh -gl"`.

`Source/Tests/SafetyTest/integration.sh` necesita Lazarus 3.8/Cocoa. `LAZBUILD`
admite la ruta del compilador y de Lazarus. Aísla configuración y HOME; sin las
siguientes variables omite la integración Windows real:

- `PENGUIN_TEST_WINDOWS_TOOLCHAIN`: carpeta del compilador de pruebas.
- `PENGUIN_TEST_WINDOWS_RUNNER`: Wine ARM64 de pruebas.
- `PENGUIN_TEST_WINDOWS_MAKE`: GNU Make de pruebas.
- `PENGUIN_TEST_WINDOWS_PREFIX`: prefix aislado, previamente preparado.

La matriz de consola se ejecuta con
`python3 Source/Tests/WindowsGameTest/console_test.py --cc RUTA_CC --cxx RUTA_CXX --runner RUTA_WINE --prefix PREFIX_AISLADO`.
Antes, `WindowsGameTest/build.sh` compila el helper de argumentos.
Los resultados y capturas de bytes quedan en su carpeta `build/` ignorada por Git.

## Límites que permanecen

- El código es compartido con Linux y sus regresiones se incorporan a los
  workflows, pero esta validación local se hizo en macOS. La ejecución Linux
  debe confirmarse en CI y con su runtime.
- No se inspeccionaron todas las fuentes, paletas, idiomas o formularios. La
  herramienta visual no respondió; el menú se abrió con System Events y se
  midió la geometría real de los nuevos controles mediante Cocoa.
- Un perfil no puede corregir cadenas con codificaciones mezcladas, una llamada
  explícita contradictoria ni colores sin contraste elegidos por el programa.
  No convierte automáticamente todas las APIs ANSI de Windows ni sus argumentos
  de inicio a Unicode. Tampoco acredita compatibilidad completa con DOS/Win32.
- La recuperación puede cerrar servicios del prefix privado que está preparando;
  no utiliza una terminación global por nombre. Los respaldos se conservan y
  consumen espacio hasta que el usuario decida retirarlos.
- El runtime puede emitir la aserción de inicialización de un proceso auxiliar
  ya conocida de la 0.5.0, aun cuando el self-test y los programas probados pasan.
  La comprobación acredita ese conjunto de funciones, no todas las APIs Windows.
- La tolerancia de lectura de preferencias malformadas anterior no se ha
  sustituido por una migración o reparación completa del formato.

Referencias de las APIs utilizadas: [locale y páginas de códigos del CRT](https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/setlocale-wsetlocale?view=msvc-170),
[constructores de GCC](https://gcc.gnu.org/onlinedocs/gcc/Common-Function-Attributes.html) y
[opciones de wineserver en el código de Wine](https://github.com/wine-mirror/wine/blob/master/server/main.c).
