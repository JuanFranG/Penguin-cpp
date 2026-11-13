# Prototipo de compatibilidad nativa

Código nuevo con licencia MIT. SDL3 conserva su propia licencia zlib. El
prototipo no instala encabezados en el sistema, no modifica el código del
alumno y no está activado automáticamente en Penguin cpp 0.3.0.

En macOS compila como ARM64 y exige el renderer Metal de SDL3. Si Metal no
está disponible informa un error: no cambia silenciosamente a OpenGL.
En Linux utiliza el renderer disponible de SDL3. La consola conserva el
comportamiento de terminal POSIX; no necesita Wine ni Rosetta.

## Compilar y comprobar

Se necesita un compilador C++17 y SDL3. No se incluyen binarios de terceros
ni redistribuibles propietarios en esta carpeta.

macOS, con el framework de la distribución oficial de SDL3:

```sh
python3 Compat/native/build.py \
  --sdl-framework /ruta/al/directorio/que/contiene/SDL3.framework \
  --run-tests
build/native-compat/legacy_demo
```

Linux, con SDL3 de desarrollo y pkg-config configurados:

```sh
python3 Compat/native/build.py --run-tests
# Para las pruebas sin pantalla:
SDL_VIDEODRIVER=dummy python3 Compat/native/build.py --run-tests
```

`CXX` permite elegir Clang o GCC. El programa del alumno se compila agregando
`-ICompat/native/include`, `Compat/native/src/compat.cpp` y las opciones de
SDL3 del sistema. El ejemplo conserva `#include <graphics.h>`,
`#include <conio.h>` y `#include <bits/stdc++.h>`.

## Contrato inicial

| Área | Implementado |
|---|---|
| Gráficos | initwindow(w,h,title), initgraph, closegraph, graphresult/grapherrormsg, getmaxx/y, set/getcolor, set/getbkcolor, cleardevice, line, rectangle, circle, bar, put/getpixel, delay, outtextxy |
| Colores/relleno | Paleta BGI de 16 colores; EMPTY_FILL y SOLID_FILL |
| Consola | getch/_getch, kbhit/_kbhit, getche, clrscr, gotoxy, textcolor/textbackground |
| bits/stdc++.h | Agregador propio de encabezados estándar comunes; no es el encabezado interno de GCC |

En una ventana gráfica, getch/kbhit reciben letras ASCII, Enter, Escape y
Retroceso; cerrar la ventana hace que getch devuelva EOF. En consola leen
bytes del terminal sin Enter. getche hace eco en consola. gotoxy usa
coordenadas de consola con origen (1,1). Los colores y el cursor de consola
necesitan una terminal que interprete secuencias ANSI.

initgraph abre un lienzo fijo 640x480 y no carga controladores BGI externos.
outtextxy usa el texto de depuración de SDL (no los tipos de letra BGI).
getpixel devuelve un índice cuando el color leído coincide con la paleta.
Las operaciones gráficas deben hacerse desde el hilo principal.

No están implementados windows.h/WinAPI, todos los modos BGI, las funciones
extendidas de WinBGIm, patrones arbitrarios, tipografías BGI, Unicode,
secuencias de teclas extendidas de DOS/Windows ni todas las extensiones GNU
(como ext/pb_ds). Este perfil no sustituye libstdc++ ni permite enlazar una
biblioteca Windows dentro de un ejecutable macOS/Linux.

## Verificación

- El ejemplo prueba dimensiones, píxeles de barras y círculos, put/getpixel,
  errores de argumentos y uso después del cierre.
- En macOS exige y comprueba que el renderer devuelva `metal`.
- La prueba con un pseudoterminal comprueba entrada sin Enter, kbhit,
  getch y restauración de ajustes. Excluye PENDIN de la comparación porque
  Darwin lo mantiene como estado de entrada pendiente, no como ajuste.
- No se ha probado macOS 28 ni compatibilidad con programas Windows
  arbitrarios. Las pruebas de consola y Metal no prueban Wine/FEX.

Resultados locales del prototipo (13 de noviembre de 2026): Apple Clang en
macOS ARM64 pasó las pruebas de Metal, la API desde C y el pseudoterminal.
GCC en Ubuntu 24.04 ARM64 pasó dibujo con renderer software/dummy y teclado;
no se inspeccionó una ventana Linux real. La ventana macOS fue inspeccionada
y se cerró al recibir una tecla mediante getch. Estos resultados no cubren
funciones fuera del contrato descrito arriba.
