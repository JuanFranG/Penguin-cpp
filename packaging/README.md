# Paquete `.deb` y repositorio APT

Esta carpeta tiene todo lo que hace falta para el paquete de Linux:

| Archivo | Qué es |
|---|---|
| `build-deb.sh` | Compila el IDE y arma `build/deb/penguin-cpp_<versión>_amd64.deb`; lo revisa con lintian |
| `control.in`, `copyright`, `changelog`, `lintian-overrides` | Datos del paquete |
| `penguin-cpp.desktop`, `penguin-cpp.xml`, `icons/` | Entrada del menú y tipo de archivo `.dev` |
| `penguin-cpp.1`, `penguin-cpp.es.1` | Páginas de manual |
| `update-apt-repo.sh`, `apt-repo-index.html` | Arman y firman el repositorio APT |

El CI arma el paquete en cada cambio, lo instala, lo desinstala y prueba el
repositorio APT con una clave desechable. Publicar una versión lo hace
`.github/workflows/release.yml`.

## Preparación (una sola vez)

Lo hace el responsable del paquete en su equipo con Linux.

1. **Crear la clave que firma el repositorio.** `apt` comprueba con ella que
   los paquetes vienen de este proyecto:

   ```bash
   gpg --batch --pinentry-mode loopback --passphrase '' --quick-gen-key "Penguin cpp <jfgonzalez@unimagdalena.edu.co>" ed25519 sign never
   gpg --list-secret-keys --keyid-format long
   ```

   La segunda orden muestra la huella de la clave (40 caracteres). En lo que
   sigue, `HUELLA` es esa huella.

2. **Guardar una copia de la clave privada** fuera del equipo (una memoria
   USB, un gestor de contraseñas). Si se pierde, hay que crear otra y cada
   usuario tendría que volver a agregar la clave nueva:

   ```bash
   gpg --armor --export-secret-keys HUELLA > penguin-cpp-clave-privada.asc
   ```

   Ese archivo no se sube nunca al repositorio.

3. **Dársela al CI como secreto.** En GitHub: *Settings → Secrets and
   variables → Actions → New repository secret*, con el nombre
   `APT_SIGNING_KEY` y como valor todo el contenido de
   `penguin-cpp-clave-privada.asc`. Con la herramienta `gh` es:

   ```bash
   gh secret set APT_SIGNING_KEY --repo JuanFranG/Penguin-cpp < penguin-cpp-clave-privada.asc
   ```

## Publicar una versión

1. Poner el número de versión en `Source/Version.pas` (`DEVCPP_VERSION`) y
   una entrada nueva al principio de `packaging/changelog`.
2. Subir esos cambios a `main` y crear la etiqueta de la versión:

   ```bash
   git tag v0.1.0
   git push origin v0.1.0
   ```

3. El flujo *Release* compila, publica el Release con el `.deb` y el programa
   con sus símbolos, y agrega el paquete al repositorio APT en la rama
   `gh-pages`.
4. **Solo la primera vez:** en GitHub, *Settings → Pages → Build and
   deployment*, elegir *Deploy from a branch*, la rama `gh-pages` y la
   carpeta `/ (root)`. Al rato el repositorio queda en
   <https://juanfrang.github.io/Penguin-cpp/>.

## Leer un informe de errores

El `.deb` lleva el programa sin símbolos, así que las trazas de
`penguin-cpp-errores.txt` son direcciones. Con el archivo
`penguin-cpp_<versión>_amd64_symbols` del Release de esa versión:

```bash
addr2line -f -C -e penguin-cpp_0.1.0_amd64_symbols 0x9BA4B9 0x52EE0D
```

## Validación del paquete macOS

`build-macos-pkg.py` construye un `.pkg`, sin instalarlo ni subirlo automáticamente. El perfil completo revisado de la 0.5.0 se publica en GitHub. Requiere una app enlazada y declarada para macOS 26.0/ARM64.
Acepta `--app`, `--toolchain` (LLVM-MinGW existente) y `--output`. Conserva las
licencias del compilador y rechaza una app que ya contenga un runtime Windows
sin auditar. No acepta acuerdos ni descarga componentes.

La app se prepara con `build-macos.sh --app-only`; `--no-build` reutiliza un
binario ya compilado y comprueba su destino mínimo. La opción habitual sigue
produciendo el DMG. Véanse las pruebas, límites y requisitos de redistribución
en [QA-pkg-macos.md](QA-pkg-macos.md).

### Paquete completo y configuración automática

`build-macos-pkg.py` exige por defecto el compilador LLVM-MinGW, el motor curado
y GNU Make. Busca las versiones preparadas en `build/` o acepta las rutas
explícitas `--toolchain`, `--runtime` y `--tools`. Si falta un componente,
falla antes de crear el instalador. `--native-only` permite explícitamente el
paquete de validación que solo contiene el IDE, usado por CI.

El paquete completo coloca las herramientas dentro de `Penguin cpp.app`,
con sus avisos, y crea `Compat/windows/environment.json`. La primera apertura
comprueba la compilación y ejecución; no pide rutas ni instala herramientas
globales. El diálogo muestra el estado del entorno. Las rutas personalizadas
y GPTK quedan en Opciones avanzadas; Usar entorno incluido recupera los valores
del bundle. Para distribución pública exige `--publishable --source-bundle <archivo>`: comprueba el SHA-256 de las fuentes y que el manifiesto del motor coincide con `Compat/redistribution-lock.json`. Rechaza componentes opcionales excluidos. La firma Developer ID y notarización siguen pendientes; el perfil público está etiquetado como experimental y sin firmar.

`collect-runtime-sources.py` recoge revisiones y submódulos fijados; `assemble-compat-sources.py` verifica hashes y reúne fuentes, recetas, parches y avisos. No basta volver a empaquetar el archivo upstream completo. Véase [el informe](../Compat/REDISTRIBUTION.md) y [la validación](QA-pkg-macos.md).

El mismo paquete se instala desde Terminal con:

```sh
sudo installer -pkg /ruta/al/paquete-completo.pkg -target /
open -a "Penguin cpp"
# También se puede iniciar directamente el ejecutable:
"/Applications/Penguin cpp.app/Contents/MacOS/penguin-cpp"
```

La preparación inicial se ejecuta al iniciar la aplicación, con el usuario
actual, tanto mediante Finder como desde Terminal. No se inicia Wine como
root durante Installer. Si falta un componente de un paquete completo,
Penguin lo avisa y exige reinstalar el paquete completo; no omite la
comprobación silenciosamente. La compilación Windows vuelve a comprobar
el entorno y se cancela si la preparación falla o se cancela.

## Desinstalar en macOS

Cierra Penguin y mueve `/Applications/Penguin cpp.app` a la Papelera. El
compilador y el motor incluidos se eliminan con la app, sin desinstalar paquetes
por separado. La configuración y el prefix privado se conservan en
`~/Library/Application Support/penguin-cpp`. Borrar esa carpeta es opcional y
elimina también los programas y datos guardados dentro del entorno Windows.
El recibo de Installer no ejecuta una desinstalación por sí solo.
