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
