# Internacionalización ES/EN (#30) — Design Doc

**Fecha:** 2026-09-23
**Issues:** #30 (implementación), cierre al terminar. Extras: README actualizado + `CHANGELOG.md` nuevo.
**Stack:** Godot 4.7.2 / GDScript. Tests SceneTree (`--headless --script`).

## Goal

Internacionalizar la UI de GestorAO: soporte **español** (actual) + **inglés**, seleccionable desde la ventana Preferencias con banderas SVG, persistido en `config_store`, con autodetección del idioma del SO en el primer arranque. Al terminar la implementación se actualiza el `README.md` y se crea `CHANGELOG.md` con el histórico completo de cambios por día.

## Contexto y restricciones

- El proyecto no tiene aún carpeta `locale/` ni configuración de traducciones en `project.godot` — se parte de cero salvo el `tr()` del motor.
- `project.godot` tiene trabajo ajeno sin commitear → cualquier edición se hace con **staging selectivo** (técnica probada en #17: `git archive` + `hash-object` + `update-index`).
- Convenciones del repo: sin comentarios en scripts, tabs, UI en español, preload-const, tests con bases `user://__test_*__` que se limpian.
- Batería actual: 21 suites; `run_battery.sh` recorre `test_*.gd`, su lógica no cambia.
- Al terminar un issue: cerrarlo en GitHub (`gh issue close N --comment "resumen + commits"`).

## Decisiones (del brainstorming)

### D1 — Mecanismo: traducción nativa de Godot vía CSV
- Nuevo fichero `res://locale/gestor_es_en.csv` con el formato nativo: cabecera `keys,es,en`. La columna `keys` es la cadena **tal como aparece hoy en español** (así el auto-translate y `tr()` encajan sin renombrar nada).
- Registro en `project.godot`, sección `[internationalization]`: `locale/translations=PackedStringArray("res://locale/gestor_es_en.csv")`. Godot genera un `Translation` por columna (es, en) y asigna default por la locale del SO.
- Aplicar idioma en runtime: `TranslationServer.set_locale("es"|"en")`. El `auto_translate_mode` por defecto de los Controls re-traduce automáticamente `text`, `tooltip_text` y `title` (ventanas) de toda la UI al cambiar de locale — sin recorrer la escena a mano.
- Cadenas de runtime (mensajes de barra de progreso, entradas de menús/contexto, títulos de diálogos construidos por código) se envuelven en `tr(...)` explícito solo donde el auto-translate no cubra; un test de cobertura lo pinza.
- Fallback nativo de región: Godot cae a la columna más cercana (`pt-BR` → `pt` → `en`); una cadena sin traducción muestra la clave (texto en español). **Por diseño la UI nunca se rompe**, como mucho una cadena aparece sin traducir (y el test de integridad impide commitear celdas vacías).
- Idiomas futuros = añadir una columna al CSV (o un segundo CSV), sin tocar código.

### D2 — Banderas SVG propias
- `res://Assets/icon/flag_es.svg` y `flag_gb.svg`, generadas por el script existente `scripts/generar_iconos.gd` (misma fuente única y regenerable; `test_iconos.gd` se adapta).
- El `OptionButton` de idioma usa `add_icon_item(load(...), texto, id)`. Si el SVG no cargara, se muestra solo el texto (degradación sin bloqueo).
- Etiquetas **autónimas** ("Español", "English") en nombre nativo — no se traducen; así el selector funciona en cualquier idioma.

### D3 — Selector en Preferencias + persistencia + autodetección
- Ventana Preferencias: nuevo desplegable "Idioma" junto a "Tema". La señal `aplicado` gana un arg `idioma: String`.
- `config_store.guardar(...)` gana `idioma` como último arg opcional (default `""`); `cargar()` devuelve `idioma` validado contra `IDIOMAS_VALIDOS := ["", "es", "en"]` normalizando cualquier valor desconocido (p.ej. `"fr"` de una versión futura) a `""` (patrón `_orden_columna_ok` del #17).
- En `_ready()` de `main.gd`, antes de construir la UI principal:
  1. `cfg = cargar()`.
  2. Si `idioma == ""` → autodetección: normalizar `OS.get_locale()` a los 2 primeros caracteres en minúscula; si es `"en"` → inglés, cualquier otra cosa → español.
  3. `TranslationServer.set_locale(idioma)`.
- Al guardar en Preferencias: `aplicado` emite el idioma nuevo; `main.gd` aplica `set_locale` y la UI visible se re-traduce al instante (ventana abierta incluida, por `NOTIFICATION_TRANSLATION_CHANGED`), sin reconstruir la escena.
- **Rollback**: si `guardar()` falla al persistir el idioma, se revierte a la preferencia previa y se informa en la barra de progreso (patrón #17).

### D4 — Alcance de las cadenas
- **Entran** en `locale/` todas las cadenas visibles: `text`/`title`/`placeholder_text`/`tooltip` de las 5 escenas (`Main`, `Preferencias`, `AgregarEnlace`, `ListItem`, `Historial`) y las cadenas runtime (barra de progreso, menús, contexto de fila, diálogos construidos por código). Estimación: ~150 claves.
- **No entran** (acordado): `tests/`, logs, informes exportados (CSV/HTML), e identificadores internos (rutas, claves de `config_store`, esquema de datos).
- Las escenas **no se editan**: el auto-translate las cubre tal cual. El único cambio de código en la UI es `tr(...)` para runtime y el thread de idioma (D3).

### D5 — Testing (nueva suite `tests/test_locale.gd`)
1. **Integridad del CSV**: cabecera exacta `keys,es,en`, claves únicas, sin celdas vacías.
2. **Cobertura de escenas**: el test escanea `res://scenes/*.tscn` y verifica que todo atributo visible (`text=`, `title=`, `placeholder_text=`) exista como clave en el CSV (añadir una etiqueta sin traducir rompe el test).
3. **Cobertura runtime**: manifiesto explícito con los mensajes de barra/menús/diálogos de `main.gd` y otros scripts, verificado contra el CSV.
4. **Conmutación funcional**: `set_locale("en")` sobre la escena principal y comprobación de un título de ventana/menú representativo en inglés (pinza que el registro y el auto-translate funcionan de verdad).
- Suites existentes tocadas: `test_config_store.gd` (guardar/cargar valida `idioma`), `test_preferencias.gd` (OptionButton + señal con idioma), `test_iconos.gd` (generación de banderas), `test_main_barra.gd` (aplicar idioma en `_ready` con autodetección).
- Headless: base de config `user://__test_locale__`; cada test fuerza `set_locale("es")` al empezar y restaura/limpia al final para no contaminar otras suites.

### D6 — Entregables finales: README y CHANGELOG
- **`README.md` actualizado** (al final de la implementación, tras batería verde):
  - Características: internacionalización ES/EN (#30) y ordenación por columnas (#17) que hoy faltan en la lista.
  - Batería: corregir el conteo de suites ("17 suites" → **22 suites**) en todas sus ocurrencias (secciones Batería y Estructura del proyecto).
  - Estructura del proyecto: añadir `locale/` y `CHANGELOG.md`.
  - Roadmap: marcar #17 y #30 como hechos.
- **`CHANGELOG.md` nuevo** (mismo commit final), formato Keep a Changelog, agrupado **por día** con las mejoras de TODO el histórico del proyecto (11 días, 168 commits a 2026-09-23 más los del #30). Generación: `git log --date=short --pretty=format:"%ad|%s"` agrupado por fecha, mapeado a los issues (`gh issue list`), redactado en español, sección "Sin publicar" hasta el cierre.

## Arquitectura

| Fichero | Tipo | Rol |
|---|---|---|
| `res://locale/gestor_es_en.csv` | nuevo | Tabla de traducción `keys,es,en` |
| `project.godot` | modificar | `[internationalization] locale/translations` (staging selectivo) |
| `scripts/config_store.gd` | modificar | Constantes `IDIOMAS_VALIDOS`/`IDIOMA_DEFAULT`, `cargar()`/`guardar()` con `idioma` |
| `scripts/preferencias.gd` | modificar | OptionButton Idioma + banderas, señal `aplicado(..., idioma)` |
| `scenes/Preferencias.tscn` | modificar | Nodo `%Idioma` + etiqueta |
| `scripts/main.gd` | modificar | Autodetección + `set_locale` en `_ready`, aplicar idioma al guardar, rollback, `tr()` de runtime |
| `scripts/generar_iconos.gd` | modificar | Emite `flag_es.svg`/`flag_gb.svg` |
| `Assets/icon/` | nuevo | `flag_es.svg`/`flag_gb.svg` + `.import` |
| `tests/test_locale.gd` | nuevo | Suite de i18n (D5) |
| `tests/test_config_store.gd` | modificar | Checks de `idioma` |
| `tests/test_preferencias.gd` | modificar | OptionButton Idioma + señal |
| `tests/test_iconos.gd` | modificar | Banderas generadas |
| `tests/test_main_barra.gd` | modificar | Idioma aplicado en `_ready` |
| `README.md` / `CHANGELOG.md` | modificar/nuevo | Entregables finales (D6) |

## Flujo de datos

```
Preferencias (%Idioma)
  → aplicado.emit(..., idioma)
  → main._on_aplicar_preferencias: TranslationServer.set_locale(idioma)
  → config_store.guardar(..., idioma)            [rollback si falla]
  → NOTIFICATION_TRANSLATION_CHANGED → UI auto-re-traducida

Arranque (main._ready)
  cfg = config_store.cargar()
  idioma = cfg.idioma if != "" else autodetección(OS.get_locale())
  TranslationServer.set_locale(idioma)
  → escena principal construida ya en el idioma correcto
```

## Manejo de errores

- Config con idioma desconocido → normaliza a `""` → autodetección.
- Guardar fallido → rollback a idioma previo + aviso en barra de progreso.
- SVG de bandera no carga → opción sin icono (solo texto).
- Cadena sin traducir / CSV corrupto → muestra la clave (ES) + test de integridad falla (imposible commitear).
- `OS.get_locale()` inesperado (vacío/`C`) → español.

## Alcance / fuera de alcance

**Fuera de alcance:** traducción de tests, logs, informes exportados, identificadores internos; idiomas adicionales a EN (la arquitectura lo permite sin código); traducción de nombres de los idiomas en el selector (autónimas por diseño).

## Plan de implementación

El plan (skill writing-plans) tendrá ~6 tareas en orden TDD (RED→GREEN→commit por tarea):
1. CSV + registro en `project.godot` + tests de integridad.
2. Extracción de cadenas escena + runtime y completar el CSV EN.
3. Banderas en `generar_iconos.gd` + `test_iconos.gd`.
4. `config_store` con `idioma` + `test_config_store.gd`.
5. Selector en Preferencias + señal + `main.gd` (autodetección, aplicar, rollback, `tr()` runtime) + suites afectadas.
6. Batería completa (22 suites) + boot headless + README + `CHANGELOG.md` + checkboxes del plan + cierre del issue #30 en GitHub.