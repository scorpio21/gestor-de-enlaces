# Changelog

Todos los cambios relevantes de GestorAO por día.

## [Sin publicar]

### Añadido

- **Internacionalización ES/EN** (`#30`): selector de idioma con banderas en Preferencias, CSV de traducciones (`locale/gestor_es_en.csv`), carga de traducciones al arrancar y `tr()` en toda la UI (textos de escaneo, dialogs, menús, cabeceras de columna e historial). Scanner de cadenas de UI (`scripts/extraer_cadenas.gd`) con test de cobertura (`test_locale.gd`).
- **Ordenación por columnas** (`#17`): cabeceras pulsables en la lista (fecha, nombre, imagen, estado) con criterio persistido en configuración y restauración al arrancar.

---

## [0.1.5]

### Añadido

- **Dashboard de estadísticas** (`#45`): ventana desde el menú Utilidades con resumen de disponibilidad (válidos, caídos, sin comprobar y % disponible sobre los comprobados), distribución por categoría y por host (los más problemáticos primero), gráfico de comprobaciones válidas vs caídas por día a partir del historial y exportación a CSV/JSON.

### Cambiado

- Versión del proyecto a 0.1.5.

---

## [0.1.4]

### Añadido

- **Vista de grilla** (`#43`): botón que alterna entre lista y cuadrícula de tarjetas (miniatura grande con nombre, estado y fecha); los filtros y la ordenación se aplican igual en ambas vistas y la vista elegida queda persistida en configuración.

### Cambiado

- Versión del proyecto a 0.1.4.

---

## [0.1.3]

### Añadido

- **Presets de filtros** (`#44`): guardar la combinación actual de filtros (estado, categoría, etiqueta, búsqueda, código HTTP, días y modo) bajo un nombre, aplicarla desde el desplegable y eliminarla; hasta 20 presets en `user://presets_filtros.json`. El filtro por días se aplica en vivo al cambiar el SpinBox.

### Cambiado

- Versión del proyecto a 0.1.3.

---

## [0.1.2]

### Añadido

- **Filtros avanzados** (`#44`): búsqueda booleana AND/OR por palabras en nombre/descripción/URL, filtro por código HTTP (200, 301, 302, 403, 404, 410, 500, 503) y filtro por última comprobación (últimos N días), combinables con estado, categoría y etiquetas; los tres criterios nuevos se persisten en configuración.

### Cambiado

- Versión del proyecto a 0.1.2.

---

## [0.1.1]

### Añadido

- **Etiquetas personalizadas** (`#42`): campo en el alta de enlaces con sugerencias por uso frecuente, normalización de etiquetas y filtro por etiqueta combinable con estado y categoría, con el criterio persistido en configuración.
- **Barra de estado con colores**: nombre de contador en blanco y número en color — Rotos (rojo), Activos (verde) y Total (azul).

### Cambiado

- Versión del proyecto a 0.1.1.

---

## 2026-09-24

- Implementación completa de `#30` (internacionalización): `config_store` guarda y valida el idioma, CSV ES/EN con scanner y test de cobertura, banderas de idioma generadas, selector en Preferencias y aplicación de idioma con `tr()` runtime (6 commits).

---

## 2026-09-23

- Spec y plan de `#30` (internacionalización).
- Ordenación por columnas (`#17`): spec, plan, persistence del criterio en config, exposición de nombre/imagen en `list_item`, cabeceras en la escena e integración con persistencia y rollback (7 commits).
- Orden manual de la lista (`#6`): helpers de reorden, estados del menú contextual, tests con filtros y persistencia; plan y spec (4 commits).
- Detalles de la convención de cierre de issues (AGENTS.md).

---

## 2026-09-20

- Aviso de nueva versión (`#27`): comparador de versiones y parse de `releases/latest` (TDD), nodo `HTTPClient` que consulta la API y aviso una vez por versión con opción de menú. Orden manual de la lista (`#6`): spec y plan del menú contextual Subir/Bajar (7 commits).

---

## 2026-09-19

- Tema claro/oscuro (`#19`): store con paletas y `aplicar` (TDD), selector `%Tema` en Preferencias y aplicación en arranque; `list_item` pinta con paleta (4 commits).
- Informe de disponibilidad (`#11`): store CSV/HTML, menú Archivo con FileDialog y checks de integración (3 commits).
- Cola de escaneo persistida (`#13`): store de `user://colas.json`, persistencia en cada avance y diálogo de reanudación (4 commits).
- Detectores de enlace caído por host (`#12`): marcas host-específicas (MEGA, MediaFire, Drive, Sites, Dropbox, WeTransfer) con unión a las genéricas (2 commits).
- Ajustes de Preferencias por contenido, import ETC2 ASTC para macOS universal, import previo a la batería en CI y README/empaquetado/logs/diagnóstico (9 commits).

---

## 2026-09-18

- Empaquetado y CI (`#26`): presets Windows/Linux/macOS y workflow GitHub Actions (2 commits).
- Logs y diagnóstico (`#28`): logger rotativo app/scan y exportador de ZIP con `info.txt` (3 commits).
- Icono y metadatos (`#29`): generador de iconos SVG/PNG/ICO/ICNS y proyecto 0.1.0 (2 commits).
- Correcciones de la spec de empaquetado y extras (3 commits).

---

## 2026-09-15

- Disponibilidad de enlaces (`#8`, `#9`, `#10`): auto-escaneo al abrir con intervalo, fecha de última comprobación visible, selector de orden por fecha y diálogo de historial con cap de 50 (8 commits).

---

## 2026-09-14

- Datos persistentes confiables (`#23`, `#24`): `gestor_datos.gd` con esquema versionado, escritura atómica y copia de seguridad; menú Restaurar copia y detección de fallos (5 commits).
- Normalización de URLs (`#25`): `normalizar_url` y `clave_unica`, deduplicación de variantes en carga, alta, lote y edición; estados y contadores por clave canónica (4 commits).
- Ventana Agregar enlace (`#32`, `#33`): redimensionable, diálogo de imagen jpg/jpeg/webp y copiado por formato con limpieza en Assets/jpg (4 commits).
- Importar/exportar catálogo y atajos (`#3`, `#14`): desde el menú Archivo; Ctrl+F/N/R y Esc (3 commits).
- Tests de `link_checker` (`#31`): marcadores, parseo, redirects y sin red (3 commits).
- Correcciones y planes asociados (11 commits).

---

## 2026-09-13

- Categorías (`#5`): helpers en `gestor_catalogo`, campo en alta/edición, etiqueta en filas y desplegable de filtro combinado estado+categoría (7 commits).
- Capturas (`#20`, `#21`, `#22`): cambiar/quitar captura al editar con reporte de imagen pendiente, limpieza de huérfanas desde menú y al cerrar, y redimensionado a 800px (8 commits).
- Sidecars `.uid` de Godot 4.7 versionados y ajustes de conteos (5 commits).

---

## 2026-09-12

- Alta y edición de enlaces (`#1`, `#2`, `#4`): helpers de catálogo (dominio, separar), diálogo multi-modo, edición con remapeo de estado y borrados, lote de URLs con duplicados y menú contextual (14 commits).
- Plan y spec del catálogo; correcciones de conteos y tipos (1 commit).

---

## 2026-09-07

- Corrección de `abrir_edicion` en modo Varias y conteos del plan (1 commit).

---

## 2026-09-06

- Preferencias de escaneo (`#7`): `config_store` para paralelismo/timeout, diálogo de preferencias e integración en main (7 commits).
- Lote de UI (`#15`, `#16`, `#18`): barra de progreso, copiar URL, tooltip de estado, código HTTP y fecha (5 commits).
- Contadores con código HTTP y fecha; lista de servidores inicial y sidecars `.uid` (5 commits).
- Plan y spec del catálogo base; ajustes de checks (7 commits).

---

## 2026-09-05

- Base del proyecto (1 commit).
- Barra de estado (`#8` parcial): contadores del catálogo y versión 0.0.1 (4 commits).
- Persistencia del escaneo (`#1`, `#2`): `EstadoStore`, eliminación de caídos y re-comprobación individual (5 commits).
- Capturas/imagen (`#1`): selector y copiado, miniatura con placeholder y borrado del archivo (6 commits).
- README profesional y ajustes varios (3 commits).

---

Formato basado en [Keep a Changelog](https://keepachangelog.com/es/).