# -*- coding: utf-8 -*-
"""
Prueba manual: corre el modelo con los valores que escribas aquí abajo.

Sirve para ensayar a mano, como con SyntheSim, pero dejando el registro.
Cambia DESCRIPCION, MODO y VALORES, guarda el archivo y córrelo. Los
parámetros que no escribas quedan con su valor actual (config.py).
Los nombres tienen que ser exactamente los de config.PARAMETROS.

Salidas: resultados/prueba_<fecha>.png y una línea en registro_calibracion.csv.
"""
import config as C
import herramientas as H

DESCRIPCION = "Prueba manual: percepción del precio de 12 semanas"
MODO = "cerrado"          # "cerrado" o "regla" (precio y costo observados)
VALORES = {
    "Tiempo de percepción del precio": 12,
    # "Tiempo de ajuste de gallinas": 18,
    # "Sensibilidad de las gallinas deseadas al margen": 1,
}

desconocidos = [n for n in VALORES if n not in H.PARAM]
if desconocidos:
    raise SystemExit(f"Estos nombres no están en config.PARAMETROS: {desconocidos}")

sim = H.Simulador(MODO)
valores = H.valores_actuales()
valores.update(VALORES)
df = sim.correr(valores)
series = ["Encasetamiento", "Precio de mercado"] if MODO == "cerrado" else ["Encasetamiento", "Producción de huevos"]
tabla = H.tabla_metricas(df, series)
print(tabla[["serie", "periodo", "MAPE", "r", "UM", "US", "UC", "amplitud", "desfase"]].to_string(index=False))
pesos = C.PESOS_CERRADO if MODO == "cerrado" else C.PESOS_REGLA
error = H.objetivo(df, pesos)
print(f"\nError ponderado 2019-2025: {error:.3f}")

ruta = C.CARPETA_RESULTADOS / f"prueba_{H.sello()}.png"
H.figura_ajuste(df, ruta, DESCRIPCION, series=tuple(series))
H.registrar("probar_valores", f"{DESCRIPCION} (modo {MODO})", VALORES,
            {"error_ponderado": round(error, 3), **{f"MAPE {r.serie} ({r.periodo})": r.MAPE for r in tabla.itertuples()}},
            [ruta], sim.md5)
print(f"Gráfica: {ruta.name}")
