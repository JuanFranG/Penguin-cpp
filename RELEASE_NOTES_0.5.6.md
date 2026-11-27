# Penguin cpp 0.5.6

## Cambios y adiciones

- **Hotfix de idiomas:** se recupera la lectura de valores entre comillas en configuraciones de versiones anteriores. El lector de guardado atómico conserva ahora el comportamiento de `TIniFile`: `"English.lng"` se interpreta como `English.lng`. También se recuperan parejas de comillas acumuladas en rutas, idioma, tema y fuente de interfaz, conservando las comillas significativas de comandos. Esto evita que toda la interfaz muestre `<ID … translation missing>` por no poder cargar los archivos de idioma.
- **Preferencias y proyectos antiguos:** la corrección se aplica al lector INI compartido, también utilizado por proyectos y disposición de ventanas. No requiere eliminar las preferencias del usuario.
- **Página del proyecto:** presentación con la identidad de Penguin, temas claro y oscuro, capturas reales, historia de Dev-C++, motivación del port, autoría, descargas y versiones.

## Validación

La prueba de regresión carga una configuración antigua con `Language="English.lng"` y `Lang="%path%\Lang/"`, comprueba los valores resueltos y conserva las pruebas de guardado atómico. La regresión gráfica carga los 32 idiomas y comprueba todas las cadenas no vacías de referencia y su respaldo al inglés, en Cocoa y Qt5. El tema de la web sigue al sistema/navegador automáticamente. La compilación Cocoa y las pruebas de seguridad se verifican localmente. La comprobación de los paquetes se documenta en `packaging/QA-0.5.6.md`; ese informe distingue ejecución real y validación de contenido.

## Límites y pendientes

La compatibilidad Windows sigue siendo experimental. Este hotfix no amplía la cobertura de WinBGIm, depuración Windows ni de bibliotecas externas. macOS requiere 26 o posterior y Apple Silicon; los paquetes siguen sin Developer ID ni notarización. Las pruebas de una aplicación extraída de un PKG no sustituyen una instalación con administrador en un Mac limpio.
