# Spec: Cambiar o quitar la captura de un enlace existente (#20)

**Fecha:** 2026-09-13
**Issue:** scorpio21/gestor-de-enlaces#20 — [Imágenes] Cambiar o quitar la captura de un enlace existente

## Objetivo

Permitir cambiar o eliminar la captura de imagen de un enlace ya existente sin perder el
resto de sus datos, actualizando el registro `img` en `data.json` y **borrando el fichero
viejo** de `Assets/png/` cuando corresponde.

## Contexto (estado actual)

La edición de enlaces ya existe (plan `2026-09-06-catalogo-anadir-editar`, issues #1/#2/#4).
El diálogo `AgregarEnlace` tiene modo editar con precarga de imagen (`%BotonElegir`,
`%BotonQuitar`) y `main._on_enlace_editado()` persiste `entrada["img"]`. Lo que queda para
cumplir #20:

1. Al cambiar o quitar la captura no se borra el fichero viejo de `Assets/png/`.
2. La copia de la imagen nueva ocurre en el diálogo **antes** del chequeo de colisión de
   URL: una edición rechazada deja un `img_*.png` huérfano en `Assets/png/` y, al reabrir el
   diálogo, la imagen mostrada se pierde.

## Enfoque

Mover las operaciones de archivo de imagen del diálogo a `main`. El diálogo pasa a ser un
formulario puro (sin I/O): reporta la intención (`imagen igual` / `nueva imagen` / `quitar`)
y `main` decide copiar/borrar **después** del chequeo de colisión y junto a la persistencia.

## Alcance

Dentro de #20:

- Cambiar la captura de un enlace existente (seleccionar otra imagen).
- Quitar la captura de un enlace existente.
- Borrar el fichero viejo de `Assets/png/` tras guardar, con guarda de captura compartida y
  de convención de nombres.
- Reabrir por colisión de URL mostrando la imagen original.

Fuera de alcance («para #21»):

- Limpieza general de capturas huérfanas (`Assets/png/`).
- El huérfano que pueda dejar el camino de **alta individual duplicada** (`guardado` sigue
  copiando en el diálogo como hoy).
- Redimensionado/optimización de capturas al copiar (#22).

## Comportamiento detallado

### Diálogo `agregar_enlace.gd` — modo editar

- La señal `editado(datos, url_original)` no cambia de firma.
- Nuevo campo optativo en `datos`: `img_pendiente` (String) = ruta **fuente** de la imagen
  nueva elegida con `%BotonElegir`.
- Al guardar en modo editar, `datos["img"]` lleva:
  - sin cambios → la ruta original (`_imagen_original`),
  - quitar (`_quitar_imagen == true`) → `""`,
  - imagen nueva → `""` con `datos["img_pendiente"] = _imagen_ruta`.
- `_on_guardar` en modo editar **no** llama a `copiar()` (se elimina ese efecto de archivo).
- Se conserva `hide()` antes del `editado.emit(...)` (fix ya commiteado).

### `gestor_imagenes.gd`

Nuevo helper estático:

```gdscript
static func borrar(ruta: String) -> Dictionary
```

- `ruta` vacía → `{"ok": false, "error": "Ruta vacía."}`.
- Si no, `DirAccess.remove_absolute(ProjectSettings.globalize_path(ruta))`; `OK` →
  `{"ok": true, "error": ""}`, si no `{"ok": false, "error": "No se pudo borrar la captura."}`.

### `main.gd` — `_on_enlace_editado(datos, url_original)`

1. Buscar la entrada por `url_original`; si no existe → barra «No se encontró el enlace.»
   (comportamiento actual).
2. **Colisión de URL** (`url_nueva != url_original` y `_cambios_url_validos` false) →
   barra «Ya existe: <url>», `abrir_edicion` con `datos` donde `img` es la **imagen
   original** de la entrada, y `return`. Sin operaciones de archivo.
3. Renombrar URL en `_estados`/`_borrados` si cambió (comportamiento actual).
4. `img_anterior = str(entrada["img"])` antes de sobrescribir.
5. Resolver `destino`:
   - si `datos.has("img_pendiente")` → `gestor_imagenes.copiar(ruta_pendiente)`; si
     `not ok` → barra «No se pudo procesar la imagen.» y `return` **sin tocar la entrada**.
     Si ok → `destino = resultado.destino`.
   - si no → `destino = str(datos.get("img", ""))`.
6. `entrada["img"] = destino`; si `_guardar_datos()` falla → `_cargar_datos()` +
   `_refrescar_vista()` + barra «No se pudo guardar el enlace.» y `return` (la copia nueva,
   si existió, queda huérfana → la barre #21).
7. Si `destino != img_anterior` → `_borrar_captura_si_huerfana(img_anterior)`.
8. `_refrescar_vista()` + `_actualizar_status()` + barra «Enlace actualizado: <nombre>».

### Helper `_borrar_captura_si_huerfana(ruta: String)` en `main.gd`

Borra la captura **solo** cuando se cumplen TODAS:

- `ruta.begins_with("res://Assets/png/")` y el nombre del fichero empieza por `img_`
  (convención propia; rutas raras de datos viejos/importados se ignoran).
- Ninguna otra entrada de `_entradas` referencia la misma ruta (captura compartida se
  conserva: solo se desreferencia en el enlace editado).

Si procede → `gestor_imagenes.borrar(ruta)`.

### Reapertura por colisión

`main.gd:261` pasa de reabrir con el `datos` recibido a reabrir con `img` = imagen original
(merge: `datos` del usuario con `img` restaurado), de modo que la captura actual sigue
visible y el cambio de imagen queda descartado con la edición rechazada.

## Errores y casos borde

| Caso | Resultado |
|---|---|
| Nueva imagen pero `copiar()` falla | Barra «No se pudo procesar la imagen.»; ni se persiste ni se toca `img`. |
| Persistencia fallida tras copiar | Se recarga el estado; copia huérfana (la barre #21); mensaje de guardado fallido. |
| Captura compartida por otra entrada | No se borra; solo se desreferencia. |
| `img` fuera de la convención `res://Assets/png/img_*` | Nunca se borra. |
| Edición sin tocar imagen | `destino == img_anterior` → no se borra nada. |
| Colisión de URL con imagen nueva | Sin copia, sin huérfano, barra «Ya existe», diálogo reabierto con imagen original. |

## Pruebas

### `tests/test_gestor_imagenes.gd` (5 → 8 checks)

- `borrar()` borra un archivo real (creado por el test, bajo `user://`).
- `borrar()` no afecta a otros archivos.
- `borrar()` con ruta vacía devuelve `ok:false`.

### `tests/test_main_barra.gd` (34 → ~40 checks), vía real del diálogo

Los tests usan archivos temporales reales en `Assets/png` (escritura permitida en modo
editor) y los limpian al finalizar:

1. Editar con imagen nueva → `entrada.img` apunta a un `img_*.png` nuevo y el **archivo
   viejo ya no existe** en disco.
2. Editar quitando la imagen → `entrada.img == ""` y el archivo viejo ya no existe.
3. Editar sin tocar la imagen → archivo conservado y `img` intacto.
4. Colisión de URL con imagen nueva → no se crea ningún archivo nuevo; barra «Ya existe»; el
   diálogo reabierto muestra la imagen original.
5. Captura compartida por otra entrada → no se borra.
6. `copiar()` fallido (source inexistente) → barra de error, entrada intacta.

### Regresión

Batería completa (11 suites) al final; `tests/test_agregar_enlace.gd` inalterado (el camino
de alta no cambia).