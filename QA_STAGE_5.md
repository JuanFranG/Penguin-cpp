# Fiabilidad: etapa 5 — funciones heredadas

> Informe histórico de desarrollo. Estos cambios se reúnen en la entrega
> **0.5.5**; la evidencia de integración y sus límites están en [QA_STAGE_6.md](QA_STAGE_6.md).


Cambios de desarrollo para la próxima **0.5.5**. No publican una release ni
modifican los instaladores de la 0.5.0. Continúan las [etapas 1–4](QA_STAGES_3_4.md).

## Qué cambia para el usuario

- Los proyectos con recursos Windows activos (`.rc` o `.res`) dejan de producir
  una compilación aparentemente correcta que omite esos archivos. La compilación,
  reconstrucción y generación de Makefile muestran un error que explica el límite.
  El error no ejecuta un programa anterior ni sobrescribe el Makefile existente.
- En el destino Windows también se rechazan iconos, recursos privados, versión
  y manifiestos XP solicitados a la compilación generada: todavía no hay una
  cadena de recursos implementada. Se necesita un sistema de compilación externo.
- Al compilar nativamente se conservan esos metadatos en el `.dev`, se informa
  que no se aplican al ejecutable y no se incrementa una versión Windows que no
  se incorpora al binario. Los recursos desmarcados no bloquean esa compilación.
- Un Makefile personalizado nativo conserva el control de sus recursos. Limpiar
  sigue disponible para el proyecto aunque contenga recursos no admitidos.
- Los recursos del formato antiguo `Resources=...` se convierten en memoria a
  secciones `UnitN` correctas, conservando nombres con espacios. Abrir no modifica
  el descriptor ni sobrescribe un `.bak` existente. Guardar confirma la conversión.
- Las rutas de iconos vacías o relativas se guardan sin convertirlas en rutas
  incorrectas; aceptar opciones ya no copia ni renombra un icono oculto.
- El compilador comprueba que los eventos opcionales están asignados antes de
  llamarlos al terminar, evitando un fallo en su notificación.
- La plantilla OpenGL se presenta como **Windows / WGL** y explica su dependencia
  del runtime. OpenMP indica que requiere compilador y runtime compatibles, que
  Apple clang no incorpora por defecto. No se añadieron bibliotecas nuevas.

## Código retirado y código conservado

Se retiraron:

- El importador Code::Blocks incompleto y sus enlaces. El menú ya estaba oculto
  y deshabilitado en el estado actual; el informe de auditoría anterior lo
  describía como accesible basándose en su enlace, lo que exageraba su visibilidad.
  No se ofrece importación `.cbp` en esta versión. Los `.dev` existentes se mantienen.
- El generador de recursos situado tras un `Exit` incondicional. También se
  retiró la llamada que borraba `PrivateResource` durante una compilación.
- `FormatterOptionsFrm`: formulario antiguo sin consumidores. Se mantienen los
  diálogos activos de AStyle y clang-format.
- `Tests.pas` y la acción desactivada que ejecutaba acciones del IDE y alteraba
  compiladores; no se retiraron las suites actuales de `Source/Tests/`.
- La acción y menú ocultos de donaciones, las funciones vacías de versión y
  asociación del registro Windows, y las constantes sin consumidores de espejos,
  paquetes e importadores Visual C++/Code::Blocks.

Se conservan los formatos `.dev` y `Makefile.win`, los metadatos de intercambio,
las funciones activas del editor/depurador y la apertura con programas externos
mediante las APIs del escritorio. Los avisos de autoría y licencias permanecen.
No se eliminaron imágenes, fixtures históricos ni ramas condicionales de Windows
solo por su origen o nombre.

## Validación y pendientes

Validación local en macOS 27.2.1 / ARM64 (destino mínimo 26.0):

- Compilaciones completas Default (distribución) y Debug correctas con Lazarus
  3.8 / FPC 3.2.4. Permanecen los avisos conocidos del enlazador sobre alineación
  de threadvars; no se presentan como errores de Pascal.
- `Source/Tests/LfmCheck/check.sh`: **9.699 comprobaciones, 89 clases,
  36 formularios y cero problemas**. Comprueba estructura, propiedades y firmas
  de eventos; no sustituye la inspección visual de todas las pantallas.
- `Source/Tests/MakefileTest/build.sh --run`: regresiones de nombres, construcción,
  ejecución y limpieza correctas.
- `Source/Tests/SafetyTest/integration.sh`: IDE y controles Cocoa reales con HOME
  y configuración temporales. Rechazo de RC/RES en destinos nativo/Windows, extras
  del enlazador, reconstrucción y generación; conservación del Makefile; recurso
  inactivo; compilación nativa y guardado de metadatos; Makefile personalizado;
  finalización sin callbacks; migración, guardado y reapertura de recursos con
  espacios; conservación de la copia `.bak` preexistente. Incluye las regresiones
  anteriores de F9/F11 y geometría de los controles de compatibilidad.

También se repitió la integración Windows real con LLVM-MinGW y Wine ARM64/FEX:
recuperación del prefix aislado, compilación y ejecución de archivos sueltos y
proyectos, cambio de perfiles de consola y limpieza del objeto de preparación.
El conjunto pasó. No se probaron nuevas APIs gráficas ni se considera una
certificación general del runtime.

Las primeras ejecuciones reprodujeron la llamada a un evento no asignado y la
alteración de una ruta de icono relativa. Se corrigieron en el código compartido;
las regresiones correspondientes pasan tras esas correcciones.

La etapa 6 sigue pendiente: Linux real/CI, instalación y actualización completas,
Gatekeeper y revisión visual ampliada. Antes de empaquetar la 0.5.5 debe incluirse
`Compat/windows/console-startup.c` en el constructor del PKG y comprobarse su
presencia en los artefactos definitivos. No se ofrece aún soporte completo de
recursos Windows ni un importador Code::Blocks alternativo.
