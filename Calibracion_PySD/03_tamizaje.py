# -*- coding: utf-8 -*-
"""
Paso 3. Tamizaje de sensibilidad: cuáles parámetros mueven el resultado.

Corre el modelo cerrado N_TAMIZAJE veces (config.py) con valores al azar de
todos los parámetros de config.PARAMETROS, repartidos en su rango con un
hipercubo latino. Para cada corrida calcula el MAPE del encasetamiento y del
precio en 2019-2025 y la razón de amplitud del encasetamiento. Después mide
la correlación de rangos (Spearman) entre cada parámetro y cada resultado.

Cómo se lee: un parámetro con correlación cercana a cero no mueve el error
y no vale la pena calibrarlo. Con lo que salga aquí se ajustan las listas
CALIBRAR_REGLA y CALIBRAR_CERRADO en config.py (Ford y Flynn, 2005).

Salidas: resultados/03_tamizaje_<fecha>.xlsx y .png, y el registro.
"""
import time

import numpy as np
import pandas as pd

import config as C
import herramientas as H
import matplotlib.pyplot as plt

nombres = [p["nombre"] for p in C.PARAMETROS]
U = H.muestra_lhs(C.N_TAMIZAJE, len(nombres), C.SEMILLA)
sim = H.Simulador("cerrado")
filas = []
inicio = time.time()
for i, u in enumerate(U, start=1):
    valores = H.de_unitario(nombres, u)
    fila = dict(corrida=i, **valores)
    try:
        df = sim.correr(valores)
        me = H.metricas(df["Encasetamiento"], df["Encasetamiento observado"], 0, C.SEMANA_FIN_CALIBRACION)
        mp = H.metricas(df["Precio de mercado"], df["Precio de mercado observado"], 0, C.SEMANA_FIN_CALIBRACION)
        fila.update(MAPE_encasetamiento=me["MAPE"], MAPE_precio=mp["MAPE"], amplitud_encasetamiento=me["amplitud"],
                    error_ponderado=C.PESOS_CERRADO["Encasetamiento"] * me["MAPE"] + C.PESOS_CERRADO["Precio de mercado"] * mp["MAPE"])
    except Exception as e:  # una combinación que hace fallar el modelo también es información
        fila.update(MAPE_encasetamiento=np.nan, MAPE_precio=np.nan, amplitud_encasetamiento=np.nan,
                    error_ponderado=np.nan, falla=str(e)[:120])
    filas.append(fila)
    if i % 25 == 0 or i == len(U):
        print(f"  {i}/{len(U)} corridas ({time.time() - inicio:.0f} s)")

muestras = pd.DataFrame(filas)
resultados = ["error_ponderado", "MAPE_encasetamiento", "MAPE_precio", "amplitud_encasetamiento"]
validas = muestras.dropna(subset=["error_ponderado"])
correl = validas[nombres + resultados].corr(method="spearman").loc[nombres, resultados].round(3)
correl.insert(0, "clase", [H.PARAM[n]["clase"] for n in nombres])
correl["abs_error_ponderado"] = correl["error_ponderado"].abs()
correl = correl.sort_values("abs_error_ponderado", ascending=False).drop(columns="abs_error_ponderado")

print("\nCorrelación de Spearman con cada resultado (ordenada por el error ponderado):")
print(correl.to_string())
print(f"\nCorridas que fallaron: {len(muestras) - len(validas)} de {len(muestras)}")
print(f"Mejor error ponderado de la muestra: {validas.error_ponderado.min():.2f} "
      f"(corrida {int(validas.loc[validas.error_ponderado.idxmin(), 'corrida'])})")

s = H.sello()
ruta_xlsx = C.CARPETA_RESULTADOS / f"03_tamizaje_{s}.xlsx"
ruta_png = C.CARPETA_RESULTADOS / f"03_tamizaje_{s}.png"
H.guardar_excel(ruta_xlsx, {"correlaciones": correl, "muestras": muestras,
                            "rangos": pd.DataFrame(C.PARAMETROS)})

fig, ejes = plt.subplots(1, 2, figsize=(12, 0.38 * len(nombres) + 1.5), sharey=True)
orden = correl.index[::-1]
for ax, col, titulo in zip(ejes, ["MAPE_encasetamiento", "MAPE_precio"], ["MAPE del encasetamiento", "MAPE del precio"]):
    v = correl.loc[orden, col]
    colores = ["#1f5fa8" if H.PARAM[n]["clase"] == "K" else "0.6" for n in orden]
    ax.barh(range(len(orden)), v.values, color=colores)
    ax.axvline(0, color="0.3", lw=0.8)
    ax.set_title(titulo, fontsize=10, loc="left")
    ax.set_xlim(-1, 1)
    ax.grid(axis="x", alpha=0.25)
ejes[0].set_yticks(range(len(orden)))
ejes[0].set_yticklabels(orden, fontsize=8)
fig.suptitle("Correlación de Spearman entre cada parámetro y el error (azul = K, gris = S)", fontsize=11)
fig.tight_layout()
fig.savefig(ruta_png, dpi=150)
plt.close(fig)

H.registrar("03_tamizaje", f"Tamizaje con {len(muestras)} corridas del modelo cerrado (hipercubo latino)",
            {"rangos": {n: [H.PARAM[n]["minimo"], H.PARAM[n]["maximo"]] for n in nombres}},
            {"top_error_ponderado": correl["error_ponderado"].head(6).to_dict(),
             "fallas": int(len(muestras) - len(validas))}, [ruta_xlsx, ruta_png], sim.md5)
print(f"\nGuardado: {ruta_xlsx.name} y {ruta_png.name}")
