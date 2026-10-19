# Seguridad

## Versiones con soporte

Penguin cpp está en desarrollo. Solo la versión más reciente recibe
correcciones de seguridad.

| Versión | Soporte |
| ------- | ------- |
| 0.1.x   | ✅ |
| Dev-C++ 6.x y anteriores (Windows) | ❌ No son parte de este proyecto |

## Cómo reportar una vulnerabilidad

No publiques la vulnerabilidad en un *issue* abierto. Repórtala en privado
desde la pestaña **Security** del repositorio, con **Report a vulnerability**
(<https://github.com/JuanFranG/Penguin-cpp/security/advisories/new>).

Incluye, si puedes:

- Qué versión o *commit* usaste y en qué distribución (por ejemplo, Linux Mint 22).
- Los pasos para reproducirla: un archivo, un proyecto `.dev` o un nombre de
  archivo que la provoque.
- Qué pasa y qué debería pasar.

Es un proyecto educativo mantenido por una persona: la respuesta puede tardar
algunos días. Si tienes una corrección, puedes proponerla junto con el reporte.

## Qué cuida el IDE

Penguin cpp compila y ejecuta código, así que estas son las reglas con las que
está hecho. Los detalles están en [ROADMAP.md](ROADMAP.md) (fases 3, 4 y 6).

- **Los comandos del IDE no pasan por el shell.** gcc, make, la terminal y los
  formateadores reciben cada argumento por separado. Un nombre de archivo con
  `$(…)`, comillas invertidas o `;` es texto, nunca código. Al depurar, gdb
  arranca el programa a través de `/bin/sh` (sin shell partiría los
  argumentos en cada espacio): cada argumento va entre comillas simples, así
  que llega tal como se escribió y nada en él se ejecuta.
- **Los Makefiles citan cada nombre de archivo** para `make` y para `/bin/sh`.
  Los nombres que `make` no puede representar (saltos de línea, `%`, `:`, `;`,
  `=`, `|`, `#`, `\`, `*`, `?`, `[`, `]`) detienen la compilación con un aviso.
- **Proyectos de terceros.** Un proyecto `.dev` puede traer su propio Makefile,
  comandos de compilación u opciones que ejecutan programas. Al abrir uno así,
  el IDE muestra lo que ejecutaría y pregunta; la respuesta se guarda en tu
  configuración, no en el proyecto.
- **Archivos temporales privados.** Las copias para formatear o imprimir van en
  `~/.cache/penguin-cpp/tmp` (permisos 0700), nunca en `/tmp`.
- **Instancia única privada.** El socket con el que un segundo arranque le pasa
  archivos al IDE abierto está en `$XDG_RUNTIME_DIR`, al que solo entra tu
  usuario.

## Fuera del alcance

- Compilar o ejecutar un programa es ejecutar su código: Penguin cpp no aísla
  los programas que compilas.
- Las vulnerabilidades de gcc, gdb, make, Qt o Lazarus se reportan a sus
  proyectos.
