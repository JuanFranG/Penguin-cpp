# Auditoría de interfaz y preferencias heredadas — 0.5.6

Penguin cpp es un IDE nativo de C/C++ para un usuario local, con proyectos pequeños o medianos. Se revisaron los flujos compartidos de configuración, recursos, edición, zoom y disposición; los 36 formularios activos y las referencias a componentes heredados. La causa reproducida de los errores de idioma y fuente es la migración del lector INI, no una DLL de Embarcadero que falte en macOS.

## Debía corregirse

1. **Las comillas acumuladas afectaban a más partes del IDE que el idioma.**
   - Contexto: `FileTransactions.pas:136`, `devCFG.pas:2300` y `devCFG.pas:2355` cargan rutas y preferencias. El respaldo real contiene `Name="""Courier New"""`, además de claves de terminal, codificación y formateadores con capas sobrantes.
   - Problema: el nombre de fuente deja de reconocerse; los programas y carpetas pueden dejar de encontrarse. Los argumentos del formateador pueden convertirse en un único argumento incorrecto.
   - Corrección: recuperar capas en nombres, rutas y opciones cerradas. Para FullCommand del formateador, deducir las capas extra del nombre de su ejecutable, conservando las comillas propias de los argumentos. Regresión de comandos y rutas, sin borrar el INI.
   - Sin corregirlo: reaparecen fallos aparentemente independientes en traducciones, edición, terminal y formato. **Corregido.**

2. **Una fuente heredada de Windows podía caer en una sustitución proporcional.**
   - Contexto: `devCFG.pas:2355` aplica la fuente persistida; el diálogo ya tenía una selección de fuentes monoespaciadas, pero la carga del editor no aplicaba esa recuperación.
   - Problema: una fuente inexistente en el equipo produce espaciado y columnas impropios de un editor de código. Se reprodujo con el nombre entre comillas de la captura del usuario.
   - Corrección: recuperar el nombre y usar la preferencia monoespaciada nativa disponible cuando la familia no existe. Validar los tamaños de editor y limitar el selector a los mismos 6–72 puntos del zoom.
   - Sin corregirlo: abrir un archivo puede verse mal aunque los menús ya estén traducidos. **Corregido y probado abriendo C++.**

3. **Las marcas del margen podían invadir los números y perder su fila al plegar.**
   - Contexto: `Editor.pas:627` centraba las imágenes en todo el margen y recorría líneas consecutivas sin convertir filas visibles a líneas del documento.
   - Problema: con el ancho medido, ese centro cae dentro de la parte de numeración. Al plegar un bloque, la línea lógica y su fila visible dejan de coincidir.
   - Corrección: centrar en la parte de marcas de SynEdit y convertir cada fila visible a su línea lógica. Prueba de geometría a distintos zooms y prueba de dibujo de un breakpoint tras plegar.
   - Sin corregirlo: números tapados o un icono que parece señalar otra línea. **Corregido.**

4. **El panel de proyecto restauraba un ancho desproporcionado.**
   - Contexto: `main.pas:6493`; el INI del usuario conserva 689 puntos y la captura muestra casi media ventana dedicada al panel lateral.
   - Problema: restaurar el valor sin comprobar el espacio disponible reduce innecesariamente el editor.
   - Corrección: recuperar un ancho compacto cuando el valor guardado supera un tercio del cliente de la ventana, respetando el mínimo necesario para sus pestañas. No se limita el arrastre manual posterior.
   - Sin corregirlo: la distribución mala persiste en cada arranque. **Corregido y probado con un ancho guardado de 9.000 puntos.**

5. **El lector ignoraba subsecciones válidas y manejaba mal números dañados.**
   - Contexto: `CFGData.pas:142`. Salía al faltar la sección padre, aunque existiera `Editor.Font`; usaba 1 como sustituto de enteros y conversiones que podían interrumpir el resto de preferencias.
   - Problema: un INI parcial pierde su fuente válida; un número inválido puede sustituir un tamaño sensato o dejar sin leer las propiedades posteriores. La conversión de 64 bits utilizaba una conversión de 32 bits.
   - Corrección: comprobar cada propiedad/subsección, conservar el valor actual cuando un número no se puede leer y usar conversión de 64 bits. Regresión con enteros/decimales dañados y 4.294.967.296.
   - Sin corregirlo: configuraciones parciales o dañadas generan fallos difíciles de relacionar con su origen. **Corregido.**

6. **La opción de fuente independiente del margen no describía la implementación nativa.**
   - Contexto: `EditorOptFrm.pas:323` y `devCFG.pas:2530`; el formulario permitía editar una fuente que SynEdit de Lazarus no usaba para dibujar la numeración.
   - Problema: el usuario podía configurar un tamaño esperando que no cambiara al ampliar el código, sin efecto real.
   - Corrección: controles sincronizados y de solo lectura para esa opción heredada; explicación traducible de que números y editor usan la misma fuente y zoom. El tamaño del margen sigue la cantidad de dígitos, sin crecimiento acumulado. El control heredado se limita a los 12 dígitos que admite SynEdit; el modo fijo se aplica a la numeración y el ancho total sigue adaptándose a las partes del margen.
   - Sin corregirlo: la interfaz promete un comportamiento que no implementa. **Corregido.**

## Conviene limpiar o implementar por separado

7. **El interruptor de ligaduras conserva estado, pero no lo aplica al editor.**
   - Contexto: `ShowLigatures` en `devCFG.pas` y `cbLigatures` en `EditorOptFrm.pas`; sus referencias son declaración, carga, guardado y valor inicial.
   - Problema: alternarlo no cambia ninguna opción del renderizador en el flujo de AssignEditor.
   - Propuesta: conectar una implementación real o retirar el interruptor de la interfaz nativa. **Pendiente; no se afirma que esté implementado.**

8. **Quedan preferencias históricas sin consumidor de ejecución.**
   - Contexto: `GenericCMD1/2/3`, `FindCols`, `CompCols` y los campos de asociaciones de `devCFG.pas`. La búsqueda incluye Pascal, recursos, pruebas y configuración del proyecto.
   - Problema: aumentan la superficie de mantenimiento, aunque guardar estas claves no implica cargar bibliotecas Windows. Los arrays de estilos Delphi y colores de `DataFrm.pas` no tenían referencias y se retiraron.
   - Propuesta: decidir su migración al retirar serialización antigua; conservar la capacidad de leer configuraciones previas. **Los campos publicados se mantienen por compatibilidad; los arrays muertos se eliminaron.**

## Qué procede de Windows y sigue teniendo una función

- Las páginas de códigos de los `.lng` se utilizan para leer traducciones históricas y convertirlas a UTF-8.
- Los recursos e iconos de proyectos `.dev` se conservan como metadatos; los recursos no admitidos por un destino tienen un diagnóstico explícito.
- Wine y los encabezados de MinGW forman el entorno opcional para programas Windows, separado del IDE nativo.
- Los bloques Windows de creación de procesos y ShellExecute están condicionados por plataforma. En macOS el enlace inspeccionado utiliza Cocoa, Foundation y bibliotecas de Apple, sin VCL ni DLL de Embarcadero.
- Los cuatro directorios actuales de `Source/VCL` contienen el analizador/navegador, las opciones de compilación, el monitor de archivos y los atajos que utiliza el IDE. El nombre histórico de la carpeta no los convierte en código sin uso. `Source/Tools/LangCheck` es una utilidad separada, fuera del ejecutable principal.

## Evidencia y alcance

- **Cocoa y Qt5:** comprobación estructural de 36 formularios, 88 clases y 9.384 propiedades/eventos por plataforma, sin problemas.
- **Idiomas:** 32 archivos y 1.232 cadenas de referencia, con respaldo al inglés donde falte una traducción; 39.424 comprobaciones por plataforma.
- **Editor:** apertura real de C++, recuperación de nombres de fuente, disponibilidad de familia monoespaciada, ancho lateral y controles de fuente.
- **Margen:** archivos de 9, 99, 999 y 10.000 líneas; zoom de 6, 24 y 72 puntos y vuelta al tamaño anterior; modo fijo de cuatro dígitos y regreso al automático; separación de iconos y números y posición del breakpoint con código plegado.
- Se inspeccionaron los puntos compartidos y las declaraciones de los formularios; el grafo existente se usó como orientación y se contrastó con el código actual. La consulta amplia del grafo tenía salida truncada y no se utilizó como prueba de cobertura completa.

**Veredicto:** los fallos reproducidos pertenecen a la lectura de preferencias y a diferencias entre los componentes de Delphi y Lazarus. No se encontró una dependencia activa de VCL/DLL Windows que explique estas capturas. Las correcciones necesitan paquetes regenerados; las pruebas de los paquetes anteriores no se atribuyen automáticamente a esta revisión.

**No comprobado:** todas las combinaciones visuales de 36 formularios × 32 idiomas × fuentes/resoluciones; motores de terceros, todo el analizador de C++, todos los flujos del depurador o un Mac limpio. Esta auditoría se centra en interfaz, persistencia y adaptación de plataforma, no es una certificación de ausencia de errores en todo el repositorio.

## Bloqueo encontrado en la reinstalación final

La app completa instalada terminó correctamente el self-test, pero el hilo principal quedó dentro de `TSetupForm.Destroy → TThread.WaitFor → pthread_join`. El trabajador ya había terminado y el único hilo Pascal activo era el monitor de archivos. El formulario repetía `WaitFor` en cada tick de estado listo y en su destructor. En FPC/Unix, `WaitFor` vuelve a unir el identificador nativo aunque se hubiera recolectado antes; ese identificador puede pertenecer ahora a otro hilo. Se limita la espera a una sola vez por trabajador, también al reintentar y cancelar. La regresión crea otro hilo después de terminar la preparación y comprueba que cerrar el diálogo no espera a ese hilo ajeno.


## Follow-up fixes after the 0.5.6 release (not yet in its installers)

The illustrated manual exposed further native Cocoa problems. This follow-up fixes truncated check/radio labels, the blank project-template view (a native table needs columns and must not read absent icons), overlapping template/footer controls, incremental-search sizing and initial background, and formatter errors displayed as source. Optional missing clang-format is now reported inline with execution disabled; a failed formatter cannot replace the sample or its scratch file.

The debugger's controls now reflow with spacing. ARM64 CPU views omit the irrelevant Intel/AT&T syntax selectors. Project flags use a short translated Add button with the full purpose in its hint. Existing Help handlers in project/editor/environment dialogs are enabled.

Opening a project member through File → Open now preserves project membership and its editor association. Project navigation also repairs an already-open standalone editor. This prevents an unintended single-file build when the other implementation belongs to the project.

The English/Spanish manual adds a downloadable, compiled three-file C++ project, include guards, declarations/implementations, project file participation, include/library/output directories, compiler/linker flags, and an actual LLDB session with left=2, right=3, total=5, registers and call frames. The expanded reference contains 47 views with English screenshots. Refreshed patched-source views are explicitly distinguished from public 0.5.6 installer behaviour.

Native Cocoa regression coverage checks template selection, search geometry and pre-show colour, project membership, and failing formatter isolation. The existing Linux/Qt5 CI runs the same integration tests. Screenshot coverage does not imply every feature, translation, font size or resolution was tested. The legacy icon-library picker remains a separately documented limitation.
