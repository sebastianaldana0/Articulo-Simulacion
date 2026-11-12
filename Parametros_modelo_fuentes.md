# Parámetros del modelo del huevo: valor, fuente y cálculo

Revisión del 12-nov-2026 sobre `Huevo_modelo_forrester_completo.mdl` y `Base final- Borrador.xlsx` (versión corregida, datos a septiembre de 2026). Las tablas de Vensim calculadas desde la base están en `Tablas_Vensim_desde_base.txt`.

Cada parámetro tiene una clase:

- D: dato publicado.
- F: valor tomado de una fuente publicada.
- C: cálculo propio con la base o con cuadros de Fenavi.
- K: se fija calibrando el modelo contra los datos.
- S: supuesto declarado, sin fuente.
- P: palanca de política o de escenario.

La confianza es alta, media o baja.

## 1. Aves

| Parámetro | Actual | Propuesto | Clase | Fuente o cálculo | Confianza |
|---|---|---|---|---|---|
| Tiempo de levante | 20 sem | 20 sem | F | Fenaviquín 440, p. 6: el modelo de población usa 80 semanas de vida, 20 de levante. El cuadro de costos de la misma edición (p. 20) pone la postura de la semana 18 a la 80. | Alta |
| Vida productiva normal | 60 sem | 60 sem | F | Misma fuente (80 − 20). | Alta |
| Fracción de mortalidad | 0,12 | 0,12 | F | Fenaviquín 440, p. 6 y p. 20. En el modelo solo reparte la salida entre descarte y muerte; la vida media sigue siendo 60 semanas. | Alta |
| Postura semanal por ave | 5,83 | 5,75 | C | k = 24,66 huevos por pollita al mes durante 14 meses (t−18 a t−5) da 345,2 huevos por pollita encasetada; 345,2 / 60 = 5,754. Con k la base reproduce la producción de Fenavi 2019-2025 con error medio de 0,58%. Queda 1,4% por debajo de los 350 huevos nominales de Fenavi. | Alta |
| Producción inicial de huevos | 275.640.000 | 266.776.181 | D | Semana 0 de la base (enero de 2019). 275,6 millones es el promedio de todo 2019 y sobrestima el arranque en 3,3%. | Alta |
| Encasetamiento inicial | 800.000 | 821.165 | C | Promedio semanal del 13-ago al 31-dic-2018, que son las 20 semanas de pollitas que siguen en levante el 1-ene-2019 (16,54 millones en total). El promedio de todo 2018 es 796.362. | Alta |
| Gallinas iniciales (se calcula) | 47,3 M | 46,4 M | C | 266,78 M / 5,754. Con los 16,4 M en levante suman 62,8 M aves; el censo ICA 2019 contó 60,8 M en postura ocupada (incluye pollitas criadas en esas granjas) y 7,3 M en granjas de levante. | Media |
| Efecto del margen en la vida productiva | tabla | calibrar | K | Fenaviquín 440, p. 8, nombra la "reducción del ciclo productivo" como una de las dos vías de ajuste de los productores (la otra es encasetar menos). No da cifras. | Baja |

Con estos valores el modelo no arranca en equilibrio: entran 821.165 pollitas por semana y salen 46,4 M / 60 = 772.700 gallinas. Eso coincide con lo observado (la producción pasó de 14.383 millones en 2019 a 16.382 millones en 2020). Para la prueba de equilibrio se usa Encasetamiento inicial = 772.700.

## 2. Mercado y precio

| Parámetro | Actual | Propuesto | Clase | Fuente o cálculo | Confianza |
|---|---|---|---|---|---|
| Precio de referencia | 290 | 300,75 | C | Promedio de 2019 del precio mayorista SIPSA (referencia rojo AA, 19 mercados). | Alta |
| Índice de precios | IPC(t)/IPC(0) | IPC(t)/102,556 | C | 102,556 es el IPC promedio de 2019 (dic-2018 = 100), el mismo deflactor de `precio_huevo_real_2019`. Si se deja la fórmula con INITIAL TIME, el precio de referencia debe ser 295,0 (pesos de enero de 2019). | Alta |
| Elasticidad precio de la demanda | 0,3 | 0,46 | F | Fenavi, Documentos Avícolas n.º 7 (Torres Castro, dic-2016): −0,462 (tabla 2, p. 16), MC2E con datos mensuales 1999-2015; la cantidad se aproxima con el encasetamiento de pollitas. Elasticidad ingreso: 0,625. Sensibilidad: 0,3 a 0,6. | Media |
| Consumo per cápita de referencia | valores de prueba | ver tabla abajo | C | Consumo aparente × (precio real / 300,75)^0,462. | Media |
| Participación del productor en el precio | 0,9 | 0,85 | S | No hay precio en granja publicado. Ver la explicación abajo. Sensibilidad: 0,75 a 0,95. | Baja |
| Tiempo de percepción del precio | 6 sem | calibrar entre 4 y 26 | K | Fenaviquín 440, p. 8: el ajuste de la actividad toma "aproximadamente seis meses". Fenaviquín 394, p. 8: el ajuste de precios en la cadena "toma semanas". La forma (expectativa adaptativa) es la de Nerlove (1958). | Media |
| Semanas por año | 52,18 | 52,18 | C | 365,25 / 7. | Alta |

Sobre la elasticidad. El −1,32 de Fenaviquín 440 (p. 9) no es una estimación: es el cociente de las variaciones de 2025 (oferta +7,6%, precio −5,8%) que Fenavi usó para simular exportaciones, y mezcla movimientos de la demanda con movimientos a lo largo de ella. Además, con 1,32 el consumo de referencia que exige el modelo saltaría de 292 huevos por persona en 2019 a 494 en 2022 y volvería a 368 en 2026, un vaivén que no tiene sentido para un alimento básico. Con 0,46 o 0,3 esa serie sube hasta 2021 y luego queda plana. Nuestras regresiones dieron entre −0,08 y −2,30, así que los datos solos no la identifican. El estudio de Fenavi tiene dos debilidades que conviene declarar: la cantidad es el encasetamiento y no el consumo, y el estadístico J de la ecuación del huevo tiene p = 0,000 (tabla A2), lo que pone en duda los instrumentos.

Consumo per cápita de referencia (huevos por persona al año), para pegar en la tabla de Vensim:

| Punto | Semana | e = 0,462 | e = 0,3 |
|---|---|---|---|
| Enero de 2019 | 0 | 280,1 | 281,9 |
| 2019 | 26,07 | 291,8 | 291,8 |
| 2020 | 78,25 | 320,4 | 322,1 |
| 2021 | 130,43 | 355,0 | 347,1 |
| 2022 | 182,61 | 368,4 | 348,6 |
| 2023 | 234,79 | 377,8 | 357,8 |
| 2024 | 286,97 | 368,0 | 358,9 |
| 2025 | 339,15 | 374,9 | 371,7 |
| 2026 (ene-sep) | 391,33 | 370,9 | 371,5 |

El punto de enero de 2019 hace que el modelo arranque en el precio observado: con él, la demanda de la semana 0 es 0,981 veces la oferta y el precio simulado da 283,2, igual al dato. Sin él (con 291,8 desde la semana 0) el precio arranca 16% arriba. Advertencia para el artículo: como el consumo de referencia se deduce con el precio observado, el nivel promedio de cada año queda en parte dentro de la demanda. La validación del precio debe mirar el momento y la forma del ciclo, no solo el nivel anual.

Sobre la participación del productor. Fenavi dice que el precio de SIPSA "no corresponde a precio del productor" e "incluye margen de comercialización e intermediarios" (Fenaviquín 394, p. 16; 456, p. 18). Tres datos acotan el valor:

1. Corabastos, el mercado más cercano a la zona productora cuya estructura de costos usa Fenavi (Cundinamarca), estuvo en 2024-2026 entre 0,84 y 0,98 veces el promedio de los 19 mercados (mediana 0,90); en 2019 estaba a la par (1,01).
2. Con 0,9 × 0,98 (factor de surtido) el precio en granja queda bajo el costo de Fenavi en 3 meses (ago-2020, sep y oct-2021); con 0,85, en 10 meses (jul-nov 2020, feb-abr 2021, sep-oct 2021); con 0,8, en 15.
3. En enero de 2026 pequeños productores protestaron porque la cubeta se les pagaba en finca entre 5.000 y 6.000 pesos frente a un costo de 10.000 a 11.000 (El Colombiano, 20-ene-2026). Son cifras de los manifestantes, no verificadas, pero indican que para los pequeños el costo real (con depreciación, crédito y comercialización, que Fenavi excluye) está por encima del de Fenavi.

Lo que importa para el modelo: la brecha de margen es s × (P/C − P₀/C₀), así que la participación s solo escala la entrada de todas las tablas de efecto y queda absorbida al calibrarlas. Por sí sola pesa en Caja del productor, Utilidad, Compras del fondo y Semanas con margen negativo. Si no se agrega una variable de surtido, usar 0,85 × 0,98 = 0,83 como participación efectiva.

## 3. Regla de encasetamiento

| Parámetro | Actual | Propuesto | Clase | Fuente o cálculo | Confianza |
|---|---|---|---|---|---|
| Fracción de la línea de suministro considerada | 0,33 | 0,34 | F | Sterman (1989), tabla 4: media de β = 0,34 (rango 0 a 1,05) en el juego de la cerveza; "only five subjects (11%) accounted for more than two-thirds of the supply line". Es la referencia de comportamiento estándar, medida en un experimento de laboratorio y no con avicultores. El valor 1 queda como política de información completa. | Media |
| Tiempo de ajuste de gallinas | 18 sem | calibrar entre 8 y 26 | K | Objetivos de calibración en la sección 8. | Baja |
| Tiempo de reposición | 4 sem | 4 sem | S | Fenavi publica el encasetamiento cada mes; el productor revisa su reposición con esa frecuencia. | Baja |
| Tiempo para percibir la demanda | 52 sem | 52 sem | S | Fenavi publica el consumo per cápita una vez al año. | Baja |
| Efecto del margen en las gallinas deseadas | tabla | calibrar | K | Objetivos en la sección 8. | Baja |

## 4. Costos

Recomendación: para la corrida histórica usar directamente la serie de costo de Fenavi, que ya está en la base, y dejar la estructura de maíz, soya y TRM solo para los choques. Con la estructura actual, aun calibrada, el costo simulado se aparta 7% en promedio del de Fenavi y queda 4% a 10% por debajo en 2026, porque el Banco Mundial no es el precio que paga el productor colombiano y Fenavi cambió de metodología en noviembre de 2020.

Opción B (recomendada):

```
Costo unitario = Tabla costo Fenavi(Time)*(1+Participación del alimento en el costo*((1+Choque del precio de las materias primas)*(1+Choque de la TRM)-1)*STEP(1, Semana de inicio del choque))
Participación del alimento en el costo = 0.70
```

El 0,70 sale de Fenaviquín 456, p. 17: en junio de 2026 el alimento fue 222,5 de 319,2 $/huevo (69,7%). La tabla de costo (2019 a sep-2026, más la proyección de Fenavi hasta enero de 2027) está en el archivo de tablas. El choque multiplica la parte del alimento porque Fenavi calcula ese costo con el precio internacional por la TRM más el flete (Fenaviquín 319, p. 12).

Opción A, si se quiere conservar la estructura (valores calibrados):

| Parámetro | Actual | Propuesto | Clase | Fuente o cálculo | Confianza |
|---|---|---|---|---|---|
| Alimento por huevo | 0,15 kg | 0,160 kg | F | Fenaviquín 381 (p. 16), 416 (p. 21) y 456 (p. 17): 56,035 kg de alimento acumulado por ave / 350 huevos. Fenavi usaba 0,130 kg (45,5 / 350) hasta octubre de 2020 (Fenaviquín 319, p. 12). | Alta |
| Participación del maíz en el alimento | 0,5 | 0,63 | C | Pesos que reproducen la "fórmula básica alimento huevo" de Fenaviquín 456 (p. 16) con sus precios de maíz y torta de soya puestos en Bogotá, 16 meses (oct-2025 a ene-2027), error máximo de 0,2%. USDA (GAIN CO2025-0002, p. 5): el alimento avícola típico lleva 60% de maíz. | Media |
| Participación de la soya en el alimento | 0,3 | 0,19 | C | Misma regresión. El resto de la fórmula (carbonato, premezclas, fríjol soya) entra por el factor de fabricación. | Media |
| Sobrecosto de importación | 0,15 | 0,40 | C | Precio de Fenavi puesto en Bogotá frente a Banco Mundial × TRM del mismo mes, oct-2025 a may-2026: maíz 1,47 a 1,54 (media 1,51), torta 1,11 a 1,24 (media 1,19), ponderado por la fórmula 1,35 a 1,43 (media 1,40). Incluye flete marítimo, puerto y flete terrestre Barranquilla-Bogotá. El cuadro de Fenavi rotula estos valores como US$/t, pero por su magnitud son miles de pesos por tonelada. No incluye arancel: el maíz de EE. UU. entra sin arancel desde 2023 por el TLC (USDA, GAIN CO2025-0002, p. 7). | Media |
| Factor de fabricación del alimento | 1,6 | 1,20 | K | (1 + sobrecosto) × factor = 1,685, ajustado contra 25 meses de la fila "alimento" de Fenavi (2019 reconstruida a 0,160 kg, 2022-2026), con las materias primas rezagadas 2 meses ("la estructura de costos está rezagada 2 meses", Fenaviquín 456, p. 16). Error medio 11,5%, con sesgos por año de −13% (2024) a +17% (2022). | Baja |
| Participación inicial del alimento en el costo | 0,7 | 0,76 | K | Valor que hace que el costo simulado de 2019 sea el de Fenavi (199,5 $/huevo). Para comparar: Fenavi publicó 67,8% en 2019 con su metodología vieja (0,130 kg y pollita de 18%); con la actual sería cerca de 83%; en junio de 2026, 69,7%. | Baja |
| Participación de la mano de obra en otros costos | 0,5 | 0,3 | C | Salto de enero de 2026 en Fenaviquín 456: "otros costos" pasó de 77,5 a 83,2 $/huevo (+7,4%) cuando el salario mínimo subió 23,0% y el IPC 1,2% en el mes: (7,4 − 1,2) / (23,0 − 1,2) = 0,28. Es una sola observación. | Baja |

## 5. Productores

| Parámetro | Actual | Propuesto | Clase | Fuente o cálculo | Confianza |
|---|---|---|---|---|---|
| Productores iniciales | 3.000 | 2.323 | D | Censo ICA 2019: predios de postura. Un predio no es lo mismo que un productor (una empresa puede tener varios). | Media |
| Productores posibles | 6.000 | calibrar | K | No hay fuente. | Baja |
| Tasa de contagio | 0,08 | calibrar | K | Objetivos: predios ICA de 2.323 (2019) a 2.558 (2025) y "más de 800" productores nuevos en 2024-2025 (Fenaviquín 440, p. 8). Las cifras de Fenavi no cuadran entre sí (854 entre 2023 y 2025 en la p. 7; 1.614 NIT nuevos en la p. 5) ni con el ICA: usar el ICA para el nivel y Fenavi como control del flujo. | Baja |
| Gallinas por productor nuevo | 4.230 | 4.230 | F | Fenaviquín 440, p. 5: 1.614 NIT sin registro previo encasetaron 6.826.143 pollitas en 2024-2025 (4.229 cada uno). La p. 8 da un valor parecido (3,6 M aves de más de 800 productores, unas 4.500). Corregir el comentario del modelo: son pollitas encasetadas en el bienio por NIT nuevos, no 1.614 productores en total. | Media |
| Tiempo de salida | 52 sem | 52 sem | S | Sin fuente. | Baja |
| Efecto del margen en la entrada y Fracción de salida | tablas | calibrar | K | Mismos objetivos de la tasa de contagio. | Baja |

## 6. Galpones y caja

| Parámetro | Actual | Propuesto | Clase | Fuente o cálculo | Confianza |
|---|---|---|---|---|---|
| Holgura inicial de capacidad | 0,15 | 0,144 | D | Censo ICA 2019: 69.577.275 cupos instalados / 60.814.199 ocupados − 1. El comentario del modelo cita 69,18 millones en 2025; el ICA da 80.396.592 instalados en 2025. | Alta |
| Capacidad por productor nuevo | 5.000 | 4.840 | C | 4.230 × 1,144: el productor nuevo construye con la misma holgura del promedio nacional. | Media |
| Tiempo de construcción | 26 sem | 26 sem | S | No se encontró fuente pública. Sensibilidad: 13 a 52 semanas. | Baja |
| Tiempo para decidir ampliaciones | 15 sem | calibrar | K | Objetivo: capacidad instalada del ICA 2019-2025 (69,6 a 80,4 M). | Baja |
| Fracción de galpones que se desmontan | 0,2 | calibrar | K | Mismo objetivo. | Baja |
| Tiempo para ocupar galpones | 20 sem | calibrar | K | Objetivo: ocupación del ICA entre 82,2% (2023) y 89,4% (2022). | Baja |
| Efecto del margen bajo en la ocupación | tabla | calibrar | K | Mismo objetivo. | Baja |
| Tiempo de retiro de utilidades | 26 sem | 26 sem | S | Sin fuente. | Baja |

## 7. Políticas y escenarios

| Parámetro | Actual | Propuesto | Clase | Fuente o cálculo |
|---|---|---|---|---|
| Umbral de caja | 0,3 | 0,3 | P | Diseño de la política. |
| Cuota de encasetamiento | 1.036.000 | 1.078.000 | C | Encasetamiento que repone la producción de 2025: 372,1 M huevos por semana / 345,2 huevos por pollita = 1.077.700 por semana (4,69 M al mes). El encasetamiento real de 2025 fue 4,86 M al mes. Los "4,5 millones citados por Fenavi" no aparecieron en las ediciones revisadas: si se mantienen, hay que citar la edición exacta. |
| Compra máxima del fondo | 50.000.000 | 50.000.000 | P | 13% de la producción de 2025. Palanca del escenario. |
| Tiempo de reacción del fondo | 2 sem | 2 sem | P | Palanca del escenario. |
| Brote sanitario, corrida histórica | interruptor 0 | interruptor 0 | D | ICA, informe de influenza aviar n.º 3: 39 focos en 2022 y 27 en 2023, todos en aves de traspatio o silvestres, "no en granjas comerciales"; 53.035 aves sacrificadas en 584 predios (cerca de 0,1% de las gallinas). El brote de 2022 no movió el ciclo comercial. |
| Fracción sacrificada por el brote, escenario | 0,03 | 0,10 | F | Análogo: brote H7N3 de Jalisco (México, 2012), 22,3 millones de gallinas de postura muertas o sacrificadas entre el 18 de junio y el 24 de octubre; el precio del huevo subió 60% según el estudio de la Universidad de Guanajuato citado por SENASICA. Frente a los 209 M de aves de postura que el mismo documento reporta para 2020, es cerca de 11%. |
| Duración del brote, escenario | 8 sem | 18 sem | F | Mismo brote (18-jun a 24-oct-2012). |
| Choques de materias primas y TRM | 0 | 0 | P | El 0,6 atribuido a Yuzaria et al. (2025) no se revisó en esta ronda. |

## 8. Qué se calibra y contra qué

Los parámetros K se ajustan a mano con SyntheSim, uno por bloque, contra estas series y hechos:

1. Encasetamiento semanal observado 2019-2026 (Tabla encasetamiento observado).
2. Producción semanal observada (Tabla producción observada).
3. Precio mayorista observado (Tabla precio observado, que hay que agregar al modelo para comparar).
4. Rezago razón precio/costo → encasetamiento de 7 a 16 meses (máximo a 16 meses, r = 0,43) y de 13 a 15 meses entre picos de encasetamiento y de producción.
5. Capacidad instalada y ocupación del ICA, 2019-2025.
6. Predios de postura del ICA y productores nuevos de Fenavi.

## 9. Tablas de datos

Todas se reemplazan por las del archivo `Tablas_Vensim_desde_base.txt`, con un punto por mes desde enero de 2019:

- Población: proyección DANE actualizada en julio de 2025 (2019: 49,27 M; el modelo traía 49,40 M).
- IPC mensual (el modelo traía promedios anuales con diferencias de 0,7% a 1,2%). De octubre de 2026 a diciembre de 2027 crece al ritmo de los últimos 12 meses (6,28% anual), como supuesto.
- TRM, maíz y torta de soya mensuales (la torta del modelo estaba 4% a 19% por debajo del Banco Mundial). Desde octubre de 2026 quedan constantes.
- Salario mínimo con escalón el 1 de enero; 2027 con +7% (supuesto).
- Encasetamiento y producción observados mensuales en tasa semanal (el modelo traía promedios anuales).
- Nuevas: Tabla precio observado y Tabla costo Fenavi.
- Consumo per cápita de referencia con e = 0,462.

## 10. Pendiente de decidir en el grupo

1. Opción B para el costo (recomendada) o la estructura calibrada (opción A).
2. Participación del productor: 0,85 como base con sensibilidad 0,75 a 0,95.
3. Elasticidad 0,46 como base; si se cambia, recalcular el consumo de referencia (la columna e = 0,3 ya está).
4. Agregar Tabla precio observado al modelo.

## Fuentes

- Fenavi (2016). Elasticidad de la demanda de carne de pollo y huevo en Colombia 1999-2015 (M. Torres Castro). Documentos Avícolas n.º 7. https://fenavi.org/wp-content/uploads/2018/05/CARTILLA_Elasticidad_Precios_2016.pdf
- Fenavi-Fonav. Fenaviquín, ediciones 319 (oct-2020), 381 (jun-2023), 394 (ene-2024), 416 (ene-2025), 440 (ene-2026) y 456 (sep-2026). https://fenavi.org/wp-content/uploads/2020/11/Fenaviquin_ed3192020.pdf ; https://fenavi.org/wp-content/uploads/2023/06/Fenaviquin_ed3812023.pdf ; https://fenavi.org/wp-content/uploads/2024/01/Fenaviquin_ed3942024.pdf ; https://fenavi.org/wp-content/uploads/2025/01/Fenaviquin_ed4162025.pdf ; https://fenavi.org/wp-content/uploads/2026/01/Fenaviquin_ed4402026.pdf ; https://fenavi.org/wp-content/uploads/2026/09/Fenaviquin_ed4562026.pdf
- Sterman, J. D. (1989). Modeling managerial behavior: Misperceptions of feedback in a dynamic decision making experiment. Management Science, 35(3), 321-339. Versión de trabajo revisada: MIT Sloan WP 1933-87. https://dspace.mit.edu/bitstream/handle/1721.1/2184/SWP-1933-18213539.pdf
- USDA FAS (2025). Colombia: Grain and Feed Annual, GAIN CO2025-0002, 19-mar-2025. https://www.fas.usda.gov/data/colombia-grain-and-feed-annual-10
- ICA. Informe de influenza aviar n.º 3 (enero de 2023 a enero de 2024). https://www.ica.gov.co/areas/pecuaria/servicios/enfermedades-animales/influenza-aviar/informe_ia-final-informe-no-3.aspx
- ICA. Censo pecuario aviar 2019-2025 (tablas por municipio; resumen en el documento del proyecto huevo-ica-censo-postura).
- SENASICA. Análisis económico del potencial impacto de la influenza aviar de alta patogenicidad en México (datos a 2020-2022). https://dj.senasica.gob.mx/Contenido/files/2022/agosto/AnálisisdeeconómicodelpotencialimpactodelaInfluenzaAviardeAltaPatogenicidadenMéxico_34a88075-4fb4-4a3b-aaf1-800568bfd16d.pdf
- El Colombiano (20-ene-2026). Nota sobre la protesta de pequeños avicultores por el precio del huevo. https://www.elcolombiano.com/negocios/avicultores-huevo-barato-crisis-protestas-MO32694778
- Nerlove, M. (1958). Adaptive expectations and cobweb phenomena. Quarterly Journal of Economics, 72(2), 227-240 (forma de la expectativa; no se usan cifras).
- DANE (SIPSA, IPC, proyecciones de población), Banco de la República (TRM) y Banco Mundial (Pink Sheet), a través de la base de datos del proyecto.
