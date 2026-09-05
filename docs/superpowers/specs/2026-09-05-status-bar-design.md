# Spec — Barra de estado en Main

Fecha: 2026-09-05
Estado: aprobada

## Propósito

Añadir una barra de estado fija al pie de la ventana principal que muestre un
resumen del catálogo completo y la versión de la aplicación:

- Número de enlaces **rotos**.
- Número de enlaces **activos**.
- **Total** de enlaces.
- **Versión** de la app, alineada a la derecha del todo (primera versión: `0.0.1`).

## Alcance

Los contadores se calculan sobre **todo el catálogo** (entradas base + entradas
de usuario, excluyendo las borradas), independientemente del filtro de estado
activo o de la búsqueda. La barra es un resumen global, no de la lista visible.

No se modifica el comportamiento del label `Progreso` existente (textos de
comprobación y mensajes).

## Versión

- Añadir `config/version="0.0.1"` en la sección `[application]` de
  `project.godot`.
- `main.gd` lee ese valor con
  `ProjectSettings.get_setting("application/config/version", "0.0.1")` y lo
  muestra con el prefijo `v` (p. ej. `v0.0.1`). Esta es la única fuente de
  verdad para la versión mostrada.

## UI — Nodos en `scenes/Main.tscn`

Dentro de `ColumnaApp`, después del nodo `Margen` (que es el que expande), se
añade la barra:

```
ColumnaApp
├── MenuBar
├── Margen (size_flags_vertical = fill/expand)
└── BarraEstado (PanelContainer)              # recién añadido
    └── Box (HBoxContainer)                   # separación 12
        ├── Rotos     (Label, unique)         # text "Rotos: 0"
        ├── Activos   (Label, unique)         # text "Activos: 0"
        ├── Total     (Label, unique)         # text "Total: 0"
        ├── Empuje    (Control)               # size_flags_horizontal = expand
        └── Version   (Label, unique)         # text "v0.0.1"
```

`BarraEstado` es un `PanelContainer` fino fijo al pie (sin `size_flags_vertical`
de expandir) con relleno constante. Las etiquetas se referencian en `main.gd`
con `unique_name_in_owner` (`%Rotos`, `%Activos`, `%Total`, `%Version`).

## Lógica — `scripts/main.gd`

Nueva función `_actualizar_status() -> void`:

- `total = _entradas.size()`.
- `activos` = número de entradas cuyo estado en `_estados` tiene
  `valido == true`.
- `rotos` = número de entradas cuyo estado en `_estados` tiene
  `valido == false`.
- Escribir `Rotos: N`, `Activos: N`, `Total: N` en sus labels.
- Escribir `"v" + version` en `%Version`, cargando la versión una sola vez al
  inicio (caché en una constante).

Solo las entradas presentes en `_estados` (con `valido` `true` o `false`) se
consideran activas o rotas. Las entradas sin estado registrado (nunca
comprobadas) solo suman a `Total`.

### Puntos de actualización

`_actualizar_status()` se llama cuando cambian el catálogo o los estados:

1. Al final de `_ready()` (tras cargar datos y estados).
2. En `_on_enlace_guardado()` (después de añadir el enlace).
3. En `_confirmar_borrado()` (después de eliminar el enlace).
4. En `_on_item_terminado()` (al terminar cada verificación de un escaneo).
5. En `_persistir_recompra()` (al terminar una re-comprobación individual).

## Errores y casos límite

- Si `config/version` falta, el `get_setting` devuelve el fallback `"0.0.1"`.
  La barra nunca se queda sin versión.
- Si no hay estados cargados, `activos` y `rotos` son `0` y `Total` muestra el
  tamaño del catálogo.
- Eliminar un enlace resta de `Total` automáticamente (se recalcula de
  `_entradas.size()`).

## Testing

- Smoke headless: la escena `Main.tscn` abre sin errores y los labels de la
  barra muestran valores coherentes.
- El cálculo es trivial y vive en `main.gd` (escena); no se añaden tests GUT
  nuevos para esta funcionalidad.
- Los tests existentes (GUT + harness headless) deben seguir pasando.