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

- **Godot 4.7** (motor usará *Forward Plus*, renderizado **D3D12** en Windows).

---

## Instalación y ejecución

```bash
git clone https://github.com/scorpio21/gestor-de-enlaces.git
cd gestor-de-enlaces
godot --path .          # abre el editor
godot -e                # importa y abre el editor con importación de recursos
```

O simplemente abre `project.godot` desde el propio editor de Godot 4.7.

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
| `Assets/png/` | Capturas de imagen de los enlaces (carpeta versionada) |
| `data/data.json.bak` | Copia de seguridad local (no versionada) |

> `user://` equivale a la carpeta de datos del usuario del sistema según el sistema operativo.

---

## Estructura del proyecto

```
gestor-de-enlaces/
├── project.godot            # Configuración del proyecto
├── scenes/
│   ├── Main.tscn            # Escena principal (UI completa)
│   ├── AgregarEnlace.tscn   # Ventana para añadir enlaces
│   └── ListItem.tscn        # Fila individual del listado
├── scripts/
│   ├── main.gd              # Lógica de la UI, carga/guardado y escaneo
│   ├── list_item.gd         # Fila: estado, verificación y apertura
│   ├── link_checker.gd      # Verificador HTTP (redirecciones, timeouts…)
│   ├── agregar_enlace.gd    # Formulario de nuevo enlace (+ captura)
│   ├── estado_store.gd      # Persistencia de estados y borrados (user://)
│   └── gestor_imagenes.gd   # Copia de capturas a Assets/png
├── data/
│   └── data.json            # Catálogo base de enlaces
├── Assets/
│   └── png/
│       └── no-disponible.png  # Marcador cuando un enlace no tiene captura
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

> El diseño de cada funcionalidad está especificado en `docs/superpowers/specs/` (`2026-09-05-estado-escaneo-enlaces-design.md`, `2026-09-05-captura-enlaces-design.md`).

---

## Licencia

Uso libre para la comunidad de Argentum Online. Los enlaces del catálogo pertenecen a sus respectivos autores/proyectos.