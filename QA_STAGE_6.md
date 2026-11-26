# Penguin cpp 0.5.5 — validación de entrega

La fase 6 reúne las correcciones de las etapas 1–5, comprueba su integración y
prepara los artefactos. Este informe diferencia pruebas realizadas y límites;
se actualizará con los resultados antes de publicar la 0.5.5.

## Mejoras de uso de bibliotecas Windows

`windows.h` se compila con MinGW y se ejecuta mediante el runtime Windows, sin
reescribir el programa. `conio.h` conserva esa misma ruta. Los cambios de esta
versión evitan ejecutar un binario anterior cuando falla el compilador, conservan
el trabajo al guardar, recuperan una preparación privada incompleta y coordinan
CRT/entrada/salida de consola con perfiles UTF-8, OEM 437 y ANSI 1252. Las llamadas
explícitas del programa conservan prioridad. Un perfil no corrige codificaciones
mezcladas ni implementa APIs Win32 que el runtime no soporte.

`math.h`, `stdlib.h` y la biblioteca estándar siguen disponibles según el destino.
El encabezado `bits/stdc++.h` común sigue incluido. No se añadió WinBGIm ni
compatibilidad general con todas las bibliotecas Windows. Los recursos `.rc` y
`.res` no admitidos fallan de forma explícita; sus metadatos `.dev` se conservan.

## Actualizaciones y notas

- Acerca de: la versión instalada enlaza a su publicación y el repositorio usa
  un texto compacto para caber en el grupo.
- Actualizaciones: enlaces permanentes a GitHub y a novedades. Al detectar una
  publicación válida, el segundo apunta a ella; si falla la red, conserva el de
  la versión instalada. No es necesario aceptar instalar para leer los cambios.
- Cada versión requiere sus notas con cambios, validación y límites. El workflow
  de publicación prepara un borrador hasta completar los artefactos.
- El constructor del PKG copia explícitamente `console-startup.c`. Los paquetes
  nativos lo incorporan como recurso versionado. La actualización conserva el
  canal completo o nativo de la instalación anterior.

## Resultados de validación

En curso: compilación Cocoa, regresiones de diálogos/enlaces, checks Linux/macOS,
consola, contenido/firma de paquetes y reemplazo de instalación aislada.

## Límites que requieren otro entorno

No hay un Mac limpio ni una credencial de administrador disponible para instalar
el PKG sobre el sistema mediante Installer. La extracción y la prueba de su
aplicación no sustituyen esa instalación. Tampoco acreditan notarización o
aceptación automática por Gatekeeper. Se mantiene macOS mínimo 26.0/ARM64.

No se acredita compatibilidad con macOS futuro ni todas las combinaciones de
pantallas, idiomas, fuentes, impresión/PDF y exportaciones. Se mantienen los
límites de lectura de preferencias malformadas y de APIs del runtime. Los
paquetes macOS siguen siendo experimentales, con firma ad hoc y sin Developer ID.
