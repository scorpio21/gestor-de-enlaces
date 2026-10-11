## Decisión sobre backup_to en SQLite (#72)

En el backend `scripts/almacen_bd.gd`, se toma un `.bak` con `backup_to()` justo antes de cada transacción de escritura, pero solo si ya había datos (`_hay`).

- **Estado actual**: cada escritura guarda una copia completa de `gestorao.db` en `gestorao.db.bak`. Esto mantiene la semántica "versión anterior" idéntica a los otros backends (no copia en la primera escritura).
- **Razones para mantenerlo**: simplicidad, la base contiene la carga útil en JSON por fila (no hay millones de escrituras por sección), restauración trivial (`restore_from(bak)`), tamaño típicamente pequeño, y ha demostrado mantener consistencia bajo transacciones.
- **Cuándo evaluar cambio**: si el catálogo crece mucho, las capturas van a `Assets/` (no a la base) y las escrituras son por lotes (estados/cola/config/etc.). Un `backup_to` es una copia del archivo completo, es correcto con esta frecuencia y con el tamaño actual.

**Decisión**: **mantener `backup_to` antes de cada escritura que modifique datos** (solo si `_hay`). No se implementa copia por intervalo/umbral ahora. Si aparece un catálogo muy grande y las pruebas muestran lentitud, se reconsidera la cadencia.

Documentado en `MEMORIA.md` (este bloque) por resolución del issue #72.
