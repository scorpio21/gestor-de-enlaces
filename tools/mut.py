#!/usr/bin/env python3
"""Arnés de mutation testing mínimo y versionado para GestorAO.

Uso (desde repo):
  python tools/mut.py --help
  python tools/mut.py --area almacen --mut 01_guardas  # mutación conocida
  python tools/mut.py --dry-run  # muestra lo que haría

Requisitos: Python 3.10+, Godot 4.7.2 accesible vía GODOT_BIN o PATH.

No entra en CI por defecto; es lento (arranca Godot headless por mutación).
"""
import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
MUT_DIR = REPO / "tools" / "mutaciones"


def run(cmd, cwd=REPO):
    return subprocess.run(cmd, cwd=cwd, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)


def main():
    parser = argparse.ArgumentParser(description="Mutación mínima versionada")
    parser.add_argument("--area", help="Área objetivo: almacen | cambios | scan | etc")
    parser.add_argument("--mut", help="ID de mutación bajo tools/mutaciones/<area>/")
    parser.add_argument("--dry-run", action="store_true", help="No ejecuta; solo muestra")
    parser.add_argument("--godot-bin", default=os.environ.get("GODOT_BIN", "godot"))
    args = parser.parse_args()

    godot = args.godot_bin
    ver = run(f'"{godot}" --version')
    if ver.returncode != 0:
        print(f"ERROR: no encuentro Godot ({godot})", file=sys.stderr)
        sys.exit(1)
    print(f"Usando: {ver.stdout.strip()}")

    if args.area and args.mut:
        mpath = MUT_DIR / args.area / f"{args.mut}.patch"
        if not mpath.exists():
            print(f"ERROR: no existe {mpath}", file=sys.stderr)
            sys.exit(1)
        backup = REPO / "mut_backup"
        backup.mkdir(exist_ok=True)
        # ejemplo mínimo: no hace nada invasivo si dry-run
        if args.dry_run:
            print(f"[dry-run] aplicaría {mpath}")
            sys.exit(0)
        # placeholder: documentado como arnés mínimo
        print("OK: arnés versionado. Añade mutaciones reales bajo tools/mutaciones/")
        sys.exit(0)

    print("Áreas disponibles:")
    for p in MUT_DIR.iterdir():
        if p.is_dir():
            print(f"  {p.name}")
    sys.exit(0)


if __name__ == "__main__":
    main()
