<p align="center">
  <img src="Source/Images/AppIcon/hicolor/256x256/apps/penguin-cpp.png" alt="Icono de Penguin cpp" width="180">
</p>

<h1 align="center">Penguin cpp</h1>

<p align="center"><strong>Un IDE de C/C++ sencillo, libre y nativo para Linux.</strong></p>

Penguin cpp expande Embarcadero Dev-C++ a Linux. Es el mismo entorno ligero
con el que mucha gente aprende C y C++, ahora como programa nativo de Linux,
sin Wine.

> **Estado: versión 0.2.0.** El IDE funciona en Linux Mint (paquete `.deb` y
> repositorio APT) y en macOS con Apple Silicon (`.dmg`, en pruebas). Ver
> [ROADMAP.md](ROADMAP.md).

---

## Objetivo

Penguin cpp tiene **propósitos educativos y de divulgación**:

- **Para aprender y enseñar.** Estudiantes, docentes, talleres y cursos
  tienen en Linux la misma herramienta que se usa en muchas aulas con
  Windows. Se instala y se usa sin configuraciones complicadas.
- **Para divulgar.** Muestra que un IDE clásico de Windows puede pasar a
  Linux como software libre, y documenta cómo se hizo: cada fase del port
  está explicada en [ROADMAP.md](ROADMAP.md) y en el historial de commits.
- **Producto final: un paquete `.deb`** para Debian, Ubuntu, Linux Mint y
  derivadas. Se instala con `apt`, trae sus dependencias (gcc/g++, gdb,
  make) y aparece en el menú de aplicaciones.

---

## Qué ofrece

Lo que trae del Dev-C++ original y se está portando:

- Editor con resaltado de sintaxis de C/C++, temas de color y numeración de
  líneas.
- Navegador de clases y autocompletado, con un analizador de C++ propio.
- Proyectos y plantillas (consola, bibliotecas…).
- Compilación con el gcc/g++ del sistema, con errores que se pueden clicar.
- Depuración con gdb.
- Formateo de código con AStyle o clang-format.
- Traducida a más de 30 idiomas, incluido el español (con variantes de
  España y Colombia).

Qué funciona hoy y qué falta está en [ROADMAP.md](ROADMAP.md).

---

## Instalación

Penguin cpp se instala con `apt` en Debian, Ubuntu, Linux Mint y derivadas
(amd64). `apt` instala también todo lo que necesita: gcc, g++, make, gdb,
astyle y clang-format.

Una sola vez, agrega su repositorio y la clave con la que está firmado:

```bash
curl -fsSL https://juanfrang.github.io/Penguin-cpp/penguin-cpp.gpg | sudo tee /usr/share/keyrings/penguin-cpp.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/penguin-cpp.gpg] https://juanfrang.github.io/Penguin-cpp stable main" | sudo tee /etc/apt/sources.list.d/penguin-cpp.list
sudo apt update
```

Después se instala como cualquier programa, y las versiones nuevas llegan con
`sudo apt upgrade`:

```bash
sudo apt install penguin-cpp
```

También se puede descargar el `.deb` de
[Releases](https://github.com/JuanFranG/Penguin-cpp/releases) e instalarlo
directamente (sin actualizaciones automáticas):

```bash
sudo apt install ./penguin-cpp_0.2.0_amd64.deb
```

Después aparece en el menú, en *Programación* y *Educación*. También se abre
desde una terminal con `penguin-cpp`, y `man penguin-cpp` explica sus opciones.

Para desinstalarlo:

```bash
sudo apt remove penguin-cpp
```

La configuración de cada usuario queda en `~/.config/penguin-cpp` y sus
plantillas en `~/.local/share/penguin-cpp`; se pueden borrar a mano. Si el IDE
tiene un error, lo anota en `penguin-cpp-errores.txt`, en el Escritorio.

### macOS (Apple Silicon)

La versión para Mac está en pruebas. Se instala (y se actualiza) con una
línea en Terminal, que descarga la última versión, la pone en Aplicaciones y,
si faltan, pide las Command Line Tools de Apple (clang, make y lldb):

```bash
curl -fsSL https://juanfrang.github.io/Penguin-cpp/install-macos.sh | bash
```

Así macOS la abre directamente. También se puede descargar el `.dmg` de
[Releases](https://github.com/JuanFranG/Penguin-cpp/releases/latest) y
arrastrar *Penguin cpp* a Aplicaciones; como la app no está firmada por un
desarrollador de Apple, la primera vez hay que abrirla, cerrar el aviso y
pulsar *Abrir igualmente* en *Configuración del Sistema > Privacidad y
seguridad*.

El formateador de código (astyle) viene dentro de la app. La configuración
queda en `~/Library/Application Support/penguin-cpp`.

## Compilar desde el código

Necesitas Lazarus 3.0 o superior y Free Pascal 3.2.2 (Linux Mint 22 /
Ubuntu 24.04):

```bash
sudo apt install lazarus fpc g++ gdb make git python3 lcl-qt5-3.0 libqt5pas-dev
git clone https://github.com/JuanFranG/Penguin-cpp.git
cd Penguin-cpp
lazbuild -B --ws=qt5 Source/penguin-cpp.lpi
./penguin-cpp
```

Para armar el paquete `.deb` (queda en `build/deb/`):

```bash
sudo apt install dpkg-dev lintian
packaging/build-deb.sh
```

En macOS hacen falta Free Pascal 3.2.4 y Lazarus 3.8 (Free Pascal 3.2.2 no
puede enlazar programas Cocoa con el enlazador actual de Apple). La app y el
`.dmg` quedan en `build/macos/`:

```bash
LAZBUILD="ruta/a/lazbuild --lazarusdir=ruta/a/lazarus --compiler=ruta/a/fpc" packaging/build-macos.sh
```

Las pruebas y más detalles están en [ROADMAP.md](ROADMAP.md#cómo-compilar-y-probar-linux).

---

## Autor

**Juan Francisco Gonzalez Pacheco**: Ingeniería de Sistemas, Universidad
del Magdalena.

El port se desarrolló con la asistencia de **Claude Opus 5.5**, el modelo
de inteligencia artificial de Anthropic.

## Origen

Penguin cpp parte del código de **Embarcadero Dev-C++**
(<https://github.com/Embarcadero/Dev-Cpp>), que a su vez continúa a
**Orwell Dev-C++** y a **Bloodshed Dev-C++**
(<https://www.bloodshed.net/devcpp.html>). El proyecto original solo funciona
en Windows y está hecho con Delphi.

Para llevarlo a Linux se pasó a **Lazarus y Free Pascal**, y se quitó todo lo
que solo existe en Windows. El historial completo del proyecto original se
conserva en este repositorio. Sus notas de versión están en
[NEWS.txt](NEWS.txt).

## Licencia

Penguin cpp es software libre bajo la **GNU General Public License, versión 2
o posterior** ([LICENSE](LICENSE)), la misma licencia del código del que
parte.

## Créditos

- **Bloodshed Dev-C++**: Colin Laplace y colaboradores.
- **Orwell Dev-C++**: Johan Mes y colaboradores.
- **Embarcadero Dev-C++**: Embarcadero Technologies y colaboradores.
- [Lazarus](https://www.lazarus-ide.org/) y [Free Pascal](https://www.freepascal.org/):
  la LCL y el componente de edición SynEdit.
- [Artistic Style](https://astyle.sourceforge.net/): formateo de código.
- Temas [Monokai](https://github.com/rbardini/devcpp-monokai) y
  [Monokai Fresh](https://github.com/sspathare97/devcpp-monokai_fresh).
- Fuentes Heebo y Source Code Pro (SIL Open Font License).

## Aviso sobre marcas

Penguin cpp es un proyecto independiente. **No está afiliado a Embarcadero
Technologies ni cuenta con su respaldo.** "Embarcadero" y "Delphi" son marcas
registradas de sus dueños. Aquí se nombran solo para indicar de dónde viene
el código.
