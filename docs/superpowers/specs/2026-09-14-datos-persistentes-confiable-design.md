# Spec: Datos persistentes confiables — #23 (escritura atómica) + #24 (esquema versionado)

Fecha: 2026-09-14
Estado: aprobado en diseño (brainstorming)

## Contexto

- **#23:** el catálogo se escribe con `FileAccess.open(path, WRITE)` directo (no atómico). Si la app
  se cierra a mitad de escritura, `data.json` queda corrupto (vacío o truncado). Pide escritura
  atómica (`data.json.tmp` → `data.json.bak` → `data.json`) y un botón «Restaurar copia» que importe
  la copia de seguridad.
- **#24:** el catálogo en disco no lleva versión de esquema. Pide `schema_version` (int) en
  `data.json` y `user://enlaces.json`, y comprobar la versión en `_ready()` de `main.gd`.
- Estado actual del código (`scripts/main.gd`): `DATA_RES := "res://data/data.json"` (línea 4),
  `DATA_USER := "user://enlaces.json"` (línea 5). `_cargar_datos()` (215) usa `_leer_array` (272),
  que parsea un **array plano** de nivel superior. `_guardar_datos()` (284) escribe ese mismo array
  plano vía `_escribir_archivo` (295) a ambos archivos (USER primero, RES después; si USER falla
  corta con mensaje, si RES falla se ignora). `_leer_array` se usa también en la línea 172 (conteo
  de capturas para la limpieza de huérfanas).
- `scripts/gestor_archivo.gd` exporta/importa un array plano como **formato de intercambio**
  (Importar/Exportar, #3). Es independiente de la persistencia interna y **no cambia**.

## Objetivos

1. Nunca dejar el catálogo corrupto ante una escritura interrumpida.
2. Versionar el formato en disco para permitir migraciones futuras.
3. Permitir recuperar el último catálogo bueno con «Restaurar copia».
4. Lectura 100 % compatible con el formato actual (v0 = array plano): migra de forma transparente.

## Decisiones de diseño

- **Formato v1** en disco (ambos archivos): objeto JSON
  `{"schema_version": 1, "enlaces": [ {...entrada...}, ... ]}`. Las entradas conservan los campos
  actuales (`nombre`, `desc`, `url`, `img`, `cat`).
- **v0** (array plano actual): al cargar, `cargar()` lo envuelve en v1 en memoria y **reescribe el
  archivo a v1 en el acto** (por archivo, independiente).
- **Escritura atómica** por archivo en `guardar(ruta, enlaces)`:
  1. Escribir el JSON v1 a `<ruta>.tmp`.
  2. Si existe `<ruta>`: borrar `<ruta>.bak` si existe y renombrar `<ruta>` → `<ruta>.bak`.
  3. Renombrar `<ruta>.tmp` → `<ruta>`.
  - En Windows `rename` no sobreescribe, por eso el `.bak` se borra antes de rotar.
  - Si el paso 1 falla: borrar el `.tmp` si existe y devolver `false`; el `<ruta>` previo queda
    intacto (no se borra nada hasta que el nuevo contenido está escrito en `.tmp`).
- **Nuevo módulo** `scripts/gestor_datos.gd` (`extends RefCounted`, API estática, sin `class_name`,
  español, tabs). API:
  - `const SCHEMA_ACTUAL := 1`
  - `static func version_de(ruta: String) -> int` → `-1` inexistente/no válido; `0` array plano (v0); `1` = `SCHEMA_ACTUAL`; otro positivo = esquema futuro.
  - `static func cargar(ruta: String) -> Array` → entradas. Faltante/no válido → `[]` (sin
    sobreescritura); v0 → migra y reescribe en v1 y devuelve las entradas; v1 → devuelve `enlaces`;
    dict con `schema_version != SCHEMA_ACTUAL` (futuro) → `[]` sin tocar el archivo.
  - `static func guardar(ruta: String, enlaces: Array) -> bool` → escribe v1 atómicamente.
  - `static func hay_copia(ruta: String) -> bool` → `FileAccess.file_exists(ruta + ".bak")`.
  - `static func restaurar_copia(ruta: String) -> bool` → lee `<ruta>.bak` y lo escribe en `<ruta>`
    con la misma rutina atómica; `false` si no hay copia.
  - Renombrados vía `DirAccess.rename_absolute` (con rutas absolutizadas con
    `ProjectSettings.globalize_path`) — `FileAccess` no renombra.
- **Integración en `main.gd`:**
  - `_cargar_datos()`: `base = GestorDatosScript.cargar(DATA_RES)`,
    `usuario = GestorDatosScript.cargar(DATA_USER)`; el merge y el resto quedan igual.
  - `_guardar_datos()`: `if not GestorDatosScript.guardar(DATA_USER, _entradas)` → mensaje y
    `false`; después `GestorDatosScript.guardar(DATA_RES, _entradas)` (el resultado de RES se
    ignora, como hoy).
  - Línea 172: sustituir `_leer_array(...)` por `GestorDatosScript.cargar(...)`.
  - Eliminar `_leer_array` y `_escribir_archivo` (quedan sin uso).
  - La comprobación de versión de #24 la hace `cargar()` internamente (v0 → migra y reescribe a v1;
    esquema futuro → no toca). No hace falta lógica adicional en `_ready`.
- **UI: «Restaurar copia…»** (decisión del usuario: en el **menú Archivo**):
  - `_configurar_menus()`: en `%File`, antes de «Salir» y tras el separador:
    `menu_file.add_item("Restaurar copia…", 4)`.
  - `_on_file_id(id)`: `4` → `_on_restaurar_copia()`.
  - `_on_restaurar_copia()`:
    - Si `GestorDatosScript.hay_copia(DATA_USER)` **o** `GestorDatosScript.hay_copia(DATA_RES)` →
      mostrar `%ConfirmarRestaurar` (`popup_centered()`) con texto «¿Restaurar el catálogo desde la
      copia de seguridad?».
    - Si no hay ninguna copia → `progreso.text = "No hay copia de seguridad disponible."` (sin
      diálogo).
  - `_confirmar_restaurar()` (conectada al `confirmed`): restaura `DATA_USER` y `DATA_RES` con
    `restaurar_copia`, recarga con `_cargar_datos()`, `_refrescar_vista()`, `_actualizar_status()` y
    `progreso.text = "Catálogo restaurado desde la copia."` (si alguna restauración falla, informa
    «No se pudo restaurar la copia.»).
  - Nodo nuevo en `scenes/Main.tscn`: `%ConfirmarRestaurar` (ConfirmationDialog, oculto por
    defecto).
- **`gestor_archivo.gd` queda igual** (formato de intercambio plano).

## Escritura en `res://`

El proyecto ya escribe hoy `res://data/data.json` en cada guardado (comportamiento actual en
editor). Se mantiene tal cual: `guardar()` fallará en un exportado real (solo lectura) con `false`,
que hoy también se ignora para RES. No se cambia este comportamiento.

## Mensajes al usuario

- Guardado fallido (USER): «No se pudo guardar el enlace.» (ya existente).
- Restaurar sin copia: «No hay copia de seguridad disponible.»
- Restaurar con copia, confirmado y ok: «Catálogo restaurado desde la copia.»
- Restaurar con copia, confirmado y fallo de escritura: «No se pudo restaurar la copia.»

## Testing

- **Nuevo `tests/test_gestor_datos.gd`** (~12 checks, hermético, rutas bajo `user://` de test y
  limpieza al final):
  1. `version_de` de archivo v1 → 1.
  2. `version_de` de archivo v0 (array plano) → 0.
  3. `version_de` de archivo inexistente/inválido → -1.
  4. `cargar` de v0 migra a v1 (reescribe en disco) y devuelve las entradas.
  5. `cargar` de v1 devuelve `enlaces`.
  6. `cargar` inexistente/corrupto → `[]` y no toca el archivo.
  7. `cargar` de esquema futuro (dict con `schema_version=2`) → `[]` sin tocar.
  8. `guardar` crea v1 correcto (`schema_version` y `enlaces`).
  9. `guardar` atómico: no deja `<ruta>.tmp` y rota `.bak` con el contenido previo.
  10. `guardar` en directorio inexistente → `false` (y no corrompe nada).
  11. `hay_copia` true tras dos guardados / false sin copia.
  12. `restaurar_copia` recupera el contenido del `.bak`; sin copia → `false`.
- **`tests/test_main_barra.gd`** (bloque del menú Importar/Exportar, +2 checks):
  - El menú `%File` contiene «Restaurar copia…» (id 4).
  - Flujo condicional hermético: con la misma condición que `_on_restaurar_copia` (`hay_copia(DATA_USER)` **o** `hay_copia(DATA_RES)`), si existe copia `_on_file_id(4)` muestra `%ConfirmarRestaurar`; si no, `_on_file_id(4)` deja el mensaje «No hay copia de seguridad disponible.». El test nunca
    confirma el diálogo ni toca datos reales (la confirmación solo existe por método conectado a
    `%ConfirmarRestaurar.confirmed`, que no se emite). La lógica de restauración se cubre de forma
    determinista en `test_gestor_datos`.
- **Recuento esperado:** 12 suites, ~262 checks (248 actuales + ~14). La cifra exacta la fija el
  plan/Battery.

## Fuera de alcance

- Backups de más profundidad (varias generaciones).
- Migración de esquemas futuros (se deja el gancho: número de versión + no tocar lo desconocido).
- Auto-restaurar la copia al arranque si el principal está corrupto.
- Cambios en `gestor_archivo.gd` (import/export).
- Modalidad/`transient` de las ventanas nativas (bug del arranque, ya resuelto aparte).