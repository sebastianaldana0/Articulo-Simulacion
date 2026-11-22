# -*- coding: utf-8 -*-
"""
Paso 8. Compara este modelo con el nuestro (Modelo calibrado.mdl).

Los dos se miden igual: mismas series observadas (las tablas semanales de la
base, que son idénticas en los dos .mdl; el script lo comprueba), misma
ventana de calibración (2020-2025, porque este modelo copia el dato en 2019),
misma prueba (ene-sep 2026) y mismos censos del ICA.

Modelos que entran:
  - Nuestro modelo: Modelo calibrado.mdl, de la carpeta del artículo. Solo se
    lee: se copia a modelo_comparacion/ y se traduce ahí.
  - Este modelo tal cual: Modelo final semanal.mdl con los valores de los
    compañeros.
  - Este modelo calibrado: los valores de resultados/valores_cerrado.json
    (si ya existe; si no, se omite).

Salidas: resultados/08_comparacion_<fecha>.xlsx y .png, y el registro.
"""
import shutil

import pandas as pd

import config as C
import herramientas as H  # importa rapido antes de pysd.load
import pysd

# ---------------------------------------------------------------- nuestro modelo (solo lectura)
if not C.RUTA_MODELO_PROPIO.exists():
    raise SystemExit(f"No encuentro {C.RUTA_MODELO_PROPIO}. Revisa RUTA_MODELO_PROPIO en config.py.")
carpeta = C.CARPETA / "modelo_comparacion"
carpeta.mkdir(exist_ok=True)
copia = carpeta / "modelo_propio.mdl"
md5_propio = H._md5(C.RUTA_MODELO_PROPIO)
if not copia.exists() or H._md5(copia) != md5_propio or not (carpeta / "modelo_propio.py").exists():
    shutil.copy2(C.RUTA_MODELO_PROPIO, copia)
    print(f"Traduciendo {C.RUTA_MODELO_PROPIO.name} con PySD (copia en modelo_comparacion/)...")
    pysd.read_vensim(str(copia))
propio = pysd.load(str(carpeta / "modelo_propio.py"))
columnas = sorted(set(list(C.SERIES) + list(C.SERIES.values()) + [
    "Gallinas en postura", "Productores activos", "Capacidad de galpones"]))
corridas = {"Nuestro modelo (calibrado)": propio.run(return_columns=columnas,
                                                     final_time=C.SEMANA_FIN_PRUEBA)}

# ---------------------------------------------------------------- este modelo
sim = H.Simulador("cerrado")
corridas["Modelo final (tal cual)"] = sim.correr(H.valores_actuales())
calibrados = H.leer_valores("valores_cerrado.json")
if calibrados:
    v = H.valores_actuales()
    v.update(calibrados)
    corridas["Modelo final (calibrado)"] = sim.correr(v)
else:
    print("Todavía no hay resultados/valores_cerrado.json: se compara solo la versión tal cual.")

# ---------------------------------------------------------------- mismos datos observados
ref = corridas["Modelo final (tal cual)"]
otro = corridas["Nuestro modelo (calibrado)"]
dif_obs = {}
for o in C.SERIES.values():
    a = ref.loc[:C.SEMANA_FIN_PRUEBA, o]
    b = otro.loc[:C.SEMANA_FIN_PRUEBA, o]
    ok = a.notna() & b.notna()
    dif_obs[o] = float((a[ok] - b[ok]).abs().max())
print("Diferencia máxima entre las series observadas de los dos modelos:",
      ", ".join(f"{k}: {v:.3g}" for k, v in dif_obs.items()))
if max(dif_obs.values()) > 1e-6:
    print("  Atención: los dos modelos no tienen las mismas tablas observadas; la comparación no es pareja.")

# ---------------------------------------------------------------- métricas
filas, resumen = [], {}
for nombre, df in corridas.items():
    t = H.tabla_metricas(df)
    t.insert(0, "modelo", nombre)
    filas.append(t)
    cal = t[t.periodo == C.ETIQUETA_CALIBRACION].set_index("serie").MAPE
    pru = t[t.periodo == C.ETIQUETA_PRUEBA].set_index("serie").MAPE
    resumen[nombre] = dict(
        error_ponderado_2020_2025=round(sum(w * cal[s] for s, w in C.PESOS_CERRADO.items()), 3),
        error_ponderado_2026=round(sum(w * pru[s] for s, w in C.PESOS_CERRADO.items()), 3))
metr = pd.concat(filas, ignore_index=True)
tabla_resumen = pd.DataFrame(resumen).T
tabla_resumen.index.name = "modelo"
print("\n", tabla_resumen.to_string())
print("\n", metr[["modelo", "serie", "periodo", "MAPE", "r", "UM", "US", "UC", "amplitud"]].to_string(index=False))

ica = pd.concat([H.comparar_ica(df).assign(modelo=nombre) for nombre, df in corridas.items()], ignore_index=True)
print("\n", ica[["modelo", "anio", "productores_modelo", "predios_ica", "indice_capacidad_modelo",
                 "indice_capacidad_ica", "ocupacion_modelo", "ocupacion_ica"]].to_string(index=False))

# ---------------------------------------------------------------- figura
import matplotlib.pyplot as plt  # noqa: E402

colores = {"Nuestro modelo (calibrado)": "#1f5fa8", "Modelo final (tal cual)": "#c0392b",
           "Modelo final (calibrado)": "#e08e0b"}
fig, ejes = plt.subplots(2, 1, figsize=(10, 7), sharex=True)
for ax, var in zip(ejes, ["Encasetamiento", "Precio de mercado"]):
    d = ref.loc[:C.SEMANA_FIN_PRUEBA]
    ax.plot(d.index, d[C.SERIES[var]], color="0.35", lw=1.2, label="Observado")
    for nombre, df in corridas.items():
        dd = df.loc[:C.SEMANA_FIN_PRUEBA]
        ax.plot(dd.index, dd[var], color=colores[nombre], lw=1.5, label=nombre)
    ax.axvline(C.SEMANA_INICIO_CALIBRACION - 0.5, color="0.6", ls=":", lw=1)
    ax.axvline(C.SEMANA_FIN_CALIBRACION + 0.5, color="0.6", ls="--", lw=1)
    ax.set_title(var, loc="left", fontsize=10)
    ax.grid(alpha=0.25)
    ax.legend(fontsize=8, frameon=False)
ejes[-1].set_xlabel("Semana del modelo (0 = 1-ene-2019). Comparación entre las líneas: 2020-2025; después, prueba 2026")
fig.suptitle("Nuestro modelo frente al modelo final, mismos datos y misma ventana", fontsize=11)
fig.tight_layout()

s = H.sello()
ruta_png = C.CARPETA_RESULTADOS / f"08_comparacion_{s}.png"
fig.savefig(ruta_png, dpi=150)
plt.close(fig)
ruta_xlsx = C.CARPETA_RESULTADOS / f"08_comparacion_{s}.xlsx"
H.guardar_excel(ruta_xlsx, {"resumen": tabla_resumen.reset_index(), "metricas": metr, "ica": ica,
                            "observados_iguales": pd.DataFrame([dif_obs])})
H.registrar("08_comparar_modelos", "Comparación con Modelo calibrado.mdl (mismos datos, 2020-2025 y 2026)",
            {"md5_modelo_propio": md5_propio, "calibrado": calibrados or {}},
            resumen, [ruta_xlsx, ruta_png], sim.md5)
print(f"\nGuardado: {ruta_xlsx.name} y {ruta_png.name}")
