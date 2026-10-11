# Mutation Testing (local)

Este arnés es **local y no se ejecuta en CI**. Su objetivo es reproducir mutaciones conocidas para verificar que las suites las detectan (kill rate).

## Cómo lanzar

```bash
python tools/mut.py --help
python tools/mut.py --dry-run --area almacen --mut 01_guardas
```

Godot se detecta vía `GODOT_BIN` o PATH. El script no aplica mutaciones automáticamente por defecto (modo seguro/documentado).

## Estructura

- `tools/mut.py`: arnés mínimo versionado.
- `tools/mutaciones/<area>/<id>.patch`: mutaciones específicas con notas de qué debe fallar.

## Criterio

Cada mutación debe hacer fallar al menos una suite relevante. Si pasa todas, la mutación sobrevive (defecto en tests). Solo se versionan mutaciones ya verificadas manualmente.

## Notas

- Lento: cada mutación requiere ejecutar Godot headless.
- Reversible: usar git para deshacer (checkout).
- No invasivo por diseño (dry-run primero).
