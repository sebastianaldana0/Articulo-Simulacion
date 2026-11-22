# -*- coding: utf-8 -*-
"""
Configuración de la calibración de Modelo final semanal.mdl (modelo v4 de los
compañeros con las tablas semanales). Es el único archivo que hay que editar
entre un paso y otro (sobre todo las listas CALIBRAR_REGLA y CALIBRAR_CERRADO
después del tamizaje).

Esta carpeta no lee ni escribe nada de Calibracion_PySD. El paso 8 abre
Modelo calibrado.mdl solo para leerlo: lo copia a modelo_comparacion/ y lo
traduce ahí.
"""
import os
from pathlib import Path

# ---------------------------------------------------------------- rutas
CARPETA = Path(__file__).resolve().parent
# El modelo que se calibra: está en esta misma carpeta.
RUTA_MODELO_VENSIM = CARPETA / "Modelo final semanal.mdl"
CARPETA_MODELO = CARPETA / "modelo"          # copia traducida por PySD
CARPETA_RESULTADOS = CARPETA / "resultados"   # Excel y gráficas de cada paso
REGISTRO = CARPETA / "registro_calibracion.csv"
# Para el paso 8: nuestro modelo calibrado (solo lectura).
RUTA_MODELO_PROPIO = CARPETA.parent / "Modelo calibrado.mdl"

# ---------------------------------------------------------------- tiempo
# Semana t = 7 días desde el 1-ene-2019 + 7t (igual que el reloj de Vensim).
FECHA_SEMANA_0 = "2019-01-01"
# Hasta la semana 51 el encasetamiento copia el dato observado (calentamiento:
# Encasetamiento = IF THEN ELSE(Time < 52, observado, regla)). La 52 es la
# primera que decide el modelo; su día central es el 3-ene-2020, así que la
# ventana arranca en enero de 2020 completo.
SEMANA_INICIO_CALIBRACION = 52
SEMANA_FIN_CALIBRACION = 364   # semana del 23 al 29 de diciembre de 2025
SEMANA_INICIO_PRUEBA = 365     # 30-dic-2025
SEMANA_FIN_PRUEBA = 403        # 22 al 28 de septiembre de 2026 (último dato)
ETIQUETA_CALIBRACION = "Calibración 2020-2025"
ETIQUETA_PRUEBA = "Prueba ene-sep 2026"

# ---------------------------------------------------------------- series
# Variable simulada -> variable observada (ambas existen en el modelo). Las
# tablas observadas son las mismas semanas de Modelo actual.mdl.
SERIES = {
    "Encasetamiento": "Encasetamiento observado",
    "Precio de mercado": "Precio de mercado observado",
    "Producción de huevos": "Producción observada",
    "Costo unitario": "Costo Fenavi observado",
}
# Peso de cada serie en la función de error del modelo cerrado.
PESOS_CERRADO = {"Encasetamiento": 0.5, "Precio de mercado": 0.5}
# En la prueba parcial de la regla solo queda el encasetamiento.
PESOS_REGLA = {"Encasetamiento": 1.0}
# Prueba parcial (paso 4): variables que se reemplazan por su serie observada.
# En este modelo el costo de la historia ya es el de Fenavi (Interruptor de
# costo observado = 1), así que basta con el precio.
SUSTITUCIONES_REGLA = {"Precio de mercado": "Precio de mercado observado"}

# ---------------------------------------------------------------- parámetros
# tipo "constante": se cambia el valor de la constante del modelo.
# tipo "escala": multiplica la entrada de una tabla de efecto. En el modelo
#   equivale a escribir Tabla(escala * Brecha de margen). Con 1 la tabla queda
#   como está. PySD lo aplica dividiendo los x de la tabla por la escala.
# clase: K = se calibra; S = supuesto, solo entra al tamizaje.
# actual = valor que trae Modelo final.mdl. Los rangos son los mismos de la
# calibración de nuestro modelo, para que la comparación sea pareja; cuando el
# valor de los compañeros queda por fuera, se anota en la nota.
PARAMETROS = [
    # ---- regla de encasetamiento
    dict(nombre="Tiempo de percepción del precio", tipo="constante", actual=26, minimo=4, maximo=52, clase="K",
         nota="Mismo rango de la primera calibración."),
    dict(nombre="Tiempo de ajuste de gallinas", tipo="constante", actual=104, minimo=8, maximo=26, clase="K",
         nota="Tope de 26 (Fenaviquín 440, p. 8: seis meses). El 104 de los compañeros queda por fuera."),
    dict(nombre="Sensibilidad de las gallinas deseadas al margen", tipo="escala",
         tabla="Efecto del margen en las gallinas deseadas", actual=1, minimo=0.1, maximo=2, clase="K",
         nota="Escala la entrada de la tabla de efecto."),
    dict(nombre="Sensibilidad de la vida productiva al margen", tipo="escala",
         tabla="Efecto del margen en la vida productiva", actual=1, minimo=0.1, maximo=3, clase="K",
         nota="Fenaviquín 440, p. 8: reducir el ciclo productivo es una vía de ajuste."),
    # ---- productores
    dict(nombre="Productores posibles", tipo="constante", actual=2669, minimo=3000, maximo=12000, clase="K",
         nota="El 2.669 de los compañeros queda por debajo del rango."),
    dict(nombre="Tasa de contagio", tipo="constante", actual=0.08, minimo=0.01, maximo=0.3, clase="K",
         nota="Objetivo: predios del ICA."),
    dict(nombre="Sensibilidad de la entrada al margen", tipo="escala",
         tabla="Efecto del margen en la entrada", actual=1, minimo=0.1, maximo=3, clase="K",
         nota="Escala la entrada de la tabla de efecto."),
    # ---- galpones
    dict(nombre="Tiempo para decidir ampliaciones", tipo="constante", actual=104, minimo=5, maximo=52, clase="K",
         nota="El 104 de los compañeros queda por fuera."),
    dict(nombre="Fracción de galpones que se desmontan", tipo="constante", actual=1, minimo=0.0, maximo=0.5, clase="K",
         nota="El 1 de los compañeros queda por fuera."),
    dict(nombre="Tiempo para ocupar galpones", tipo="constante", actual=104, minimo=5, maximo=52, clase="K",
         nota="El 104 de los compañeros queda por fuera."),
    dict(nombre="Sensibilidad de la ocupación al margen", tipo="escala",
         tabla="Efecto del margen bajo en la ocupación", actual=1, minimo=0.1, maximo=3, clase="K",
         nota="Escala la entrada de la tabla de efecto."),
    # ---- supuestos (solo tamizaje)
    dict(nombre="Tiempo de reposición", tipo="constante", actual=4, minimo=2, maximo=8, clase="S", nota=""),
    dict(nombre="Tiempo para percibir la demanda", tipo="constante", actual=52, minimo=26, maximo=104, clase="S", nota=""),
    dict(nombre="Fracción de la línea de suministro base", tipo="constante", actual=0.34, minimo=0.0, maximo=1.0,
         clase="S", nota="Clase F (Sterman, 1989); aquí solo para ver cuánto pesa."),
    dict(nombre="Tiempo de salida", tipo="constante", actual=22, minimo=26, maximo=104, clase="S",
         nota="En Modelo final.mdl es K (22); aquí S con el rango de la primera calibración."),
    dict(nombre="Tiempo de construcción", tipo="constante", actual=26, minimo=13, maximo=52, clase="S", nota=""),
    dict(nombre="Tiempo de retiro de utilidades", tipo="constante", actual=26, minimo=13, maximo=52, clase="S", nota=""),
    dict(nombre="Participación del productor en el precio", tipo="constante", actual=0.79, minimo=0.78, maximo=0.92,
         clase="S", nota="Mismo rango de la primera calibración."),
    # ---- supuestos propios de este modelo (solo tamizaje)
    dict(nombre="Horizonte del pronóstico de demanda", tipo="constante", actual=52, minimo=26, maximo=104, clase="S",
         nota="Solo existe en este modelo (FORECAST). Rango provisional."),
    dict(nombre="Semanas de capital de trabajo", tipo="constante", actual=8, minimo=4, maximo=16, clase="S",
         nota="Solo existe en este modelo. Rango provisional."),
]

# Parámetros que se calibran en cada paso. Ajustar después del tamizaje (paso 3).
# Por ahora, los mismos que quedaron en la calibración de nuestro modelo.
CALIBRAR_REGLA = [
    "Sensibilidad de las gallinas deseadas al margen",
    "Tiempo de ajuste de gallinas",
    "Tiempo de percepción del precio",
]
CALIBRAR_CERRADO = CALIBRAR_REGLA + [
    "Productores posibles",
    "Tasa de contagio",
    "Sensibilidad de la entrada al margen",
]
# ---------------------------------------------------------------- búsqueda
SEMILLA = 2026
N_TAMIZAJE = 300          # corridas del tamizaje (unos 2 a 4 minutos)
N_INICIOS_REGLA = 4       # puntos de partida del optimizador en el paso 4
N_INICIOS_CERRADO = 3     # puntos de partida en el paso 5
MAX_EVALUACIONES = 300    # corridas máximas por punto de partida
N_PUNTOS_PERFIL = 15      # valores por parámetro en los perfiles del paso 6

# Modo de prueba rápida (solo para revisar que los scripts corren; lo que salga
# así no es una calibración).
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
