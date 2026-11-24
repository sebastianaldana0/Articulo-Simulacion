# -*- coding: utf-8 -*-
"""
Funciones que usan todos los pasos: cargar el modelo, correrlo con un juego de
parámetros, calcular el error y dejar el registro.
"""
import csv
import hashlib
import json
import shutil
import sys
from datetime import datetime
from pathlib import Path

import numpy as np
import pandas as pd

import config as C
import os
os.environ.setdefault("MPLCONFIGDIR", str(C.CARPETA / ".mplconfig"))
import rapido  # noqa: F401  (acelera las tablas; tiene que ir antes de pysd.load)
import pysd


import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

PARAM = {p["nombre"]: p for p in C.PARAMETROS}
C.CARPETA_RESULTADOS.mkdir(exist_ok=True)


# ============================================================ modelo
def _md5(ruta):
    return hashlib.md5(Path(ruta).read_bytes()).hexdigest()


def preparar_modelo(forzar=False):
    """Copia el .mdl de Vensim a la carpeta modelo/ y lo traduce con PySD.

    Si el .mdl de la carpeta del artículo cambió desde la última traducción,
    lo vuelve a copiar y traducir. Devuelve la ruta del .py y el md5 del .mdl.
    """
    origen = Path(C.RUTA_MODELO_VENSIM)
    if not origen.exists():
        sys.exit(f"No encuentro el modelo de Vensim en {origen}. Revisa RUTA_MODELO_VENSIM en config.py.")
    C.CARPETA_MODELO.mkdir(exist_ok=True)
    copia = C.CARPETA_MODELO / "modelo_calibracion.mdl"
    traducido = C.CARPETA_MODELO / "modelo_calibracion.py"
    md5 = _md5(origen)
    if forzar or not traducido.exists() or not copia.exists() or _md5(copia) != md5:
        shutil.copy2(origen, copia)
        print(f"Traduciendo {origen.name} con PySD...")
        pysd.read_vensim(str(copia))
    return traducido, md5


class Simulador:
    """Corre el modelo en uno de dos modos.

    modo = "cerrado": el modelo completo, como en Vensim.
    modo = "regla": prueba parcial de la regla de encasetamiento. Las variables
        de config.SUSTITUCIONES_REGLA (aquí, el precio de mercado) se reemplazan
        por sus series observadas; el resto del modelo se simula.
    """

    def __init__(self, modo="cerrado"):
        if modo not in ("cerrado", "regla"):
            raise ValueError("modo debe ser 'cerrado' o 'regla'")
        self.modo = modo
        self.ruta_py, self.md5 = preparar_modelo()
        self.modelo = pysd.load(str(self.ruta_py))
        # tablas originales, para poder escalarlas
        self.tablas = {}
        for p in C.PARAMETROS:
            if p["tipo"] == "escala":
                d = self.modelo.get_series_data(p["tabla"])
                self.tablas[p["tabla"]] = (np.asarray(d["lookup_dim"].values, float),
                                           np.asarray(d.values, float).ravel())
        self.columnas = sorted(set(list(C.SERIES) + list(C.SERIES.values()) + [
            "Gallinas en postura", "Productores activos", "Capacidad de galpones", "Capacidad ociosa"]))
        self.sustituciones = {}
        if modo == "regla":
            # Variables que se reemplazan por su serie observada (config.SUSTITUCIONES_REGLA).
            # Después del último dato la serie queda con su último valor.
            obs = list(C.SUSTITUCIONES_REGLA.values())
            base = pysd.load(str(self.ruta_py)).run(return_columns=obs)
            self.sustituciones = {var: base[o].ffill().bfill() for var, o in C.SUSTITUCIONES_REGLA.items()}
        self.n_corridas = 0

    def parametros(self, valores):
        """Convierte un diccionario {nombre: valor} en los params de PySD.

        Siempre manda todos los parámetros de config.PARAMETROS (con su valor
        actual si no vienen en 'valores'), porque PySD recuerda los cambios
        entre corridas.
        """
        params = {}
        for p in C.PARAMETROS:
            v = float(valores.get(p["nombre"], p["actual"]))
            if p["tipo"] == "constante":
                params[p["nombre"]] = v
            else:
                xs, ys = self.tablas[p["tabla"]]
                params[p["tabla"]] = pd.Series(ys, index=xs / v)
        params.update(self.sustituciones)
        return params

    def correr(self, valores=None, final=None):
        valores = valores or {}
        final = final or (C.SEMANA_FIN_PRUEBA if self.modo == "regla" else None)
        kw = dict(params=self.parametros(valores), return_columns=self.columnas)
        if final:
            kw["final_time"] = final
        self.n_corridas += 1
        return self.modelo.run(**kw)


# ============================================================ métricas
def a_mensual(serie):
    """Promedio mensual de una serie semanal (cada semana va al mes de su día central)."""
    t = np.asarray(serie.index, float)
    fechas = pd.Timestamp(C.FECHA_SEMANA_0) + pd.to_timedelta(t * 7 + 3, unit="D")
    return pd.Series(serie.values, index=fechas.to_period("M")).groupby(level=0).mean()


def ventana(serie, desde, hasta):
    return serie.loc[(serie.index >= desde) & (serie.index <= hasta)]


def _sin_tendencia(y):
    x = np.arange(len(y))
    a, b = np.polyfit(x, y, 1)
    return y - (a * x + b)


def _periodo(y, minimo=6):
    """Primer máximo de la autocorrelación después de 'minimo' meses (en meses)."""
    y = y - y.mean()
    n = len(y)
    acf = np.array([np.corrcoef(y[:-k], y[k:])[0, 1] if k else 1.0 for k in range(n // 2)])
    for k in range(minimo, len(acf) - 1):
        if acf[k] > 0 and acf[k] >= acf[k - 1] and acf[k] >= acf[k + 1]:
            return float(k)
    return float("nan")


def metricas(sim, obs, desde, hasta, mensual=True):
    """Error de una serie en la ventana [desde, hasta] (semanas).

    MAPE (%), r, Theil (U^M sesgo, U^S varianza, U^C covarianza) y tres
    medidas del patrón: razón de amplitud (desviación sin tendencia simulada /
    observada), desfase en meses (positivo = el modelo va atrasado) y período
    de la autocorrelación.
    """
    s, o = ventana(sim, desde, hasta), ventana(obs, desde, hasta)
    if mensual:
        s, o = a_mensual(s), a_mensual(o)
    s, o = np.asarray(s, float), np.asarray(o, float)
    if not np.all(np.isfinite(s)):
        return dict(MAPE=np.inf, r=np.nan, UM=np.nan, US=np.nan, UC=np.nan,
                    amplitud=np.nan, desfase=np.nan, periodo_sim=np.nan, periodo_obs=np.nan)
    mape = float(np.mean(np.abs(s - o) / np.abs(o)) * 100)
    r = float(np.corrcoef(s, o)[0, 1])
    mse = float(np.mean((s - o) ** 2))
    ss, so = s.std(), o.std()
    um = (s.mean() - o.mean()) ** 2 / mse
    us = (ss - so) ** 2 / mse
    uc = 2 * (1 - r) * ss * so / mse
    sd, od = _sin_tendencia(s), _sin_tendencia(o)
    amp = float(sd.std() / od.std())
    desfase = periodo_sim = periodo_obs = float("nan")
    if len(s) >= 24:  # con menos de dos años no tiene sentido medir desfase ni período
        rezagos = list(range(-12, 13))
        corr = []
        for k in rezagos:  # k > 0: lo simulado ocurre k meses después de lo observado
            if k >= 0:
                corr.append(np.corrcoef(sd[k:], od[:len(od) - k])[0, 1])
            else:
                corr.append(np.corrcoef(sd[:k], od[-k:])[0, 1])
        desfase = float(rezagos[int(np.nanargmax(corr))])
        periodo_sim, periodo_obs = _periodo(sd), _periodo(od)
    return dict(MAPE=round(mape, 3), r=round(r, 3), UM=round(um, 3), US=round(us, 3), UC=round(uc, 3),
                amplitud=round(amp, 3), desfase=desfase, periodo_sim=periodo_sim, periodo_obs=periodo_obs)


def objetivo(df, pesos):
    """Error ponderado (MAPE mensual) en la ventana de calibración."""
    total = 0.0
    for var, w in pesos.items():
        m = metricas(df[var], df[C.SERIES[var]], C.SEMANA_INICIO_CALIBRACION, C.SEMANA_FIN_CALIBRACION)
        total += w * m["MAPE"]
    return total


def tabla_metricas(df, series=None):
    """Métricas de calibración (2020-2025) y de prueba (ene-sep 2026) por serie."""
    filas = []
    for var in (series or C.SERIES):
        for nombre, (a, b) in {C.ETIQUETA_CALIBRACION: (C.SEMANA_INICIO_CALIBRACION, C.SEMANA_FIN_CALIBRACION),
                               C.ETIQUETA_PRUEBA: (C.SEMANA_INICIO_PRUEBA, C.SEMANA_FIN_PRUEBA)}.items():
            m = metricas(df[var], df[C.SERIES[var]], a, b)
            if nombre == C.ETIQUETA_PRUEBA:  # nueve meses no alcanzan para período ni desfase
                m.update(desfase=np.nan, periodo_sim=np.nan, periodo_obs=np.nan)
            filas.append(dict(serie=var, periodo=nombre, **m))
    return pd.DataFrame(filas)


def comparar_ica(df):
    """Modelo frente al censo del ICA a comienzos de cada año (índices 2019 = 1)."""
    filas = []
    for anio, d in C.ICA.items():
        t = int(round((pd.Timestamp(f"{anio}-01-01") - pd.Timestamp(C.FECHA_SEMANA_0)).days / 7))
        fila = df.loc[t]
        filas.append(dict(anio=anio, semana=t,
                          productores_modelo=round(float(fila["Productores activos"])),
                          predios_ica=d["predios"],
                          capacidad_modelo=round(float(fila["Capacidad de galpones"])),
                          capacidad_ica=d["instalada"],
                          ocupacion_modelo=round(float(fila["Gallinas en postura"] / fila["Capacidad de galpones"]), 3),
                          ocupacion_ica=round(d["ocupada"] / d["instalada"], 3)))
    out = pd.DataFrame(filas)
    out["indice_productores_modelo"] = (out.productores_modelo / out.productores_modelo.iloc[0]).round(3)
    out["indice_predios_ica"] = (out.predios_ica / out.predios_ica.iloc[0]).round(3)
    out["indice_capacidad_modelo"] = (out.capacidad_modelo / out.capacidad_modelo.iloc[0]).round(3)
    out["indice_capacidad_ica"] = (out.capacidad_ica / out.capacidad_ica.iloc[0]).round(3)
    return out


# ============================================================ búsqueda
def muestra_lhs(n, k, semilla):
    """Muestra de hipercubo latino en [0, 1]^k."""
    rng = np.random.default_rng(semilla)
    u = (rng.random((n, k)) + np.arange(n)[:, None]) / n
    for j in range(k):
        u[:, j] = u[rng.permutation(n), j]
    return u


def de_unitario(nombres, u):
    return {n: PARAM[n]["minimo"] + float(ui) * (PARAM[n]["maximo"] - PARAM[n]["minimo"]) for n, ui in zip(nombres, u)}


def a_unitario(nombres, valores):
    return np.array([(valores[n] - PARAM[n]["minimo"]) / (PARAM[n]["maximo"] - PARAM[n]["minimo"]) for n in nombres])


def valores_actuales():
    return {p["nombre"]: p["actual"] for p in C.PARAMETROS}


def calibrar(sim, nombres, valores_inicio, pesos, n_inicios, semilla=C.SEMILLA):
    """Busca los valores de 'nombres' que minimizan el error ponderado.

    Usa el método de Powell con límites (el mismo algoritmo del optimizador de
    Vensim Professional y DSS) sobre los parámetros llevados a [0, 1]. El
    primer punto de partida son los valores de inicio; los demás salen al
    azar (hipercubo latino) para no quedarse en un mínimo local.
    Guarda cada evaluación en la traza: ese es el registro de la búsqueda.
    """
    from scipy.optimize import minimize

    traza = []
    inicio_actual = {"k": 0}

    def f(u):
        u = np.clip(u, 0, 1)
        valores = dict(valores_inicio)
        valores.update(de_unitario(nombres, u))
        try:
            error = objetivo(sim.correr(valores), pesos)
        except Exception:
            error = np.inf
        if not np.isfinite(error):
            error = 1e6
        traza.append(dict(inicio=inicio_actual["k"], evaluacion=len(traza) + 1,
                          **{n: valores[n] for n in nombres}, error=error))
        if len(traza) % 50 == 0:
            print(f"    {len(traza)} corridas; mejor error hasta ahora {min(t['error'] for t in traza):.3f}")
        return error

    puntos = [np.clip(a_unitario(nombres, valores_inicio), 0, 1)]
    if n_inicios > 1:
        puntos += list(muestra_lhs(n_inicios - 1, len(nombres), semilla))
    resumen = []
    for k, u0 in enumerate(puntos, start=1):
        inicio_actual["k"] = k
        print(f"  Punto de partida {k} de {len(puntos)}")
        res = minimize(f, u0, method="Powell", bounds=[(0, 1)] * len(nombres),
                       options={"maxfev": C.MAX_EVALUACIONES, "xtol": 1e-3, "ftol": 1e-4})
        de_este = [t for t in traza if t["inicio"] == k]
        mejor_k = min(de_este, key=lambda t: t["error"])
        resumen.append(dict(inicio=k, mejor_error=round(float(mejor_k["error"]), 4), corridas=len(de_este),
                            convergio=bool(res.success),
                            **{f"inicio: {n}": round(de_unitario(nombres, u0)[n], 4) for n in nombres},
                            **{n: round(mejor_k[n], 4) for n in nombres}))
    traza = pd.DataFrame(traza)
    mejor = traza.loc[traza.error.idxmin()]
    valores_mejor = dict(valores_inicio)
    valores_mejor.update({n: float(mejor[n]) for n in nombres})
    return valores_mejor, float(mejor.error), traza, pd.DataFrame(resumen)


# ============================================================ archivos y registro
def sello():
    return datetime.now().strftime("%Y%m%d_%H%M%S")


def guardar_valores(valores, nombre_archivo, extra=None):
    ruta = C.CARPETA_RESULTADOS / nombre_archivo
    datos = {"fecha": datetime.now().isoformat(timespec="seconds"), "valores": valores}
    if extra:
        datos.update(extra)
    ruta.write_text(json.dumps(datos, ensure_ascii=False, indent=2), encoding="utf-8")
    return ruta


def leer_valores(nombre_archivo):
    ruta = C.CARPETA_RESULTADOS / nombre_archivo
    if not ruta.exists():
        return None
    return json.loads(ruta.read_text(encoding="utf-8"))["valores"]


def registrar(script, descripcion, valores, resumen, archivos, md5):
    """Agrega una línea al registro de la calibración (registro_calibracion.csv)."""
    nuevo = not C.REGISTRO.exists()
    with open(C.REGISTRO, "a", newline="", encoding="utf-8-sig") as f:
        w = csv.writer(f, delimiter=";")
        if nuevo:
            w.writerow(["fecha", "script", "descripcion", "md5_modelo", "parametros", "resultado", "archivos"])
        w.writerow([datetime.now().isoformat(timespec="seconds"), script, descripcion, md5,
                    json.dumps(valores, ensure_ascii=False), json.dumps(resumen, ensure_ascii=False),
                    " | ".join(str(Path(a).name) for a in archivos)])


def figura_ajuste(df, ruta, titulo, series=("Encasetamiento", "Precio de mercado")):
    fig, ejes = plt.subplots(len(series), 1, figsize=(10, 3.4 * len(series)), sharex=True)
    ejes = np.atleast_1d(ejes)
    for ax, var in zip(ejes, series):
        d = df.loc[:C.SEMANA_FIN_PRUEBA]
        ax.plot(d.index, d[C.SERIES[var]], color="0.35", lw=1.2, label="Observado")
        ax.plot(d.index, d[var], color="#1f5fa8", lw=1.6, label="Simulado")
        ax.axvline(C.SEMANA_INICIO_CALIBRACION - 0.5, color="0.6", ls=":", lw=1)
        ax.axvline(C.SEMANA_FIN_CALIBRACION + 0.5, color="0.6", ls="--", lw=1)
        ax.set_title(var, loc="left", fontsize=10)
        ax.grid(alpha=0.25)
        ax.legend(fontsize=8, frameon=False)
    ejes[-1].set_xlabel("Semana del modelo (0 = 1-ene-2019). Calibración entre las líneas: punteada = fin del "
                        "calentamiento (semana 52), discontinua = fin de 2025")
    fig.suptitle(titulo, fontsize=11)
    fig.tight_layout()
    fig.savefig(ruta, dpi=150)
    plt.close(fig)


def guardar_excel(ruta, hojas):
    with pd.ExcelWriter(ruta, engine="openpyxl") as xl:
        for nombre, tabla in hojas.items():
            tabla.to_excel(xl, sheet_name=nombre[:31], index=not isinstance(tabla.index, pd.RangeIndex))
