# GestorAO

**Gestor de enlaces para Argentum Online** — aplicación de escritorio en Godot 4 para organizar y verificar la disponibilidad de enlaces de descarga (servidores, clientes y códigos fuente) de proyectos Argentum Online.

> Útil para mantener catálogos históricos de servidores/clients AO: evita enlaces rotos y permite comprobar rápidamente qué archivos siguen disponibles.

---

## Características

- 📚 **Listado por catálogo** — listado base en `data/data.json` + enlaces añadidos por el usuario guardados en `user://enlaces.json`.
- 🔎 **Buscador en vivo** — filtra por nombre y descripción mientras escribes.
- ✅ **Verificación de enlaces** — comprueba la disponibilidad HTTP de cada URL con hasta **3 verificaciones en paralelo**, gestionando redirecciones, timeouts y marcadores típicos de archivo eliminado (4shared, RapidShare…).
- 🎛️ **Filtros por estado** — Todos / Válidos / Caídos / Sin comprobar.
- ➕ **Añadir enlaces** — ventana con nombre, descripción, URL validada y **captura/imagen opcional** (gráfico o screenshot del juego).
- 🖼️ **Miniaturas** — cada fila muestra la captura (56 px) o el marcador `no-disponible` cuando no hay imagen.
- 💾 **Persistencia del escaneo** — los resultados se guardan en `user://estados.json`; no hace falta re-escanear al abrir.
- 🗑️ **Eliminación de enlaces caídos** — con confirmación, registra la URL eliminada (`user://borrados.json`) y borra también su captura de `Assets/png/`.
- 🔁 **Re-verificación individual** — botón *Volver a comprobar* en cada fila caída.
- 🖱️ **Apertura directa** — clic en un enlace lo abre en el navegador del sistema.
- 📊 **Progreso en tiempo real** — contador de verificaciones completadas.

---

## Requisitos

- **Godot 4.7.2** (motor usará *Forward Plus*, renderizado **D3D12** en Windows).

---

## Instalación y ejecución

```bash
git clone https://github.com/scorpio21/gestor-de-enlaces.git
cd gestor-de-enlaces
godot --path .          # abre el editor
godot -e                # importa y abre el editor con importación de recursos
```

O simplemente abre `project.godot` desde el propio editor de Godot 4.7.2.

La escena principal es `res://scenes/Main.tscn`.

---

## Uso

1. **Abrir la aplicación** — se carga el catálogo base (`data/data.json`), los enlaces de usuario (`user://enlaces.json`) y el estado del último escaneo (`user://estados.json`).
2. **Comprobar enlaces** — pulsa **Comprobar** para verificar todos los enlaces visibles (o los que el filtro deje ver). Los resultados se muestran en cada fila y quedan guardados:
   - 🟢 **Válido** — el archivo responde `200`-`3xx`.
   - 🔴 **Caído / no existe** — `404`/`410`, conexión fallida, dominio inexistente o marcador de archivo eliminado.
   - 🟡 **Sin comprobar** — pendiente de verificación.
3. **Filtrar** — usa el desplegable para ver solo válidos, caídos o sin comprobar.
4. **Buscar** — escribe en el campo de búsqueda para filtrar por nombre/descripción.
5. **Añadir** — menú *Utilidades → Agregar* (o atajo directo). La URL debe empezar por `http://` o `https://`; opcionalmente elige una **imagen/captura local** (png/jpg/webp) que se copia a `Assets/png/` y se muestra como miniatura al guardar.
6. **Abrir enlace** — clic sobre la fila del enlace.
7. **Re-verificar un caído** — botón *Volver a comprobar* en la fila.
8. **Eliminar un caído** — botón *Eliminar* (con confirmación); se registra la URL como eliminada y se borra su captura de `Assets/png/`.

---

## Almacenamiento de datos

| Ruta | Contenido |
|---|---|
| `res://data/data.json` | Catálogo base (solo lectura en builds exportados) |
| `user://enlaces.json` | Enlaces añadidos por el usuario |
| `user://estados.json` | Resultados del último escaneo por URL |
| `user://borrados.json` | URLs eliminadas definitivamente |
| `user://logs/` | Logs rotativos de aplicación (`app_*.log`) y de escaneo (`scan_*.log`) |
| `Assets/png/` | Capturas de imagen de los enlaces (carpeta versionada) |
| `data/data.json.bak` | Copia de seguridad local (no versionada) |

> `user://` equivale a la carpeta de datos del usuario del sistema según el sistema operativo.

---

## Registro de actividad y diagnóstico

- **Logger rotativo** — la aplicación escribe logs a `user://logs/` con rotación por tamaño; por un lado la actividad de la app y por otro los escaneos de enlaces. En *entornos de desarrollo* (sin exportar) el logger también vuelca a consola.
- **Exportar diagnóstico** — menú *Utilidades → Exportar diagnóstico…* genera un ZIP (fecha/hora en el nombre) con los logs, los datos (`data.json`, `enlaces.json`, `estados.json`, `borrados.json`) y un fichero `info.txt` con versión de la app, SO, motor y rutas, para reportar incidencias.

---

## Empaquetado y CI

- **Presets de exportación** (`export_presets.cfg`) — Windows (exe), Linux/X11 (x86_64) y macOS (`.app` universal). La escena principal y los iconos (SVG/PNG/ICO/ICNS) se generan con `scripts/generar_iconos.gd`.
- **GitHub Actions** (`.github/workflows/ci.yml`) — en cada push a `main`: descarga Godot 4.7.2 y las export templates (versión fija `4.7.2.stable`), importa el proyecto, ejecuta la batería de tests headless y exporta los 3 presets a `build/` (el `.app` de macOS se comprime a ZIP). Los artefactos quedan publicados en la página del run.
- **Batería de tests** — cada suite es `tests/test_<area>.gd` (extiende `SceneTree`; imprime `TESTS OK` y `quit(0)`). `tests/run_battery.sh` ejecuta las 17 suites en orden; local (Windows, pwsh):

  ```bash
  & "K:\Godot_v4.6.1\Godot_v4.7.2-stable_win64_console.exe" --headless --path "K:\gestor-de-enlaces" --script res://tests/test_<area>.gd
  ```

  En CI el checkout es fresco (no trae `.godot/`): antes de la batería se ejecuta `godot --headless --path . --import` para generar el cache de importación.

---

## Estructura del proyecto

```
gestor-de-enlaces/
├── project.godot            # Configuración del proyecto
├── export_presets.cfg       # Presets de exportación Windows/Linux/macOS
├── .github/workflows/ci.yml # CI: tests headless + export de los 3 bundles
├── scenes/
│   ├── Main.tscn            # Escena principal (UI completa)
│   ├── AgregarEnlace.tscn   # Ventana para añadir enlaces
│   └── ListItem.tscn        # Fila individual del listado
├── scripts/
│   ├── main.gd              # Lógica de la UI, carga/guardado y escaneo
│   ├── list_item.gd         # Fila: estado, verificación y apertura
│   ├── link_checker.gd      # Verificador HTTP (redirecciones, timeouts…)
│   ├── agregar_enlace.gd    # Formulario de nuevo enlace (+ captura)
│   ├── logger.gd            # Logs rotativos app/scan en user://logs
│   ├── diagnostico.gd       # Exporta ZIP de logs+datos con info.txt
│   ├── estado_store.gd      # Persistencia de estados y borrados (user://)
│   ├── gestor_catalogo.gd   # Catálogo base y enlaces de usuario
│   ├── gestor_datos.gd      # Carga/guardado JSON con backups
│   ├── gestor_contadores.gd # Contadores de la barra de estado
│   ├── config_store.gd      # Preferencias persistentes (user://)
│   ├── historial.gd         # Historial de escaneos del catálogo
│   ├── preferencias.gd      # Ventana de preferencias
│   ├── gestor_archivo.gd    # Selección y copia de capturas
│   ├── gestor_imagenes.gd   # Copia de capturas a Assets/png
│   └── generar_iconos.gd    # Regenera Assets/icon (svg/png/ico/icns)
├── tests/
│   ├── run_battery.sh       # Ejecuta las 17 suites headless (Linux/CI)
│   └── test_<area>.gd       # 17 suites SceneTree (TESTS OK / quit(0))
├── data/
│   └── data.json            # Catálogo base de enlaces
├── Assets/
│   └── icon/                # Iconos generados (svg/png/ico/icns)
└── docs/superpowers/        # Specs y planes de diseño
```

---

## Roadmap

- [x] Listado de enlaces, búsqueda y filtros por estado
- [x] Verificación HTTP en paralelo con detección de archivos eliminados
- [x] Alta de enlaces desde la interfaz
- [x] **Persistencia del estado de escaneo** (`user://estados.json`) — los resultados se guardan y no hace falta re-escanear al abrir
- [x] **Eliminación de enlaces caídos** con confirmación y control de URL eliminadas (`user://borrados.json`)
- [x] Re-verificación individual por enlace
- [x] **Captura/imagen por enlace** — al añadir se puede adjuntar una imagen local que se muestra como miniatura (o el marcador `no-disponible`)
- [x] **Logs rotativos y diagnóstico en ZIP** — logger app/scan en `user://logs/` + *Utilidades → Exportar diagnóstico…* (`#28`)
- [x] **Icono propio y metadatos 0.1.0** — Assets/icon (svg/png/ico/icns) generado por script (`#29`)
- [x] **Empaquetado y CI** — presets Windows/Linux/macOS + GitHub Actions que testea y exporta los 3 bundles (#26)

> El diseño de cada funcionalidad está especificado en `docs/superpowers/specs/` (`2026-09-05-estado-escaneo-enlaces-design.md`, `2026-09-05-captura-enlaces-design.md`).

---

## Licencia

Uso libre para la comunidad de Argentum Online. Los enlaces del catálogo pertenecen a sus respectivos autores/proyectos.