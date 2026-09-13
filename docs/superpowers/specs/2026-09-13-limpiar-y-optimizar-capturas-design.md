# Spec: Limpiar huérfanas y optimizar capturas (#21 + #22)

**Fecha:** 2026-09-13
**Issues:** scorpio21/gestor-de-enlaces#21 — Limpiar capturas huérfanas en Assets/png · #22 — Redimensionar/optimizar capturas al copiarlas

## Objetivo

1. **#22** — Al copiar una captura (`gestor_imagenes.copiar`), reducirla a un ancho máximo de 800 px (solo si supera ese ancho; nunca ampliar) manteniendo la proporción y siempre en PNG, para no inflar `Assets/png/`.
2. **#21** — Barrer `Assets/png/` y eliminar los `img_*.png` que no estén referenciados por ningún enlace en `data.json`, `user://enlaces.json` ni en la lista viva `_entradas`. Se ejecuta al cerrar la app (`main._exit_tree`) y bajo demanda desde el menú `Utilidades`.

## Contexto (estado actual)

- `gestor_imagenes.copiar(origen)` copia sin redimensionar y devuelve `{"ok", "destino", "error"}`. Ya existe `limpiar...` no; existe `borrar(ruta)` (plan 2026-09-13-editar-captura, #20) con contrato `{"ok", "error"}`.
- `main.gd` ya tiene la guarda `_borrar_captura_si_huerfana(ruta)` (convención `res://Assets/png/img_*` + captura compartida) usada en la edición; se mantiene sin cambios.
- Los datos persisten como **arrays JSON planos** de entradas `{"nombre","desc","url","img"}` (`main._cargar_datos`/`_guardar_datos`; `_leer_array(path)` parsea y valida `TYPE_ARRAY`). `DATA_RES = res://data/data.json`, `DATA_USER = user://enlaces.json`.
- `main.gd` define el menú `%Utilidades` en `_configurar_menus()` con items «Agregar» (0) y «Preferencias…» (1), manejados por `_on_utilidades_id`. Para el borrado de enlaces ya existe `%ConfirmarBorrado` (AcceptDialog) conectado en `_ready`.
- Tests: `test_gestor_imagenes.gd` (8 checks) y `test_main_barra.gd` (47 checks), harness `SceneTree` + `_check`.

## Enfoque

Toda la lógica de archivos vive en `gestor_imagenes.gd` como funciones estáticas (test unitario limpio); `main.gd` solo orquesta disparadores (menú + cierre) y arma el conjunto de referencias. `copiar()` se mantiene como única ruta de creación de capturas, así #22 beneficia a alta individual, edición (#20) y lote por igual.

## Alcance

Dentro:

- Redimensionado a máx. 800 px de ancho, solo downscale, proporción conservada, PNG.
- `limpiar_huerfanas(referidas)` en `gestor_imagenes.gd`.
- Acción de menú `Utilidades > Limpiar capturas huérfanas…` con confirmación.
- Barrido automático en `main._exit_tree()`.
- Pruebas unitarias e integradas; regresión de batería.

Fuera de alcance:

- Guarda de captura compartida en `_confirmar_borrado` (queda anotado para #21-extra; no se toca aquí).
- Migrar/mover capturas entre carpetas, formatos distintos de PNG, o añadir preferencias de ancho configurable.
- Cualquier cambio al esquema de datos (eso es #5).

## Comportamiento detallado

### `gestor_imagenes.copiar(origen)` — #22

Tras `Image.load_from_file(origen)` y la validación existente (`img == null or img.is_empty()`), añadir:

```
ANCHO_MAX := 800
```

- Si `img.get_width() > ANCHO_MAX` → `var alto := maxi(1, int(float(img.get_height()) * ANCHO_MAX / float(img.get_width())))` y `img.resize(ANCHO_MAX, alto, Image.INTERPOLATE_CUBIC)`.
- Si `img.get_width() <= ANCHO_MAX` → sin cambios (nunca upscale).
- Guardado siempre `save_png` (PNG). Contrato de retorno idéntico (`ok`/`destino`/`error`), sin nuevas claves.

### `gestor_imagenes.limpiar_huerfanas(referidas: Array) -> Dictionary` — #21

- Abre `res://Assets/png` con `DirAccess.open`; si `null` → `{"ok": false, "borradas": 0, "errores": 0, "error": "No se pudo abrir la carpeta de imágenes."}`.
- Construye `referidas_str: Array` con `str(r)` de cada elemento de `referidas`.
- Recorre `carpeta.get_files()`:
  - Ignora los que no cumplan `f.begins_with("img_") and f.ends_with(".png")` (convención de #20; archivos ajenos a la app nunca se tocan).
  - Ruta candidata: `"res://Assets/png/%s" % f`.
  - Si la ruta está en `referidas_str` → conservar.
  - Si no → `borrar(ruta)`; si `ok` → `borradas += 1`, si no → `errores += 1`.
- Devuelve `{"ok": true, "borradas": int, "errores": int}`.

### `main.gd` — conjunto de referencias

`_rutas_captura_referidas() -> Array`:

- Iterar `res://data/data.json`, `user://enlaces.json` (via `_leer_array`, que ya devuelve `[]` si no existe) y `_entradas`; de cada `entrada` tipo Dictionary recoger `str(entrada.get("img", ""))` no vacía. Sin duplicar (dedupe por ruta).
- Justificación de incluir `_entradas`: protege ediciones aún no persistidas y permite a los tests sembrar referencias sin tocar los ficheros reales; en runtime es redundante (la lista viva es la unión de ambos ficheros).

### `main.gd` — acción de menú

- En `_configurar_menus()`, `%Utilidades` pasa a tener «Limpiar capturas huérfanas…» con id 2.
- En `_on_utilidades_id`, `2` → `_solicitar_limpieza_capturas()`.
- `_solicitar_limpieza_capturas()`: `var res := GestorImagenesScript.limpiar_huerfanas(_rutas_captura_referidas())`. Guarda `_limpieza_resultado = res`.
  - Si `res.get("ok")` y `int(res.get("borradas", 0)) == 0` → barra «No hay capturas huérfanas.».
  - Si `borradas > 0` → `%ConfirmarLimpieza.dialog_text = "¿Borrar %d capturas huérfanas?" % borradas`, `%ConfirmarLimpieza.popup_centered()`.
  - Si `not ok` → barra `str(res.get("error", "No se pudo limpiar las capturas."))`.
- Nuevo handler `_confirmar_limpieza()`: desde `_limpieza_resultado` (persistido entre confirmación) → si `ok` y `borradas > 0` → barra «Capturas huérfanas eliminadas: %d» % borradas; si `errores > 0` → adjuntar « (%d errores)» % errores. Resetea `_limpieza_resultado = {}`.
- `%ConfirmarLimpieza` es un `AcceptDialog` nuevo en `scenes/Main.tscn`, conectado en `_ready` (`%ConfirmarLimpieza.confirmed.connect(_confirmar_limpieza)`).

### `main.gd` — cierre automático

- Nuevo `func _exit_tree() -> void:` que llama a `_solicitar_limpieza_capturas()`? NO — el cierre no debe abrir diálogo. En su lugar ejecuta la limpieza directa: `GestorImagenesScript.limpiar_huerfanas(_rutas_captura_referidas())` con el resultado descartado (o volcado a `print` en modo headless no hace falta). Sin confirmación, sin barra (la escena ya no se ve). Con guarda: solo sobre `Assets/png` por las reglas internas de `limpiar_huerfanas` (no borra nada fuera de la convención ni referenciado).
  - Ajuste: `_solicitar_limpieza_capturas()` se separa en (a) `_hacer_limpieza_capturas() -> Dictionary` (calcula res) y (b) `_solicitar_limpieza_capturas()` que usa (a) para decidir barra/diálogo y guarda `_limpieza_resultado`. `_exit_tree()` llama solo a (a) e ignora el resultado. `_confirmar_limpieza()` usa `_limpieza_resultado`.

## Errores y casos borde

| Caso | Resultado |
|---|---|
| `copiar()` con imagen `> 800` px de ancho | PNG resultado con ancho `<= 800`, proporción aproximada conservada. |
| `copiar()` con imagen `<= 800` px | PNG con el tamaño original (sin upscale). |
| `copiar()` con imagen vacía/ilegible | Comportamiento actual (`ok: false`, destino `""`). |
| `limpiar_huerfanas` sin carpeta | `ok: false` con `error`, `borradas 0`. |
| Archivo `img_*.png` referenciado (en `data.json`, `user://` o `_entradas`) | Conservado. |
| Archivo `no-img_*` (p. ej. `no-disponible.png`, `slug.png`) | Nunca borrado (convención). |
| Archivo `img_*` no referenciado | Borrado; suma a `borradas`. |
| `borrar` individual falla | Suma a `errores`; el barrido continúa. |
| Menú con 0 huérfanas | Barra «No hay capturas huérfanas.»; sin diálogo. |
| Cierre de la app | Barrido automático sin diálogo (los test residuales `img_*` del harness también se limpian ahí). |

## Pruebas

### `tests/test_gestor_imagenes.gd` (8 → 13 checks)

1. `copiar` con origen de 1200×600 → destino PNG con `Image.get_width() <= 800` y `> 0`.
2. `copiar` con origen pequeño (4×4) → destino conserva ancho `4` (sin upscale).
3. `limpiar_huerfanas` con 2 `img_*` nuevos y solo 1 referida → `borradas == 1`, el otro archivo sigue existiendo en disco.
4. `limpiar_huerfanas` con todas las `img_*` referidas → `borradas == 0` y todos existen aún.
5. `limpiar_huerfanas` ignora un archivo sin prefijo `img_` en la carpeta (lo deja intacto).
6. `limpiar_huerfanas` devuelve `ok:true` con contadores enteros (`borradas`/`errores`).

Reglas de higiene: los tests crean/borran sus propios `img_test_*`/`img_*.png` en `Assets/png` (y un `user://__test_gestor_imagenes__` como ya hacen) y limpian tras cada bloque con `DirAccess.remove_absolute`.

### `tests/test_main_barra.gd` (47 → 53 checks)

Bloque «Catálogo: limpieza de capturas» con helpers ya presentes (`_crear_captura`, `_listar_capturas`, `_imgs_iniciales`/`_limpiar_capturas`) vía diálogo real y `main_script._persistir = false`:

7. Menú con 0 huérfanas → barra «No hay capturas huérfanas.» (ejecutar a través de `_on_utilidades_id(2)`).
8. Menú con 1 huérfana real (`img_test_*` creada, no referenciada) → `%ConfirmarLimpieza` visible y su `dialog_text` contiene «1».
9. Tras confirmar (`%ConfirmarLimpieza.confirmed.emit()`) → archivo ya no existe y barra «Capturas huérfanas eliminadas: 1».
10. Huérfana que SÍ está referenciada en `_entradas` → no se borra (barra «No hay capturas huérfanas.» tras menú).
11. `_exit_tree()` barre sin pedir confirmación: llamar `main_script._exit_tree()` con una huérfana real → archivo eliminado.

Regresión: batería completa (10 suites) con `TESTS OK`; `tests/test_main_barra.gd` deja `Assets/png` sin `img_*` nuevos no referenciados tras el bloque.

## Notas

- `limpiar_huerfanas` no se dispara por `borrar`/edición (#20) ni interfiere con `_borrar_captura_si_huerfana` (helper independiente).
- El barrido del harness en `_exit_tree` actúa de red de seguridad: cualquier `img_*` residual de los tests queda referenciado o se limpia.