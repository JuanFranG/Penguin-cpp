# Revisión de redistribuibles Microsoft y Apple

Fecha: 13 de noviembre de 2026. Revisión documental para decidir qué podría
incorporarse a Penguin; no se han instalado binarios ni aceptado acuerdos.
Las conclusiones siguientes son una lectura técnica del texto examinado,
no una certificación jurídica. La licencia adjunta al binario adquirido manda.

## Resultado para el uso solicitado

El usuario declara uso y distribución no comerciales y quiere desarrollar
videojuegos C++ en Mac. Con ese alcance hay una base en el acuerdo GPTK
revisado para un **modo opcional de videojuegos, para equipos Apple**.
Ese alcance no debe extenderse automáticamente a ejecutar cualquier programa
Windows, a distribución comercial ni a Linux.

| Componente | Decisión de incorporación |
|---|---|
| Metal Shader Converter: `.dylib`, 4.0 beta 3 | Candidato opcional: el permiso revisado cubre distribución para conversión de shaders en equipos Apple, sujeto al resto del acuerdo. No se necesita para el prototipo SDL3/Metal actual. |
| Metal Shader Converter: herramienta CLI | El permiso de distribución de `.dylib` no cubre automáticamente la herramienta. No incluirla con ese argumento. |
| D3DMetal/GPTK 3.0/4.0 | Candidato únicamente para modo de videojuegos y distribución no comercial bajo los términos revisados. No incorporarlo como motor general de Windows. |
| Visual C++ Redistributable 2015–2022, 14.44.35211.0 | Condicional: verificar derechos del distribuidor bajo Visual Studio y cumplir su lista REDIST y requisitos. La licencia del usuario no se ha acreditado. No hace falta para los ejemplos MinGW actuales. |

## Apple: Game Porting Toolkit / D3DMetal

Se examinaron copias del acuerdo **EA18380, 17/08/2023**, publicadas junto
a GPTK 3.0 y 4.0. Sus textos extraídos resultaron idénticos.

- 2A(i): uso interno para desarrollar, probar o evaluar videojuegos para
  productos Apple.
- 2A(iii): distribución del software Apple solo con fines no comerciales.
- 2C: permite separar el Framework completo o componentes de `/redist`;
  mantiene la restricción no comercial y las restricciones de uso.
- 2A/2C: conservar avisos; solo dispositivos Apple; sin vender, alojar,
  alquilar ni sublicenciar fuera del permiso concedido.
- 2D: no modificar ni aplicar ingeniería inversa salvo las excepciones del
  propio acuerdo o de la ley.

**Lectura para Penguin:** un uso interno de videojuegos y una distribución
no comercial pueden encajar. Que una descarga no tenga precio no prueba por
sí solo que su distribución tenga fines no comerciales. La condición se
refiere al software Apple; no demuestra por sí misma una prohibición de
vender un juego nativo que no lo incluya. Si el juego distribuye D3DMetal,
hay que volver a evaluar esa distribución.

No equivale a una licencia de ejecutar aplicaciones Windows arbitrarias.
El cumplimiento de la licencia tampoco prueba compatibilidad técnica con
macOS 28, ni elimina los problemas de arquitectura Intel/Rosetta.

Copias del acuerdo Apple examinadas (espejo, no descarga autenticada Apple):

- https://raw.githubusercontent.com/Sikarugir-App/Sikarugir/main/D3DMetal/3.0/License.pdf
- https://raw.githubusercontent.com/Sikarugir-App/Sikarugir/main/D3DMetal/4.0/License.pdf

## Apple: Metal Shader Converter

Se examinó el acuerdo **EA1844, 31/05/2023**, entregado como licencia del
paquete 4.0 beta 3:

- 2B concede instalar, usar, probar y distribuir las bibliotecas `.dylib`
  exclusivamente para conversión de shaders.
- 2A trata de otra manera el resto de las herramientas y su uso interno.
- 2C/2D limita el uso a equipos Apple y exige conservar avisos; prohíbe
  vender, alquilar, alojar o sublicenciar fuera de los permisos concedidos.
- 2E prohíbe modificar, descompilar o aplicar ingeniería inversa, sujeto a
  las excepciones del acuerdo o de la ley.

**Lectura para Penguin:** puede evaluarse incluir la biblioteca original sin
alterar, para conversión de shaders en el paquete macOS, preservando acuerdo,
avisos y reconocimientos. No convierte todo el SDK o la herramienta CLI en
redistribuibles generales. No se debe presentar esta biblioteca como código
abierto ni incluirla en el paquete Linux.

Copia del acuerdo Apple examinada (espejo):
https://github.com/metalsharp/VKD3D-Proton-MacOS/releases/download/deps-metal-shaderconverter-4.0b3/LICENSE.metal-shaderconverter.rtf

Página oficial del producto:
https://developer.apple.com/metal/shader-converter/

## Microsoft: instalación y redistribución son derechos distintos

Se revisaron el acuerdo del runtime **Cpp_2015-2022_ENU.1033**, el acuerdo
**Visual Studio Community 2022**, sección 4, y la lista REDIST oficial.
El motor candidato identifica sus instaladores como 14.44.35211.0.

- El acuerdo del runtime permite instalar y usar copias, pero por sí solo
  no otorga el derecho de publicarlo ni entregarlo con nuestra aplicación.
- Microsoft reserva la redistribución a usuarios debidamente licenciados
  de Visual Studio. Eso no implica necesariamente pagar: Community permite
  ciertos usos individuales, educativos y de desarrollo de software abierto.
- La sección 4 y REDIST permiten distribuir los archivos enumerados,
  sin modificar, con una aplicación que aporte funcionalidad sustancial.
  Exigen proteger el código distribuible con términos adecuados; no permiten
  redistribuir runtimes de prueba/beta ni imponerles una licencia que exija
  revelar o permitir modificar su código.

**Lectura para Penguin:** podría incorporarse legalmente si el distribuidor
cumple esos derechos y condiciones. No se ha comprobado tal licencia y no
se afirma autorización para todos los paquetes Microsoft del motor (DXC,
Windows SDK, fuentes, etc.). Los ejemplos MinGW actuales no necesitan este
redistribuible, así que no hay motivo técnico para añadirlo ahora.

Fuentes oficiales:

- https://learn.microsoft.com/en-us/cpp/windows/redistributing-visual-cpp-files
- https://learn.microsoft.com/en-us/visualstudio/releases/2022/redistribution
- https://visualstudio.microsoft.com/license-terms/vs2022-cruntime/
- https://visualstudio.microsoft.com/license-terms/vs2022-ga-community/

## Licencia de Penguin y alcance de la aprobación

El proyecto existente es GPL-2.0-or-later. El uso concreto y la distribución
del usuario pueden ser no comerciales, pero eso no convierte la GPL en una
licencia no comercial. Los componentes propietarios deben conservar su
licencia separada; no se debe imponer su restricción al código GPL ni
presentar el paquete completo como software íntegramente abierto. La forma
de integración también debe respetar las obligaciones de las licencias
abiertas del motor.

Esta revisión concluye **elegibilidad condicional**, no inclusión automática.
Antes de incorporar un binario: contrastar la licencia que lo acompaña con
esta copia, confirmar versión/procedencia, preservar sus avisos y comprobar
que el alcance real del modo y de su distribución cumple las condiciones.
No se deben aceptar acuerdos ni adquirir derechos en nombre del usuario.

## Propuesta ante limitar los usos a no comerciales

La condición no comercial puede aplicarse al componente Apple dentro de
su licencia y a nuestra distribución concreta. Por sí sola no amplía su
ámbito de videojuegos a cualquier programa o tarea educativa.

No se propone cambiar la licencia global de Penguin a no comercial:
el código derivado de Dev-C++ debe respetar sus derechos GPL. Una licencia
que prohíba usos comerciales tampoco cumpliría la definición de open source
de OSI. Separar el componente y sus condiciones requiere mantener una
frontera real de integración; no basta renombrar el módulo.

Arquitectura recomendada: núcleo Penguin GPL; capa nativa SDL3/Metal abierta;
modo GPTK opcional y específico de videojuegos en Mac, distribuido con fines
no comerciales y con los textos Apple. No aplicar las restricciones de
GPTK al código GPL, ni presentar GPTK como abierto. La inclusión final aún
requiere comprobar el binario y su acuerdo real, así como la integración
con las demás licencias del motor.

Fuentes:
- Licencia GPL incluida en `LICENSE` del proyecto.
- Definición de open source, criterios 1 y 6: https://opensource.org/osd

## Evidencia local

Solo documentos de licencia se descargaron para esta revisión. Se conservan
en `build/license-audit/`, fuera de los archivos publicados:

| Documento | SHA-256 |
|---|---|
| GPTK 3.0 PDF | b099088947b67c1707de9b8e8f8dd5e03a4af8048451e455b9044553beeabcf8 |
| GPTK 4.0 PDF | c28ec4486b60c7d46071d72f9d10e44952aefb71d8163e304ae51503e1eecd39 |
| MSC 4.0b3 RTF | 20108dfe30663a2c6c717d9c5ca92486d9a4682c85c8ab344b20470feac8d0c3 |
| Runtime Microsoft DOCX oficial | f1e3d56ceb2ad68aae0711b910375009e651ac5530fa0760f0dea6e81e54fae1 |
| Community 2022 DOCX oficial | 41a207b10c8ab91d0d2f10a854715f73dca54509581692d2fe179aa3ffcb8540 |

Las copias de acuerdos Apple se obtuvieron de espejos de terceros. Se leyó
el texto Apple incluido; esto no autentica por sí mismo un binario ni concede
nuevos derechos sobre versiones con acuerdos diferentes. La descarga oficial
Apple encontrada requiere iniciar sesión; no se inició sesión ni se aceptó
ningún acuerdo durante esta revisión.

## Validación posterior del paquete macOS

Se añadió una revisión específica de FMOD, herramientas Apple y del `.pkg` en
`packaging/QA-pkg-macos.md`. La EULA oficial de FMOD Engine, sección 1.2,
excluye su distribución como parte de un motor o conjunto de herramientas,
incluso en la concesión no comercial: no incluirlo por simple atribución.
Fuente: https://www.fmod.com/legal .

El motor completo se descargó posteriormente para pruebas aisladas de consola;
la observación anterior de que solo se descargaron documentos corresponde a la
primera revisión documental. El motor no se añadió a ningún instalador publicado.
