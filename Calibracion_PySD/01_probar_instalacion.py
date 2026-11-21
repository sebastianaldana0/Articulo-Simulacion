# -*- coding: utf-8 -*-
"""
Paso 1. Revisa la instalación, traduce el modelo y corre la base.

Qué hace:
  1. Muestra las versiones de Python y de los paquetes.
  2. Copia Modelo actual.mdl a la carpeta modelo/ y lo traduce con PySD.
  3. Corre el modelo cerrado con los valores actuales y calcula el error
     (calibración 2019-2025 y prueba ene-sep 2026).
  4. Guarda una tabla corta para comparar con Vensim (paso 2).

Salidas: resultados/01_corrida_base_<fecha>.xlsx y .png,
         comparar_con_vensim_base.csv y una línea en registro_calibracion.csv.
"""
import importlib.metadata as md
import platform
import time

import config as C
import herramientas as H

print("Python", platform.python_version())
for paquete in ("pysd", "numpy", "pandas", "scipy", "matplotlib", "openpyxl"):
    print(f"  {paquete:11s} {md.version(paquete)}")

sim = H.Simulador("cerrado")
inicio = time.time()
df = sim.correr()
segundos = time.time() - inicio
print(f"\nCorrida completa en {segundos:.2f} s (semanas 0 a {int(df.index[-1])}).")

tabla = H.tabla_metricas(df)
print("\nError de la corrida base (promedios mensuales):")
print(tabla[["serie", "periodo", "MAPE", "r", "UM", "US", "UC", "amplitud", "desfase"]].to_string(index=False))

# tabla corta para comparar con Vensim
semanas = [0, 52, 104, 208, 312, 364, 403]
corta = df.loc[semanas, list(C.SERIES)]
corta.index = corta.index.astype(int)
corta.index.name = "Semana"
ruta_csv = C.CARPETA / "comparar_con_vensim_base.csv"
corta.to_csv(ruta_csv, sep=";", decimal=",")

s = H.sello()
ruta_xlsx = C.CARPETA_RESULTADOS / f"01_corrida_base_{s}.xlsx"
ruta_png = C.CARPETA_RESULTADOS / f"01_corrida_base_{s}.png"
H.guardar_excel(ruta_xlsx, {"metricas": tabla, "ica": H.comparar_ica(df), "series_semanales": df})
H.figura_ajuste(df, ruta_png, "Corrida base con los valores actuales")

resumen = {f"MAPE {r.serie} ({r.periodo})": r.MAPE for r in tabla.itertuples()}
resumen["segundos_por_corrida"] = round(segundos, 2)
H.registrar("01_probar_instalacion", "Corrida base con los valores actuales del modelo",
            H.valores_actuales(), resumen, [ruta_xlsx, ruta_png, ruta_csv], sim.md5)
print(f"\nGuardado: {ruta_xlsx.name}, {ruta_png.name} y {ruta_csv.name}")
