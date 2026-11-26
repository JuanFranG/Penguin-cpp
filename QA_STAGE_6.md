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

- Acerca de: panel compacto con Juan Francisco Gonzalez Pacheco destacado como
  creador, versión enlazada a su publicación y enlaces a GitHub, documentación y
  GPL-2.0-or-later. La licencia completa no ocupa el diálogo; los créditos
  históricos y de asistencia de IA están en un botón separado.
- Actualizaciones: enlaces permanentes a GitHub y a novedades. Al detectar una
  publicación válida, el segundo apunta a ella; si falla la red, conserva el de
  la versión instalada. No es necesario aceptar instalar para leer los cambios.
- Cada versión requiere sus notas con cambios, validación y límites. El workflow
  de publicación prepara un borrador hasta completar los artefactos.
- El constructor del PKG copia explícitamente `console-startup.c`. Los paquetes
  nativos lo incorporan como recurso versionado. La actualización conserva el
  canal completo o nativo de la instalación anterior.

## Resultados de validación

- Local macOS: Default/Debug y suites ParserTest, PlatformTest, GdbMITest,
  GdbEngineTest, DapEngineTest, MakefileTest, UpdateTest, WindowsGameTest y
  SafetyTest correctas (GDB real se omite si no está instalado).
- Siete pruebas de selección de canal, reemplazo y recuperación del instalador.
- Diálogos reales Cocoa: links de novedades con versión disponible y fallo de red;
  Acerca de compacto; controles sin solapamiento. Se guardan capturas del arnés.
- Bienvenida: `PanelRight.AutoSize` movía los botones al origen en Qt5. Se
  desactivó y se comparte la distribución de filas; regresión a 1024×768 y
  1440×900 para Nuevo/Abrir/Opciones y acciones secundarias.
- PKG: extracción completa, verificación de firma de la app y presencia/hash de
  `console-startup.c`, self-test, bits/stdc++.h, licencias y actualizador; manifiesto
  revisado y binarios ARM64 del compilador, Wine y Make.
- CI Linux/Qt5, consola Linux/MinGW/Wine y actualización APT antigua: en curso;
  los resultados y enlaces se incorporarán al terminar.

## Límites que requieren otro entorno

Se instaló realmente el PKG completo con autorización del usuario mediante
Installer: la copia de `/Applications` pasó de 0.4.0 a 0.5.5 y el recibo del sistema
confirmó la versión. Se respaldó la app anterior. Desde la app instalada, un
arranque directo con HOME/configuración temporales preparó el entorno privado,
escribió `ready` y ejecutó el self-test `PENGUIN_WINDOWS_READY` con resultado correcto.
No se considera una instalación en un Mac limpio ni acredita notarización o
aceptación automática por Gatekeeper. Se mantiene macOS mínimo 26.0/ARM64.

No se acredita compatibilidad con macOS futuro ni todas las combinaciones de
pantallas, idiomas, fuentes, impresión/PDF y exportaciones. Se mantienen los
límites de lectura de preferencias malformadas y de APIs del runtime. Los
paquetes macOS siguen siendo experimentales, con firma ad hoc y sin Developer ID.
