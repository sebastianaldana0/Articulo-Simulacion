# -*- coding: utf-8 -*-
"""
Paso 7. Pasar los valores calibrados a Vensim.

Escribe un archivo de texto con:
  - las constantes que cambian (nombre exacto en Vensim, valor nuevo y anterior);
  - para cada tabla con escala distinta de 1, la tabla nueva lista para pegar
    (los x divididos por la escala, que equivale a multiplicar su entrada);
  - una tabla de control: encasetamiento, precio, producción y costo en
    algunas semanas, para comprobar que Vensim da lo mismo después de pegar.

Salidas: resultados/07_valores_para_vensim_<fecha>.txt,
         comparar_con_vensim_calibrado.csv y el registro.
"""
import numpy as np

import config as C
import herramientas as H

ARCHIVO_VALORES = "valores_cerrado.json"   # o "valores_regla.json"

leidos = H.leer_valores(ARCHIVO_VALORES)
if not leidos:
    raise SystemExit(f"No encontré resultados/{ARCHIVO_VALORES}. Corre antes el paso 4 o el 5.")
valores = H.valores_actuales()
valores.update(leidos)
sim = H.Simulador("cerrado")


def numero(v):
    return f"{v:.6g}"


lineas = [f"Valores calibrados tomados de {ARCHIVO_VALORES}", ""]
lineas.append("1. Constantes (escribir el valor nuevo en el editor de ecuaciones de Vensim)")
for p in C.PARAMETROS:
    if p["tipo"] == "constante" and abs(valores[p["nombre"]] - p["actual"]) > 1e-9:
        lineas.append(f"   {p['nombre']} = {numero(valores[p['nombre']])}    (antes {numero(p['actual'])})")
lineas += ["", "2. Tablas de efecto con escala distinta de 1"]
hay_tablas = False
for p in C.PARAMETROS:
    if p["tipo"] == "escala" and abs(valores[p["nombre"]] - 1) > 1e-9:
        hay_tablas = True
        e = valores[p["nombre"]]
        xs, ys = sim.tablas[p["tabla"]]
        nx = xs / e
        rango = f"[({numero(nx.min())},{numero(min(0, ys.min()))})-({numero(nx.max())},{numero(ys.max() * 1.1)})]"
        puntos = ",".join(f"({numero(x)},{numero(y)})" for x, y in zip(nx, ys))
        lineas.append(f"   {p['nombre']} = {numero(e)}")
        lineas.append(f"   Opción A, reemplazar los puntos de la tabla '{p['tabla']}' por:")
        lineas.append(f"      {rango},{puntos}")
        lineas.append(f"   Opción B, dejar la tabla y crear la constante '{p['nombre']}' = {numero(e)}, y en la variable")
        lineas.append(f"      que usa la tabla escribir {p['tabla']}({p['nombre']}*Brecha de margen)")
        lineas.append("")
if not hay_tablas:
    lineas.append("   Ninguna (todas las escalas quedaron en 1).")

df = sim.correr(valores)
semanas = [0, 52, 104, 208, 312, 364, 403]
control = df.loc[semanas, list(C.SERIES)]
control.index = control.index.astype(int)
control.index.name = "Semana"
ruta_csv = C.CARPETA / "comparar_con_vensim_calibrado.csv"
control.to_csv(ruta_csv, sep=";", decimal=",")
lineas += ["", "3. Control: después de pegar los valores y simular en Vensim, estos números deben coincidir",
           "   (diferencias menores de 0,1 %; también están en comparar_con_vensim_calibrado.csv)", ""]
lineas.append("   Semana  " + "  ".join(f"{c:>22s}" for c in control.columns))
for t, fila in control.iterrows():
    lineas.append(f"   {int(t):6d}  " + "  ".join(f"{v:22.6g}" for v in fila.values))

s = H.sello()
ruta_txt = C.CARPETA_RESULTADOS / f"07_valores_para_vensim_{s}.txt"
ruta_txt.write_text("\n".join(lineas), encoding="utf-8")
print("\n".join(lineas))
H.registrar("07_valores_para_vensim", f"Valores para pegar en Vensim desde {ARCHIVO_VALORES}",
            {k: round(v, 6) for k, v in leidos.items()}, {"control_semana_403_encasetamiento": float(control.loc[403, "Encasetamiento"])},
            [ruta_txt, ruta_csv], sim.md5)
print(f"\nGuardado: {ruta_txt.name} y {ruta_csv.name}")

FINALES = {
    "Sensibilidad de las gallinas deseadas al margen": 1,
    "Tiempo de ajuste de gallinas": 26,
    "Tiempo de percepción del precio": 4,
    "Productores posibles": 4450,
    "Tasa de contagio": 0.012,
}
valores.update(FINALES)
leidos.update(FINALES)