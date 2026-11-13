# Verificación de Penguin cpp en macOS

Entorno local: Apple Silicon, macOS 27.2. El destino mínimo del binario
es macOS 11.0; eso no demuestra ejecución en esa versión.

## Actualizaciones

- Menú Ayuda y botón de Acerca de conectados al diálogo nuevo.
- Consulta real: la versión publicada era 0.2.2 y se mostró «actualizado».
- Consulta simulada 0.3.0: botón Actualizar ahora habilitado y diálogo sin
  recortes ni superposiciones en Cocoa.
- Documento sin guardar: Actualizar ahora abrió el aviso de guardado;
  Cancelar conservó el texto y el editor abierto.
- Con un instalador simulado dentro de una copia temporal de la app:
  clic, cierre, ejecución del instalador y reapertura automática comprobados.
  No se sustituyó la instalación del usuario con el paquete publicado antiguo.
- 14 pruebas del núcleo: versiones, URL del repositorio, errores, cancelación
  y ausencia de curl. Pasaron en macOS y Ubuntu 24.04 arm64 (Docker).
- Lanzador compilado también en Linux. La ejecución real de sudo/APT desde
  un escritorio Linux y la actualización entre dos releases publicadas quedan
  pendientes; el contenedor no tiene un escritorio ni Penguin cpp instalado.
- Cuatro pruebas del instalador: éxito, copia parcial, fallo al verificar y
  fallo al reemplazar. Las tres últimas conservaron/restauraron la app anterior.

## Depuración y objetos

- Adjuntar a proceso añadido al menú Ejecutar y habilitado para programas
  independientes y proyectos, fuera de una compilación o depuración activa.
- Prueba LLDB real con proceso propio: adjuntar, detener y desconectar
  conservando el proceso. Sin fugas detectadas por heaptrc.
- Prueba desde el menú: selección de `attach`, conexión y lectura de pila,
  instrucciones y registros; desconectar mantuvo vivo el PID del proceso. Se corrigieron recortes del selector y el aviso
  de error incorrecto por el SIGSTOP inicial de la conexión.
- Prueba make/cc: dos fuentes util.c en carpetas diferentes, salida común,
  ejecución correcta y limpieza. Pasó en macOS y Ubuntu. Se comprueba también
  que nombres iguales con extensiones distintas generan objetos diferentes.

## Interfaz y distribución

- Se mantienen las correcciones de barra de herramientas, bienvenida,
  Opciones del editor/entorno/compilador, búsqueda y CPU.
- Comprobación estructural de los 37 formularios: clases, propiedades,
  enumeraciones y eventos: 9.821 comprobaciones, sin problemas. Esto no sustituye inspeccionar
  visualmente cada formulario en ejecución.
- Asistente inicial: instrucciones de bibliotecas específicas para macOS.
- Compilaciones Cocoa Release y Debug verificadas localmente.
- App empaquetada con firma ad hoc e instalador incluido. Firma e integridad
  del DMG verificadas.
- Copia temporal con cuarentena: `spctl --assess --type execute` devolvió
  **rejected**. La app carece de Developer ID y notarización; no se quitó la
  cuarentena ni se cambió Gatekeeper para esta evaluación. El instalador ya
  no elimina el atributo de cuarentena de la app.
- Workflow macOS añadido con herramientas fijadas, compilaciones, pruebas,
  comprobación de formularios y DMG. YAML y scripts validados localmente;
  ejecución del workflow en GitHub pendiente de publicar estos cambios.

## Cobertura pendiente

No se dispone de un Mac limpio ni un sistema macOS 11.0 para ejecutar estas
pruebas. Tampoco se ha completado la inspección visual individual de los 37
formularios, todas las traducciones, fuentes y resoluciones, impresión/PDF,
exportaciones, perfilador y todas las plantillas. Estos puntos no se dan por
aprobados por el resultado de las pruebas estructurales o de compilación.

La nueva función debe publicarse en una versión posterior para que los
usuarios puedan recibirla. Las versiones que aún no tienen este menú
necesitan instalar esa primera actualización por el método habitual.
