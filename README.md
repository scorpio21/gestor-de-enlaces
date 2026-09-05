# GestorAO

**Gestor de enlaces para Argentum Online** — aplicación de escritorio en Godot 4 para organizar y verificar la disponibilidad de enlaces de descarga (servidores, clientes y códigos fuente) de proyectos Argentum Online.

> Útil para mantener catálogos históricos de servidores/clients AO: evita enlaces rotos y permite comprobar rápidamente qué archivos siguen disponibles.

---

## Características

- 📚 **Listado por catálogo** — listado base en `data/data.json` + enlaces añadidos por el usuario guardados en `user://enlaces.json`.
- 🔎 **Buscador en vivo** — filtra por nombre y descripción mientras escribes.
- ✅ **Verificación de enlaces** — comprueba la disponibilidad HTTP de cada URL con hasta **3 verificaciones en paralelo**, gestionando redirecciones, timeouts y marcadores típicos de archivo eliminado (4shared, RapidShare…).
- 🎛️ **Filtros por estado** — Todos / Válidos / Caídos / Sin comprobar.
- ➕ **Añadir enlaces** — ventana con nombre, descripción y URL validada.
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

1. **Abrir la aplicación** — se carga el catálogo base (`data/data.json`) y los enlaces de usuario (`user://enlaces.json`).
2. **Comprobar enlaces** — pulsa **Comprobar** para verificar todos los enlaces visibles (o los que el filtro deje ver). Los resultados se muestran en cada fila:
   - 🟢 **Válido** — el archivo responde `200`-`3xx`.
   - 🔴 **Caído / no existe** — `404`/`410`, conexión fallida, dominio inexistente o marcador de archivo eliminado.
   - 🟡 **Sin comprobar** — pendiente de verificación.
3. **Filtrar** — usa el desplegable para ver solo válidos, caídos o sin comprobar.
4. **Buscar** — escribe en el campo de búsqueda para filtrar por nombre/descripción.
5. **Añadir** — menú *Utilidades → Agregar* (o atajo directo). La URL debe empezar por `http://` o `https://`.
6. **Abrir enlace** — clic sobre la fila del enlace.

---

## Almacenamiento de datos

| Ruta | Contenido |
|---|---|
| `res://data/data.json` | Catálogo base (solo lectura en builds exportados) |
| `user://enlaces.json` | Enlaces añadidos por el usuario |
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
│   └── agregar_enlace.gd    # Formulario de nuevo enlace
├── data/
│   └── data.json            # Catálogo base de enlaces
└── docs/superpowers/specs/  # Especificaciones de diseño
```

---

## Roadmap

- [x] Listado de enlaces, búsqueda y filtros por estado
- [x] Verificación HTTP en paralelo con detección de archivos eliminados
- [x] Alta de enlaces desde la interfaz
- [ ] **Persistencia del estado de escaneo** (`user://estados.json`) — los resultados se guardan y no hace falta re-escanear al abrir
- [ ] **Eliminación de enlaces caídos** con confirmación y control de URL eliminadas (`user://borrados.json`)
- [ ] Re-verificación individual por enlace

> El alcance de las tareas pendientes está especificado en `docs/superpowers/specs/2026-09-05-estado-escaneo-enlaces-design.md`.

---

## Licencia

Uso libre para la comunidad de Argentum Online. Los enlaces del catálogo pertenecen a sus respectivos autores/proyectos.