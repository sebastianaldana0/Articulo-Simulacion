# -*- coding: utf-8 -*-
"""
Paso 2. Comprueba que PySD da lo mismo que Vensim.

Antes de correr este script:
  1. En Vensim, abre Modelo final semanal.mdl (el de esta carpeta) y simula sin
     cambiar nada.
  2. Selecciona Encasetamiento en el diagrama y abre la herramienta de
     análisis "Table Time Down" (sirve también "Table").
  3. Copia la tabla (botón de copiar de esa ventana) y pégala en el Bloc de
     notas. Repite con Precio de mercado, Producción de huevos y Costo unitario,
     pegando cada tabla debajo de la anterior en el mismo archivo.
  4. Guarda el archivo como vensim_base.txt en esta carpeta. No lo pegues en
     Excel: Excel en español cambia los puntos decimales.

El script lee ese archivo, corre el modelo en PySD y compara semana por semana.
Una diferencia relativa menor de 0,1 % se considera igual (Vensim guarda los
números con 6 cifras significativas).
"""
import sys

import numpy as np
import pandas as pd

import config as C
import herramientas as H

ARCHIVO = C.CARPETA / "vensim_base.txt"
if not ARCHIVO.exists():
    sys.exit("Falta vensim_base.txt (lee las instrucciones al comienzo de este script).")

try:
    texto = ARCHIVO.read_text(encoding="utf-8-sig")
except UnicodeDecodeError:  # Bloc de notas guardado como ANSI
    texto = ARCHIVO.read_text(encoding="cp1252")
lineas = [l.rstrip("\n\r") for l in texto.splitlines() if l.strip()]
celdas = [l.split("\t") for l in lineas]


def es_tiempo(texto):
    t = texto.strip().lower()
    return t.startswith("time") or t.startswith("tiempo")


def numero(texto):
    texto = texto.strip().replace(",", ".")
    try:
        return float(texto)
    except ValueError:
        return np.nan


def limpiar(nombre):
    return nombre.split(":")[0].split("(")[0].strip()


def leer_bloque(bloque):
    if len(bloque) > 1 and not np.isnan(numero(bloque[1][0])):
        # tiempo hacia abajo (Table Time Down): primera fila = encabezados
        encabezados = [limpiar(c) for c in bloque[0]]
        d = pd.DataFrame([[numero(c) for c in fila[:len(encabezados)]] for fila in bloque[1:]],
                         columns=encabezados[:max(len(f) for f in bloque[1:])])
        return d.set_index(d.columns[0])
    # tiempo hacia la derecha (Table): primera fila = tiempos, primera columna = nombres
    tiempos = [numero(c) for c in bloque[0][1:]]
    return pd.DataFrame({limpiar(f[0]): [numero(c) for c in f[1:]] for f in bloque[1:]}, index=tiempos)


# El archivo puede traer una tabla con todas las variables o varias tablas
# pegadas una debajo de otra (una por variable); cada una empieza con "Time".
bloques, actual = [], []
for fila in celdas:
    if es_tiempo(fila[0]) and actual:
        bloques.append(actual)
        actual = []
    actual.append(fila)
bloques.append(actual)
datos = pd.concat([leer_bloque(b) for b in bloques], axis=1)
datos = datos.loc[:, ~datos.columns.duplicated()]
datos = datos[~datos.index.isna()]

sim = H.Simulador("cerrado")
df = sim.correr()
filas = []
for var in datos.columns:
    if var not in df.columns:
        print(f"  (se omite '{var}': no está entre las variables que guarda el script)")
        continue
    comunes = [t for t in datos.index if t in df.index]
    v = datos.loc[comunes, var].astype(float).values
    p = df.loc[comunes, var].astype(float).values
    rel = np.abs(p - v) / np.maximum(np.abs(v), 1e-12)
    filas.append(dict(variable=var, semanas_comparadas=len(comunes),
                      diferencia_relativa_maxima_pct=round(float(np.nanmax(rel)) * 100, 4),
                      semana_de_la_maxima=float(np.array(comunes)[int(np.nanargmax(rel))])))
tabla = pd.DataFrame(filas)
print(tabla.to_string(index=False))
iguales = bool(len(tabla)) and bool((tabla.diferencia_relativa_maxima_pct < 0.1).all())
print("\nResultado:", "PySD y Vensim coinciden." if iguales else "Hay diferencias: avísale al grupo antes de calibrar.")

s = H.sello()
ruta = C.CARPETA_RESULTADOS / f"02_comparacion_vensim_{s}.xlsx"
H.guardar_excel(ruta, {"comparacion": tabla, "vensim": datos})
H.registrar("02_comparar_con_vensim", "Comparación de la corrida base de PySD con la exportada de Vensim",
            {}, {"coinciden": iguales, **{r.variable: r.diferencia_relativa_maxima_pct for r in tabla.itertuples()}},
            [ruta, ARCHIVO], sim.md5)
