# -*- coding: utf-8 -*-
"""
Paso 6. Revisión de la calibración.

Con los valores de resultados/valores_cerrado.json (o los que indiques en
ARCHIVO_VALORES) revisa:
  - error de calibración (2019-2025) y de prueba fuera de muestra (ene-sep 2026)
    de las cuatro series, con Theil y las medidas del patrón;
  - residuos mensuales en el tiempo (no deberían tener tendencia ni ciclo propio);
  - perfiles: se mueve cada parámetro calibrado por todo su rango con los demás
    fijos. Si la curva del error es plana, el parámetro queda mal definido por
    los datos y conviene fijarlo con su fuente;
  - comparación con el censo del ICA.

Salidas: resultados/06_diagnostico_<fecha>.xlsx y tres .png, y el registro.
"""
import json

import numpy as np
import pandas as pd

import config as C
import herramientas as H
import matplotlib.pyplot as plt

ARCHIVO_VALORES = "valores_cerrado.json"   # o "valores_regla.json"

valores = H.valores_actuales()
leidos = H.leer_valores(ARCHIVO_VALORES)
if leidos:
    valores.update(leidos)
    datos = json.loads((C.CARPETA_RESULTADOS / ARCHIVO_VALORES).read_text(encoding="utf-8"))
    calibrados = datos.get("calibrados", C.CALIBRAR_CERRADO)
    print(f"Valores de {ARCHIVO_VALORES}")
else:
    calibrados = C.CALIBRAR_CERRADO
    print(f"No encontré {ARCHIVO_VALORES}: se revisan los valores actuales del modelo.")

sim = H.Simulador("cerrado")
df = sim.correr(valores)
metr = H.tabla_metricas(df)
print("\n", metr[["serie", "periodo", "MAPE", "r", "UM", "US", "UC", "amplitud", "desfase",
                  "periodo_sim", "periodo_obs"]].to_string(index=False))
ica = H.comparar_ica(df)

# ---- residuos mensuales
residuos = {}
for var in ("Encasetamiento", "Precio de mercado"):
    s = H.a_mensual(H.ventana(df[var], 0, C.SEMANA_FIN_PRUEBA))
    o = H.a_mensual(H.ventana(df[C.SERIES[var]], 0, C.SEMANA_FIN_PRUEBA))
    residuos[var] = ((s - o) / o * 100).round(2)
residuos = pd.DataFrame(residuos)
residuos.index = residuos.index.astype(str)

# ---- perfiles
perfiles = []
for n in calibrados:
    p = H.PARAM[n]
    for v in np.linspace(p["minimo"], p["maximo"], C.N_PUNTOS_PERFIL):
        prueba = dict(valores)
        prueba[n] = float(v)
        try:
            d = sim.correr(prueba)
            me = H.metricas(d["Encasetamiento"], d["Encasetamiento observado"], 0, C.SEMANA_FIN_CALIBRACION)["MAPE"]
            mp = H.metricas(d["Precio de mercado"], d["Precio de mercado observado"], 0, C.SEMANA_FIN_CALIBRACION)["MAPE"]
            ei = H.error_ica(d)
            err = H.objetivo(d, C.PESOS_CERRADO)
        except Exception:
            me = mp = ei = err = np.nan
        perfiles.append(dict(parametro=n, valor=float(v), MAPE_encasetamiento=me, MAPE_precio=mp,
                             error_ica=ei, error_ponderado=err))
    print(f"  perfil listo: {n}")
perfiles = pd.DataFrame(perfiles)

s = H.sello()
ruta_xlsx = C.CARPETA_RESULTADOS / f"06_diagnostico_{s}.xlsx"
png_ajuste = C.CARPETA_RESULTADOS / f"06_ajuste_{s}.png"
png_res = C.CARPETA_RESULTADOS / f"06_residuos_{s}.png"
png_perf = C.CARPETA_RESULTADOS / f"06_perfiles_{s}.png"
H.guardar_excel(ruta_xlsx, {"metricas": metr, "residuos_mensuales_pct": residuos, "perfiles": perfiles,
                            "ica": ica, "valores": pd.DataFrame([valores]).T.rename(columns={0: "valor"})})
H.figura_ajuste(df, png_ajuste, "Simulado frente a observado con los valores calibrados")

fig, ejes = plt.subplots(2, 1, figsize=(10, 6), sharex=True)
for ax, var in zip(ejes, residuos.columns):
    ax.bar(range(len(residuos)), residuos[var].values, color="#1f5fa8")
    ax.axhline(0, color="0.3", lw=0.8)
    ax.set_title(f"Residuo mensual de {var} (% del observado)", fontsize=10, loc="left")
    ax.grid(axis="y", alpha=0.25)
pos = list(range(0, len(residuos), 6))
ejes[-1].set_xticks(pos)
ejes[-1].set_xticklabels([residuos.index[i] for i in pos], rotation=45, fontsize=8)
fig.tight_layout()
fig.savefig(png_res, dpi=150)
plt.close(fig)

k = len(calibrados)
cols = 3
filas = int(np.ceil(k / cols))
fig, ejes = plt.subplots(filas, cols, figsize=(4.2 * cols, 3 * filas), squeeze=False)
for ax, n in zip(ejes.ravel(), calibrados):
    d = perfiles[perfiles.parametro == n]
    ax.plot(d.valor, d.error_ponderado, "-o", ms=3, color="#1f5fa8")
    ax.axvline(valores[n], color="0.5", ls="--", lw=1)
    ax.set_title(n, fontsize=8, loc="left")
    ax.grid(alpha=0.25)
for ax in ejes.ravel()[k:]:
    ax.axis("off")
fig.suptitle("Perfil del error ponderado (línea punteada = valor calibrado)", fontsize=11)
fig.tight_layout()
fig.savefig(png_perf, dpi=150)
plt.close(fig)

resumen = {f"MAPE {r.serie} ({r.periodo})": r.MAPE for r in metr.itertuples()}
H.registrar("06_diagnostico", f"Revisión de la calibración con {ARCHIVO_VALORES if leidos else 'valores actuales'}",
            {n: round(valores[n], 4) for n in calibrados}, resumen,
            [ruta_xlsx, png_ajuste, png_res, png_perf], sim.md5)
print(f"\nGuardado: {ruta_xlsx.name} y tres gráficas (ajuste, residuos, perfiles)")
