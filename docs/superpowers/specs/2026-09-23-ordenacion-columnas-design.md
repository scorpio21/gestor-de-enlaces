# Ordenación por columnas y vista de tabla (#17) — Design

> Estado: aprobado por el usuario. Siguiente paso: plan de implementación (writing-plans).

## Objetivo

Permitir ordenar la lista de enlaces por **nombre**, **estado**, **fecha de comprobación** o **presencia de imagen**, en modo ascendente/descendente, desde cabeceras clicables colocadas sobre la vista de filas actual, con indicador visual de la columna activa. El selector `OrdenFecha` existente se elimina; su capacidad la hereda la cabecera de Fecha.

## Decisiones acordadas

- **Presentación**: cabeceras clicables sobre la vista de filas actual (no una segunda vista tipo Tree/ItemList).
- **Relación con el orden manual (#6)**: con una columna de orden activa, Subir/Bajar quedan deshabilitados (mismo comportamiento que el `OrdenFecha` actual). Al volver a "sin ordenar", se restaura el orden manual persistido. No se reordena físicamente `_entradas` al ordenar por columna.
- **Reemplazo de OrdenFecha**: se retira el OptionButton `OrdenFecha` de `BarraAcciones`; la cabecera de Fecha cubre "Más recientes"/"Más antiguos".
- **Persistencia**: el criterio (columna + dirección) se guarda en `config_store` junto a paralelismo/timeout/tema; se restaura al arrancar.

## Arquitectura

Sigue el patrón existente en `_aplicar_filtro()` (main.gd): ordena los hijos **visibles** de `lista` con `sort_custom`, sin tocar `_entradas`.

### scripts/main.gd

- Dos variables de estado:
  - `_orden_columna: String` — `""` (sin orden), `"nombre"`, `"estado"`, `"fecha"`, `"imagen"`.
  - `_orden_direccion: int` — `1` (ascendente) o `-1` (descendente).
- En `_ready()`: tras cargar config, aplicar `_orden_columna`/`_orden_direccion` (validados por config_store) sobre las cabeceras y llamar `_aplicar_filtro()`.
- Crear 4 cabeceras (Button con `toggle_mode`) en una fila `HBoxContainer` sobre `%ListaContenedor`, con textos: `Nombre`, `Estado`, `Fecha`, `Imagen`. La columna activa muestra su texto con flecha (`Nombre ▲` / `↓`).
- Al pulsar una cabecera:
  - Otra columna → fijar criterio y dirección por defecto (`nombre`/`imagen` asc, `estado`/`fecha` desc).
  - Misma columna → invertir `_orden_direccion`.
  - Actualizar toggles, llamar `_aplicar_filtro()` y `_config_store.guardar(...)` con los valores actuales; si el guard falla, revertir criterio y avisar en `progreso` ("No se pudo guardar el orden.").
- Generalizar `_comparar_orden(a, b, modo)` a `_comparar_orden(a, b)` que usa `_orden_columna`/`_orden_direccion`:
  - **nombre**: alfabético sobre `nombre`, fallback a `url`.
  - **estado**: orden fijo `null` (sin comprobar) → `true` (válidos) → `false` (caídos); dentro del mismo estado, fallback a `url`.
  - **fecha**: igual que hoy (`0` = sin comprobar al final); empates → `url`. Desc = más recientes primero.
  - **imagen**: presencia de `img` no vacía; con imagen primero en asc.
- En `_aplicar_filtro()`: si `_orden_columna != ""`, ordenar los hijos visibles con `sort_custom` y `move_child(hijo, -1)` (patrón actual, main.gd:868-875).
- En `_on_menu_solicitado` y `_on_mover_pedido`: sustituir el guard `orden_fecha.get_selected_id() > 0` por `_orden_columna != ""`.

### scripts/config_store.gd

- Constantes:
  - `ORDEN_COLUMNAS_VALIDAS := ["", "nombre", "estado", "fecha", "imagen"]`
  - `ORDEN_DIRECCION_DEFAULT := 1`
- Nuevos campos en `cargar()` y `guardar()`:
  - `orden_columna`: string validado contra `ORDEN_COLUMNAS_VALIDAS` (invalida → `""`).
  - `orden_direccion`: entero clampado a `{-1, 1}` (invalida → `1`).
- `guardar(...)` amplía su firma con los dos parámetros por defecto; los llamadores existentes siguen funcionando (patrón `ultima_version_vista`).

### scenes/Main.tscn

- Se elimina el OptionButton `OrdenFecha` de `ColumnaApp/Margen/Columna/BarraAcciones`.
- Se inserta una fila de cabeceras (`HBoxContainer`) entre `BarraAcciones` y `%ScrollContainer` con los 4 botones.

## Flujo de datos

Ver sección "Persistencia" de decisiones y el diseño de `_ready()`/pulsación anterior.

## Pruebas (TDD)

- **test_config_store.gd**: `cargar()`/`guardar()` validan `orden_columna` (rechaza strings no válidos, por defecto `""`) y `orden_direccion` (clampa a ±1, por defecto `1`); round-trip de valores válidos en base temp.
- **test_main_barra.gd**:
  - Nombre asc/desc reordena filas visibles; fallback a url en empates de nombre.
  - Estado: sin comprobar → válidos → caídos.
  - Fecha: sin comprobar al final; desc = más recientes primero (equivalente al OrdenFecha actual).
  - Imagen: con imagen antes que sin (asc).
  - Pulsar la misma cabecera dos veces invierte la dirección.
  - Volver a sin orden (`""`) → vuelve a aplicarse el orden manual (#6).
  - Con columna activa, `_on_mover_pedido` no modifica `_entradas` (guard) y `_on_menu_solicitado` deshabilita ambas opciones Subir/Bajar.
  - El criterio elegido queda persistido en `config_store.cargar()` y se restaura en otro arranque con base temp (patrón de Task 3 del plan #6).
  - Todo mediante helpers `_filas_visibles()`, `_indice_entrada()`, cabeceras vía nodos de Main.

## Manejo de errores

- Guardar configuración falla → revertir criterio y `progreso.text = "No se pudo guardar el orden."`.
- Datos ausentes en entradas → defaults por criterio (url si falta nombre, 0 si falta fecha, sin imagen si falta img).

## Alcance

Solo esta feature. No incluye: internacionalización (#30), nueva vista tipo tabla con columnas físicas (descartada), persistencia física de `_entradas` por columna (descartada).