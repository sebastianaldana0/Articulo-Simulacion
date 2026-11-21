# -*- coding: utf-8 -*-
"""
Configuración de la calibración. Es el único archivo que hay que editar
entre un paso y otro (sobre todo las listas CALIBRAR_REGLA y CALIBRAR_CERRADO
después del tamizaje).
"""
import os
from pathlib import Path

# ---------------------------------------------------------------- rutas
CARPETA = Path(__file__).resolve().parent
# El modelo de Vensim que se calibra. Por defecto, el que está en la carpeta
# del artículo, un nivel arriba de esta carpeta.
RUTA_MODELO_VENSIM = CARPETA.parent / "Modelo actual.mdl"
CARPETA_MODELO = CARPETA / "modelo"          # copia traducida por PySD
CARPETA_RESULTADOS = CARPETA / "resultados"   # Excel y gráficas de cada paso
REGISTRO = CARPETA / "registro_calibracion.csv"

# ---------------------------------------------------------------- tiempo
# Semana t = 7 días desde el 1-ene-2019 + 7t (igual que el reloj de Vensim).
FECHA_SEMANA_0 = "2019-01-01"
SEMANA_FIN_CALIBRACION = 364   # semana del 23 al 29 de diciembre de 2025
SEMANA_INICIO_PRUEBA = 365     # 30-dic-2025
SEMANA_FIN_PRUEBA = 403        # 22 al 28 de septiembre de 2026 (último dato)

# ---------------------------------------------------------------- series
# Variable simulada -> variable observada (ambas existen en el modelo).
SERIES = {
    "Encasetamiento": "Encasetamiento observado",
    "Precio de mercado": "Precio de mercado observado",
    "Producción de huevos": "Producción observada",
    "Costo unitario": "Costo Fenavi observado",
}
# Peso de cada serie en la función de error del modelo cerrado.
PESOS_CERRADO = {"Encasetamiento": 0.5, "Precio de mercado": 0.5}
# En la prueba parcial de la regla, el precio y el costo son datos: solo
# queda el encasetamiento.
PESOS_REGLA = {"Encasetamiento": 1.0}

# ---------------------------------------------------------------- parámetros
# tipo "constante": se cambia el valor de la constante del modelo.
# tipo "escala": multiplica la entrada de una tabla de efecto. En el modelo
#   equivale a escribir Tabla(escala * Brecha de margen). Con 1 la tabla queda
#   como está. PySD lo aplica dividiendo los x de la tabla por la escala.
# clase: K = se calibra; S = supuesto, solo entra al tamizaje.
PARAMETROS = [
    # ---- regla de encasetamiento
    dict(nombre="Tiempo de percepción del precio", tipo="constante", actual=6, minimo=4, maximo=52, clase="K",
         nota="Fenaviquín 440, p. 8: el ajuste toma cerca de seis meses."),
    dict(nombre="Tiempo de ajuste de gallinas", tipo="constante", actual=18, minimo=8, maximo=26, clase="K",
         nota="Sin fuente directa."),
    dict(nombre="Sensibilidad de las gallinas deseadas al margen", tipo="escala",
         tabla="Efecto del margen en las gallinas deseadas", actual=1, minimo=0.1, maximo=2, clase="K",
         nota="Escala la entrada de la tabla de efecto."),
    dict(nombre="Sensibilidad de la vida productiva al margen", tipo="escala",
         tabla="Efecto del margen en la vida productiva", actual=1, minimo=0.1, maximo=3, clase="K",
         nota="Fenaviquín 440, p. 8: reducir el ciclo productivo es una vía de ajuste."),
    # ---- productores
    dict(nombre="Productores posibles", tipo="constante", actual=6000, minimo=3000, maximo=12000, clase="K",
         nota="Sin fuente."),
    dict(nombre="Tasa de contagio", tipo="constante", actual=0.08, minimo=0.01, maximo=0.3, clase="K",
         nota="Objetivo: predios del ICA."),
    dict(nombre="Sensibilidad de la entrada al margen", tipo="escala",
         tabla="Efecto del margen en la entrada", actual=1, minimo=0.1, maximo=3, clase="K",
         nota="Escala la entrada de la tabla de efecto."),
    # ---- galpones
    dict(nombre="Tiempo para decidir ampliaciones", tipo="constante", actual=15, minimo=5, maximo=52, clase="K",
         nota="Objetivo: capacidad instalada del ICA."),
    dict(nombre="Fracción de galpones que se desmontan", tipo="constante", actual=0.2, minimo=0.0, maximo=0.5, clase="K",
         nota="Objetivo: capacidad instalada del ICA."),
    dict(nombre="Tiempo para ocupar galpones", tipo="constante", actual=20, minimo=5, maximo=52, clase="K",
         nota="Objetivo: ocupación del ICA."),
    dict(nombre="Sensibilidad de la ocupación al margen", tipo="escala",
         tabla="Efecto del margen bajo en la ocupación", actual=1, minimo=0.1, maximo=3, clase="K",
         nota="Escala la entrada de la tabla de efecto."),
    # ---- supuestos (solo tamizaje)
    dict(nombre="Tiempo de reposición", tipo="constante", actual=4, minimo=2, maximo=8, clase="S", nota=""),
    dict(nombre="Tiempo para percibir la demanda", tipo="constante", actual=52, minimo=26, maximo=104, clase="S", nota=""),
    dict(nombre="Fracción de la línea de suministro considerada", tipo="constante", actual=0.34, minimo=0.0, maximo=1.0,
         clase="S", nota="Clase F (Sterman, 1989); aquí solo para ver cuánto pesa."),
    dict(nombre="Tiempo de salida", tipo="constante", actual=52, minimo=26, maximo=104, clase="S", nota=""),
    dict(nombre="Tiempo de construcción", tipo="constante", actual=26, minimo=13, maximo=52, clase="S", nota=""),
    dict(nombre="Tiempo de retiro de utilidades", tipo="constante", actual=26, minimo=13, maximo=52, clase="S", nota=""),
    dict(nombre="Participación del productor en el precio", tipo="constante", actual=0.83, minimo=0.78, maximo=0.92,
         clase="S", nota="Por debajo de 0,78 la caja de referencia se vuelve casi cero."),
]

# Parámetros que se calibran en cada paso. Ajustar después del tamizaje (paso 3).
CALIBRAR_REGLA = [
    "Sensibilidad de las gallinas deseadas al margen",
    "Tiempo de ajuste de gallinas",
    "Tiempo de percepción del precio",
]
CALIBRAR_CERRADO = CALIBRAR_REGLA + [
    "Productores posibles",
    "Tasa de contagio",
]
# ---------------------------------------------------------------- búsqueda
SEMILLA = 2026
N_TAMIZAJE = 300          # corridas del tamizaje (unos 2 a 4 minutos)
N_INICIOS_REGLA = 4       # puntos de partida del optimizador en el paso 4
N_INICIOS_CERRADO = 3     # puntos de partida en el paso 5
MAX_EVALUACIONES = 300    # corridas máximas por punto de partida
N_PUNTOS_PERFIL = 15      # valores por parámetro en los perfiles del paso 6

# Modo de prueba rápida (solo para revisar que los scripts corren).
if os.environ.get("PRUEBA_RAPIDA") == "1":
    N_TAMIZAJE, N_INICIOS_REGLA, N_INICIOS_CERRADO, MAX_EVALUACIONES, N_PUNTOS_PERFIL = 12, 1, 1, 20, 3

# ---------------------------------------------------------------- datos del ICA
# Censo a comienzos de cada año (claude/huevo-ica-censo-postura.md). Se usan
# para comparar, no entran a la función de error.
ICA = {
    2019: dict(predios=2323, instalada=69577275, ocupada=60814199),
    2020: dict(predios=2269, instalada=72483562, ocupada=61167920),
    2021: dict(predios=2278, instalada=70934396, ocupada=62049893),
    2022: dict(predios=2462, instalada=73385933, ocupada=65634337),
    2023: dict(predios=2557, instalada=74786615, ocupada=61510802),
    2024: dict(predios=2451, instalada=72961498, ocupada=61647064),
    2025: dict(predios=2558, instalada=80396592, ocupada=67328627),
}
