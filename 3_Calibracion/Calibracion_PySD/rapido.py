# -*- coding: utf-8 -*-
"""
Acelera las tablas (lookups) de PySD.

PySD interpola las tablas con xarray, y con tablas de 471 puntos eso se lleva
casi todo el tiempo de la corrida (unos 30 s por corrida). Aquí se reemplaza
esa interpolación por numpy.interp, que hace lo mismo que Vensim: línea recta
entre puntos y valor constante fuera del rango. Probado con PySD 3.14.3: los
resultados son idénticos y la corrida baja a menos de medio segundo.

Solo hay que importarlo antes de cargar el modelo (herramientas.py ya lo hace).
"""
import warnings

import numpy as np
from pysd.py_backend import lookups as _lookups

_original = _lookups.Lookups._call


def _call_rapido(self, data, x, final_subs=None):
    # Solo tablas sin subíndices y con x numérico; lo demás sigue por PySD.
    if getattr(self, "is_float", False) and not hasattr(x, "dims"):
        if getattr(self, "interp", None) not in ("extrapolate", "hold_backward"):
            cache = getattr(self, "_cache_numpy", None)
            if cache is None or cache[0] is not data:
                xs = np.asarray(data["lookup_dim"].values, dtype=float)
                ys = np.asarray(data.values, dtype=float).ravel()
                cache = (data, xs, ys)
                self._cache_numpy = cache
            return float(np.interp(float(x), cache[1], cache[2]))
    return _original(self, data, x, final_subs)


_lookups.Lookups._call = _call_rapido
warnings.filterwarnings("ignore")
