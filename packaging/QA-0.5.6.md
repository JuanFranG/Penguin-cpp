# Validación del hotfix 0.5.6

## Causa y recuperación

La sustitución del lector `TIniFile` por `TMemIniFile` para guardar atómicamente dejó de eliminar las comillas de valores INI antiguos. Las lecturas y guardados anteriores podían acumularlas: `Language=""English.lng""` y `Lang=""%path%\Lang/""`. El archivo existe, pero la ruta con comillas no se puede abrir y el fallo alcanza a toda la interfaz.

`TAtomicIniFile` conserva ahora `ifoStripQuotes` y recupera las parejas acumuladas en rutas, idioma, tema y fuente de interfaz. Las comillas significativas de comandos conservan el comportamiento anterior de TIniFile. No se borran preferencias ni proyectos.

## Todos los idiomas

La regresión de interfaz utiliza Cocoa y Qt5 reales. Arranca desde una configuración antigua, carga **los 32 archivos `.lng`**, comprueba cada nombre seleccionado y las **1.231 cadenas de referencia no vacías** con su respaldo al inglés: 39.392 comprobaciones por plataforma. Cocoa y Qt5 completan la prueba. Esto comprueba la carga y el respaldo, no que todas las traducciones estén completas ni la composición visual de cada frase en cada formulario.

Las pruebas de configuración con Free Pascal 3.2.2 comprueban comillas simples y acumuladas, fuente de interfaz, conservación de comandos y los fallos de guardado atómico.

## DMG

El DMG nativo definitivo se monta en solo lectura. Se arranca **su propio ejecutable**, desde una carpeta de trabajo temporal y con una copia del respaldo real dañado del usuario. System Events verifica los menús File, Edit, Search, View, Project, Execute, Tools, Formatting, Window y Help y las entradas New/Open/Save. No aparecen identificadores `translation missing`. Los 32 idiomas del DMG coinciden byte por byte con el origen.

## PKG

Se genera el PKG **completo**, con el perfil de dependencias revisado y sus fuentes correspondientes. Se extrae con `pkgutil --expand-full`, se verifica la firma ad hoc y se ejecuta la app del payload con el mismo respaldo dañado. Los menús vuelven a ser legibles y los 32 archivos de idioma coinciden con el origen. La prueba del payload no sustituye la instalación con administrador; su resultado se registra por separado al terminar.

## DEB

Se compila la aplicación Qt5 en Ubuntu 24.04 amd64, en Docker sobre Apple Silicon. Las regresiones de configuración e idiomas se ejecutan como usuario normal. El paquete se construye con sus herramientas LLVM-MinGW/UCRT y el paquete Wine privado, sin modificar el Wine del anfitrión. La prueba del ejecutable extraído y el resultado de instalación se registran por separado.

La prueba independiente de cancelación de descendientes falla dentro del contenedor amd64 emulado; no se da por validada por esta ejecución. La prueba de archivos de solo lectura exige usuario sin privilegios: ejecutarla como root invalida esa condición. Los trabajos CI x64 nativos siguen siendo necesarios para ampliar esa evidencia.

## Página del proyecto

Se mantienen manual, repositorio APT e instalador nativo. Se comprueban recursos locales, anclas, relaciones de pestañas y JavaScript. Revisión en navegador a 390 y 1.440 píxeles, sin desbordamiento horizontal. El tema utiliza exclusivamente `prefers-color-scheme`: sigue al sistema/navegador, sin selector, almacenamiento local ni una opción impuesta. Las capturas y su procedencia se describen en `site/assets/README.md`.

## Límites

Los paquetes macOS siguen sin Developer ID ni notarización. Las pruebas de este equipo no acreditan un Mac limpio ni otras versiones de macOS. La compatibilidad Windows conserva los límites documentados en 0.5.5.
