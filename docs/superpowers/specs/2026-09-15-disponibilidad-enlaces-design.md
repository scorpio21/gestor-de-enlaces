# Diseño: Disponibilidad de enlaces — auto-escaneo, fecha de última comprobación e historial

Fecha: 2026-09-15
Proyecto: GestorAO (`K:\gestor-de-enlaces`)

## Problema

1. (#8) El escaneo solo se dispara manualmente con «Comprobar»; no hay escaneo automático al abrir el proyecto ni por intervalo.
2. (#9) La fecha de la última comprobación solo aparece en el tooltip de cada fila y la lista no se puede ordenar por ella.
3. (#10) Solo se conserva el último resultado por URL en `user://estados.json`; no hay historial de disponibilidad por enlace.

## Decisiones acordadas

- **Enfoque A (incremento sobre los stores existentes):** el historial vive como campo `historial` dentro de cada entrada de `user://estados.json`; no se toca `data.json` y no se crea ningún store nuevo.
- **Auto-escaneo con ambas opciones:** «Comprobar al abrir» (casilla) + intervalo configurable (Desactivado / 15 / 30 / 60 min). Se amortiguan con los valores actuales de paralelismo y timeout.
- **Auto-escaneo desactivado en headless** (`DisplayServer.get_name() == "headless"`): los tests CI nunca disparan red.
- **Fecha visible en cada fila** (label) + selector de orden «Sin ordenar / Más recientes / Más antiguos».
- **Historial capitulación 50 por URL**, consultable desde el menú contextual de la fila con un diálogo.
- **Regla anti-ruido:** no se registra una entrada de historial idéntica (mismo `valido`, `mensaje`, `codigo`) a la más reciente; el estado actual `fecha` sí se actualiza siempre.

## Arquitectura

### 1. `scripts/config_store.gd` — nuevos ajustes

- Constantes nuevas:
  - `AUTO_ABRIR_DEFAULT := true`
  - `INTERVALO_DEFAULT := 0` (minutos; 0 = desactivado)
- `cargar()` devuelve además `"auto_abrir": bool` y `"intervalo": int` con validación:
  - `auto_abrir`: `true` si el valor es booleano, si no el default.
  - `intervalo`: solo se aceptan los valores del selector `{0, 15, 30, 60}`; cualquier otro valor se sustituye por `INTERVALO_DEFAULT` (0).
- `guardar(paralelismo, timeout, auto_abrir, intervalo)` persiste los cuatro campos en `user://config.json`. La firma cambia: por compatibilidad con el código existente que usa `guardar(paralelismo, timeout)`, se añaden los dos parámetros con defaults al final (`auto_abrir := AUTO_ABRIR_DEFAULT`, `intervalo := INTERVALO_DEFAULT`).

Formato resultante de `user://config.json`:

```json
{ "paralelismo": 3, "timeout": 10.0, "auto_abrir": true, "intervalo": 0 }
```

### 2. `scripts/preferencias.gd` + `scenes/VentanaPreferencias.tscn`

- Casilla «Comprobar enlaces al abrir» (`%AutoAbrir`, CheckBox).
- Selector «Comprobar cada» (`%IntervaloAuto`, OptionButton) con items:
  - `Desactivado` → id 0
  - `Cada 15 minutos` → id 15
  - `Cada 30 minutos` → id 30
  - `Cada 1 hora` → id 60
- `abrir(paralelismo, timeout, auto_abrir, intervalo)` y `_on_guardar()` propagan los cuatro valores a `main.gd` vía la señal de guardado existente.

### 3. `scripts/estado_store.gd` — historial por URL

- `LIMITE_HISTORIAL := 50`.
- `guardar_estado(url, valido, mensaje, codigo)`:
  - Lee los estados actuales y la entrada de `url`.
  - Con la entrada previa `{valido, mensaje, codigo, fecha, historial?}`:
    - La **entrada nueva** lleva `historial` = lista de `{fecha, valido, mensaje, codigo}` (nuevos primero).
    - **Anti-ruido:** si la lista no está vacía y su primer elemento tiene el mismo `valido`, `mensaje` y `codigo` que el resultado actual, se conserva la lista sin añadir (la `fecha` del estado cabecera sí se actualiza). Si no, se inserta el resultado al principio y se trunca a `LIMITE_HISTORIAL`.
    - Entradas antiguas sin campo `historial` se tratan como `[]`.
  - Escribe el archivo; devuelve `bool`.
- `historial_de(url) -> Array`: devuelve la lista `historial` de la entrada de `url` (o `[]` si no existe / sin campo).
- `borrar_estado(url)`: sin cambios (borra la entrada completa, con su historial).

Formato de una entrada de `user://estados.json`:

```json
"<clave>": {
  "valido": false,
  "mensaje": "No existe (404)",
  "codigo": 404,
  "fecha": 1757059200,
  "historial": [
    { "fecha": 1757059200, "valido": false, "mensaje": "No existe (404)", "codigo": 404 },
    { "fecha": 1756972800, "valido": true, "mensaje": "OK (200)", "codigo": 200 }
  ]
}
```

### 4. `scripts/list_item.gd` + `scenes/ListItem.tscn`

- `%FechaLabel` (Label) a la derecha de la fila, siempre visible:
  - `fecha > 0` → `formatear_fecha(fecha)` («DD/MM/AAAA HH:MM»).
  - `fecha == 0` → «Sin comprobar».
- Nuevo item de menú contextual **«Historial…»** y señal `historial_pedido`. `mostrar_acciones` no cambia (no se oculta por estado); el item de historial se habilita siempre.

### 5. `scenes/Historial.tscn` + `scripts/historial.gd`

- `Window` con título «Historial de disponibilidad», patrón de `VentanaPreferencias` (ventana instanciada en `Main.tscn`).
- Contenido: `ScrollContainer` + `VBoxContainer` de filas (label fecha + label estado/mensaje), nuevas primero.
- API:
  - `abrir(entradas: Array) -> void`: rellena la lista y `popup_centered()`.
  - Lista vacía → muestra el texto «Sin historial».
- Cerrado por el usuario (botón cerrar / ventana), sin lógica de guardado.

### 6. `scripts/main.gd` + `scenes/Main.tscn`

- Selector de orden `%OrdenFecha` (OptionButton) junto a `FiltroEstado`/`FiltroCategoria`:
  - id 0 «Sin ordenar», id 1 «Más recientes», id 2 «Más antiguos».
- Ordenación estable con `sort_custom` aplicada en `_mostrar_lista`/filtrado:
  - «Más recientes»: `fecha` descendente; «sin comprobar» al final.
  - «Más antiguos»: `fecha` ascendente; «sin comprobar» al final.
  - «Sin ordenar»: orden de inserción actual.
- Nodo `Timer` `%AutoEscaneo` en `Main.tscn` (one-shot no: repite según intervalo; se para cuando `intervalo == 0`).
- `_aplicar_preferencias(paralelismo, timeout)` se amplía a `_aplicar_preferencias(paralelismo, timeout, auto_abrir, intervalo)`:
  - Si headless → no activa auto-escaneo (ni Timer ni escaneo inicial).
  - Si `auto_abrir` → programa el escaneo inicial con `call_deferred` tras `_ready` (0,5 s).
  - `intervalo > 0` → `timer.start(intervalo * 60.0)`; `intervalo == 0` → `timer.stop()`.
- `_on_auto_timer()`: si ya hay escaneo en curso (`_cola` no vacía o `_en_vuelo > 0`) no hace nada; si no, `_comprobar_visibles()` sobre lo visible (respeta el filtro activo). Al terminar, el Timer sigue su cadencia.
- `_on_historial_pedido(item)`: `%DialogoHistorial.abrir(_estado_store.historial_de(GestorCatalogoScript.clave_unica(item.url)))`.
- Al terminar comprobaciones (`_on_item_terminado`/`_persistir_recompra`) la `fecha`/`historial` actualizados y `_aplicar_filtro()` re-ejecuta el orden vigente.

## Flujo de datos

`verificar()` (manual / auto / re-comprobar) → `verificacion_terminada` → `_on_item_terminado`/`_persistir_recompra` → `guardar_estado` (append + anti-ruido + cap 50) → memoria `_estados[clave]` → `_aplicar_filtro()` (reordena si hay orden activo) → `_actualizar_status()`.

Diálogo de historial: `historial_pedido` → `historial_de(clave)` (disco fresco) → `abrir(entradas)`.

## Escenarios y errores

- **Escaneo en curso y llega el tick del Timer:** se ignora; el Timer mantiene su cadencia.
- **`intervalo_auto == 0`:** Timer detenido; solo cuenta el escaneo inicial (si `auto_abrir`).
- **Headless / CI:** auto-escaneo totalmente desactivado; los tests de configuración verifican el re-arme del Timer sin depender de ticks reales.
- **`estados.json` de versiones antiguas sin `historial`:** compatible; se trata como `[]` y el campo se añade en la siguiente comprobación.
- **Entradas idénticas consecutivas:** no saturan el historial (anti-ruido); la `fecha` de cabecera se actualiza igualmente.
- **Escritura fallida de `estados.json`:** best-effort como ya hace el código; la memoria queda actualizada y el siguiente guardado reintenta.

## Pruebas (batería TDD)

- `test_config_store.gd`: defaults (auto_abrir true, intervalo 0), guardar/cargar redondo de los 4 campos, clamping de inválidos, no-regresión de paralelismo/timeout.
- `test_estado_store.gd`: historial se añade con fecha; nuevos primero; cap 50; anti-ruido (idéntica consecutiva no duplica pero actualiza fecha de cabecera); `historial_de` devuelve `[]` para URL desconocida y para entrada sin campo; `borrar_estado` limpia también el historial.
- `test_list_item.gd`: `%FechaLabel` formatea fecha si `fecha_nueva > 0` y muestra «Sin comprobar» si 0; el menú contextual emite `historial_pedido`.
- `test_main_barra.gd`: selector de orden reordena por fecha (desc/asc, sin comprobar al final, estable); `historial_pedido` abre `%DialogoHistorial` con filas; cambiar preferencias re-arma el Timer (intervalo 0 → detenido); el auto-escaneo no dispara red en headless.
- La batería total crece de 270 a ~300 checks. Smoke `Main.tscn --quit-after 90` exit 0 sin `SCRIPT ERROR`.

## Alcance

Dentro: configuración del auto-escaneo, fecha visible + ordenación por fecha, historial por URL con diálogo.
Fuera: informe de disponibilidad (#11), reanudar escaneo interrumpido (#13), más detectores de host (#12), orden manual (#6) y vistas de tabla (#17) — se mantienen para ciclos posteriores.