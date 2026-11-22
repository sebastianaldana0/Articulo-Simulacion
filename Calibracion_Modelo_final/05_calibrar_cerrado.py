# -*- coding: utf-8 -*-
"""
Paso 5. Calibración del modelo cerrado.

Parte de los valores del paso 4 (resultados/valores_regla.json) y calibra los
parámetros de config.CALIBRAR_CERRADO con el modelo completo, minimizando
el error ponderado del encasetamiento y del precio en 2020-2025
(config.PESOS_CERRADO). Los datos de enero a septiembre de 2026 no se usan
aquí: quedan para la prueba fuera de muestra del paso 6.

Salidas: resultados/05_cerrado_<fecha>.xlsx y .png, resultados/valores_cerrado.json
y el registro.
"""
import time

import pandas as pd

import config as C
import herramientas as H

sim = H.Simulador("cerrado")
nombres = C.CALIBRAR_CERRADO
inicio = H.valores_actuales()
previos = H.leer_valores("valores_regla.json")
if previos:
    inicio.update(previos)
    print("Arranca con los valores del paso 4 (valores_regla.json).")
else:
    print("No encontré valores_regla.json: arranca con los valores actuales del modelo.")
print("Parámetros que se calibran:", ", ".join(nombres))

base = sim.correr(H.valores_actuales())
arranque = sim.correr(inicio)
error_base = H.objetivo(base, C.PESOS_CERRADO)
error_arranque = H.objetivo(arranque, C.PESOS_CERRADO)
print(f"Error ponderado: valores actuales {error_base:.2f}; valores del paso 4 {error_arranque:.2f}")

t0 = time.time()
mejor, error, traza, inicios = H.calibrar(sim, nombres, inicio, C.PESOS_CERRADO, C.N_INICIOS_CERRADO)
print(f"\nMejor error ponderado: {error:.2f} en {len(traza)} corridas ({time.time() - t0:.0f} s)")
print(inicios.to_string(index=False))

final = sim.correr(mejor)
metr = pd.concat([H.tabla_metricas(base).assign(valores="actuales"),
                  H.tabla_metricas(final).assign(valores="calibrados")], ignore_index=True)
print("\n", metr[["valores", "serie", "periodo", "MAPE", "r", "UM", "US", "UC", "amplitud", "desfase"]].to_string(index=False))
tabla_val = pd.DataFrame([dict(parametro=n, actual=H.PARAM[n]["actual"], paso_4=round(inicio[n], 4),
                               calibrado=round(mejor[n], 4), minimo=H.PARAM[n]["minimo"], maximo=H.PARAM[n]["maximo"])
                          for n in nombres])
print("\n", tabla_val.to_string(index=False))
ica = H.comparar_ica(final)
print("\nComparación con el ICA (no entra al error):")
print(ica[["anio", "indice_productores_modelo", "indice_predios_ica", "indice_capacidad_modelo",
           "indice_capacidad_ica", "ocupacion_modelo", "ocupacion_ica"]].to_string(index=False))

s = H.sello()
ruta_xlsx = C.CARPETA_RESULTADOS / f"05_cerrado_{s}.xlsx"
ruta_png = C.CARPETA_RESULTADOS / f"05_cerrado_{s}.png"
H.guardar_excel(ruta_xlsx, {"valores": tabla_val, "metricas": metr, "ica": ica, "inicios": inicios,
                            "traza": traza, "series_calibradas": final})
H.figura_ajuste(final, ruta_png, "Modelo cerrado con los valores calibrados")
ruta_json = H.guardar_valores(mejor, "valores_cerrado.json", {"calibrados": nombres, "error": error})
H.registrar("05_calibrar_cerrado", "Calibración del modelo cerrado (Powell, varios inicios)",
            {n: round(mejor[n], 4) for n in nombres},
            {"error_actuales": round(error_base, 3), "error_paso4": round(error_arranque, 3),
             "error_despues": round(error, 3), "corridas": len(traza)},
            [ruta_xlsx, ruta_png, ruta_json], sim.md5)
print(f"\nGuardado: {ruta_xlsx.name}, {ruta_png.name} y valores_cerrado.json")
