# -*- coding: utf-8 -*-
"""
Paso 4. Calibración parcial de la regla de encasetamiento (Homer; Oliva).

El precio de mercado se reemplaza por el observado (precio SIPSA); el costo de
la historia ya es el de Fenavi en este modelo. Así el encasetamiento simulado depende solo
de la regla de decisión, las aves, los productores y los galpones, y no de
los errores del mercado. Se calibran los parámetros de config.CALIBRAR_REGLA
para minimizar el MAPE mensual del encasetamiento en 2020-2025 (desde la semana 52, después del calentamiento).

Salidas: resultados/04_regla_<fecha>.xlsx (hoja "traza" con cada corrida del
optimizador, hoja "inicios" con el resultado de cada punto de partida) y .png;
resultados/valores_regla.json (lo usa el paso 5) y el registro.
"""
import time

import pandas as pd

import config as C
import herramientas as H

sim = H.Simulador("regla")
nombres = C.CALIBRAR_REGLA
inicio = H.valores_actuales()
print("Parámetros que se calibran:", ", ".join(nombres))

antes = sim.correr(inicio)
error_antes = H.objetivo(antes, C.PESOS_REGLA)
print(f"Error con los valores actuales: {error_antes:.2f} % (MAPE mensual del encasetamiento 2020-2025)")

t0 = time.time()
mejor, error, traza, inicios = H.calibrar(sim, nombres, inicio, C.PESOS_REGLA, C.N_INICIOS_REGLA)
print(f"\nMejor error: {error:.2f} % en {len(traza)} corridas ({time.time() - t0:.0f} s)")
print(inicios.to_string(index=False))

despues = sim.correr(mejor)
series = ["Encasetamiento", "Producción de huevos"]
m_antes = H.tabla_metricas(antes, series).assign(valores="actuales")
m_despues = H.tabla_metricas(despues, series).assign(valores="calibrados")
metr = pd.concat([m_antes, m_despues], ignore_index=True)
print("\n", metr[["valores", "serie", "periodo", "MAPE", "r", "UM", "US", "UC", "amplitud", "desfase"]].to_string(index=False))
tabla_val = pd.DataFrame([dict(parametro=n, actual=inicio[n], calibrado=round(mejor[n], 4),
                               minimo=H.PARAM[n]["minimo"], maximo=H.PARAM[n]["maximo"],
                               en_el_limite=abs(mejor[n] - H.PARAM[n]["minimo"]) < 1e-3 * (H.PARAM[n]["maximo"] - H.PARAM[n]["minimo"])
                               or abs(mejor[n] - H.PARAM[n]["maximo"]) < 1e-3 * (H.PARAM[n]["maximo"] - H.PARAM[n]["minimo"]))
                          for n in nombres])
print("\n", tabla_val.to_string(index=False))
if tabla_val.en_el_limite.any():
    print("Ojo: algún valor quedó en el límite de su rango. Revisa si el rango es razonable antes de seguir.")

s = H.sello()
ruta_xlsx = C.CARPETA_RESULTADOS / f"04_regla_{s}.xlsx"
ruta_png = C.CARPETA_RESULTADOS / f"04_regla_{s}.png"
H.guardar_excel(ruta_xlsx, {"valores": tabla_val, "metricas": metr, "inicios": inicios, "traza": traza,
                            "series_calibradas": despues})
H.figura_ajuste(despues, ruta_png, "Prueba parcial de la regla (precio observado), valores calibrados",
                series=("Encasetamiento", "Producción de huevos"))
ruta_json = H.guardar_valores(mejor, "valores_regla.json", {"calibrados": nombres, "error": error})
H.registrar("04_calibrar_regla", "Calibración parcial de la regla con el precio observado (Powell, varios inicios)",
            {n: round(mejor[n], 4) for n in nombres},
            {"error_antes": round(error_antes, 3), "error_despues": round(error, 3), "corridas": len(traza)},
            [ruta_xlsx, ruta_png, ruta_json], sim.md5)
print(f"\nGuardado: {ruta_xlsx.name}, {ruta_png.name} y valores_regla.json")
