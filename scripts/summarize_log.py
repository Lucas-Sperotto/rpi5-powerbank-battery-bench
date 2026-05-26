#!/usr/bin/env python3
import csv
import sys
from pathlib import Path


def as_float(value, default=0.0):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def main() -> int:
    if len(sys.argv) != 2:
        print(f"Uso: {sys.argv[0]} logs/latest/battery_test_log.csv")
        return 2

    path = Path(sys.argv[1])
    if not path.exists():
        print(f"Arquivo não encontrado: {path}")
        return 1

    with path.open(newline="") as f:
        rows = list(csv.DictReader(f))

    if not rows:
        print("Log vazio.")
        return 1

    first = rows[0]
    last = rows[-1]
    elapsed = as_float(last.get("elapsed_s"))
    hours = int(elapsed // 3600)
    minutes = int((elapsed % 3600) // 60)
    seconds = int(elapsed % 60)

    temps = [as_float(r.get("temp_c"), -1.0) for r in rows]
    temps = [t for t in temps if t >= 0]

    throttled_values = [r.get("throttled", "NA") for r in rows]
    throttled_nonzero = sorted({v for v in throttled_values if v not in ("NA", "0x0", "0")})

    print("Resumo do teste")
    print("================")
    print(f"Arquivo: {path}")
    print(f"Primeiro registro: {first.get('datetime')}")
    print(f"Último registro:   {last.get('datetime')}")
    print(f"Duração: {hours}h {minutes}min {seconds}s ({elapsed:.0f} s)")
    print(f"Registros: {len(rows)}")

    if temps:
        print(f"Temperatura inicial: {temps[0]:.2f} °C")
        print(f"Temperatura final:   {temps[-1]:.2f} °C")
        print(f"Temperatura máxima:  {max(temps):.2f} °C")

    print(f"Última frequência CPU: {last.get('cpu_khz')} kHz")
    print(f"Último throttled: {last.get('throttled')}")

    if throttled_nonzero:
        print(f"Alertas throttled encontrados: {', '.join(throttled_nonzero)}")
    else:
        print("Nenhum throttled diferente de 0x0 encontrado no CSV.")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
