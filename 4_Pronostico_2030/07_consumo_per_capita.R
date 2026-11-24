# =============================================================================
# 07_consumo_per_capita.R
# Consumo per cápita de referencia de huevo (huevos por persona al año), 2027-2031.
#
# Qué es: el desplazador de la demanda del modelo. Es el consumo aparente
#   corregido por el precio: el consumo que habría con el precio de referencia.
#     consumo de referencia = consumo aparente x (precio real / precio de referencia)^e
#   con e = 0,462 (elasticidad del modelo) y precio de referencia = promedio de
#   2019. Es la misma cuenta de la hoja parametros (sección 3.5) de la base.
#
# Fuente: hoja mensual de "1_Datos/Base final- Borrador.xlsx" (producción de Fenavi,
#   población del DANE, precio SIPSA, IPC del DANE).
#
# Por qué no se usa ARIMA: hay ocho datos anuales (2019-2026; 2026 es ene-sep).
#   Un ARIMA necesita decenas de observaciones.
#
# Método, con la ventana de entrenamiento 2019-2026:
#   1. Se calcula el consumo de referencia de cada año.
#   2. Se prueba si hay tendencia: en 2019-2026 la serie sube, pero desde 2022
#      queda plana (la pendiente de 2022-2026 no es significativa). Extrapolar
#      la tendencia de toda la ventana proyectaría un crecimiento que ya se
#      detuvo, cerca de un huevo diario por persona.
#   3. Pronóstico: media de la meseta 2022-2026 (método de la media) con su
#      intervalo de predicción de 80 %:
#        media +/- t(0,90; n-1) x s x raíz(1 + 1/n)
# Escenarios: base = media; bajo y alto = límites del intervalo de 80 %.
# También deja el punto inicial (semana 0, enero de 2019) que usa la tabla semanal.
#
# Correr desde la carpeta del artículo (proyecto de RStudio), con R 4.2 o más reciente.
# =============================================================================

paquetes <- c("readxl", "writexl", "ggplot2")
faltan <- paquetes[!sapply(paquetes, requireNamespace, quietly = TRUE)]
if (length(faltan) > 0) install.packages(faltan)
suppressPackageStartupMessages(invisible(lapply(paquetes, library, character.only = TRUE)))

id           <- "07_consumo_per_capita"
archivo      <- "1_Datos/Base final- Borrador.xlsx"
elasticidad  <- 0.462
semanas_anio <- 52.18
inicio_meseta <- 2022
carpeta      <- "4_Pronostico_2030/salidas"
dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)

# --- 1. Datos ---------------------------------------------------------------
m <- read_excel(archivo, sheet = "mensual")
m$fecha <- as.Date(m$fecha)
m <- m[m$anio >= 2019 & m$fecha <= as.Date("2026-09-01"), ]
ipc_2019 <- mean(m$ipc_total[m$anio == 2019])
precio_ref <- mean(m$precio_huevo_rojo_aa_promedio[m$anio == 2019])
m$consumo_aparente <- m$produccion_huevos_millones * 1e6 * 12 / m$poblacion
m$precio_real <- m$precio_huevo_rojo_aa_promedio * ipc_2019 / m$ipc_total
m$consumo_ref <- m$consumo_aparente * (m$precio_real / precio_ref)^elasticidad
anual <- aggregate(cbind(consumo_aparente, consumo_ref) ~ anio, m, mean)
anual$meses <- as.integer(table(m$anio)[as.character(anual$anio)])
cat("Precio de referencia (promedio 2019) =", round(precio_ref, 2), "| IPC promedio 2019 =", round(ipc_2019, 3), "\n")

s <- read_excel(archivo, sheet = "semanal")
s0 <- s[s$semana == 0, ]
consumo_semana0 <- s0$produccion_huevos_millones * 1e6 * semanas_anio / s0$poblacion *
  ((s0$precio_huevo_rojo_aa_promedio * ipc_2019 / s0$ipc_total) / precio_ref)^elasticidad
cat("Punto inicial (semana 0) =", round(consumo_semana0, 1), "\n")

# --- 2. ¿Hay tendencia? --------------------------------------------------------
anual$crecimiento_pct <- round(c(NA, diff(anual$consumo_ref) / head(anual$consumo_ref, -1) * 100), 2)
t_todo <- summary(lm(consumo_ref ~ anio, anual))
meseta <- anual[anual$anio >= inicio_meseta, ]
t_meseta <- summary(lm(consumo_ref ~ anio, meseta))
pruebas <- data.frame(
  periodo = c("2019-2026", paste0(inicio_meseta, "-2026")),
  pendiente_huevos_por_anio = round(c(coef(t_todo)[2, 1], coef(t_meseta)[2, 1]), 2),
  error_estandar = round(c(coef(t_todo)[2, 2], coef(t_meseta)[2, 2]), 2),
  p_valor = round(c(coef(t_todo)[2, 4], coef(t_meseta)[2, 4]), 3),
  r2 = round(c(t_todo$r.squared, t_meseta$r.squared), 3))
print(pruebas, row.names = FALSE)

# --- 3. Pronóstico: media de la meseta con intervalo de 80 % -------------------
n <- nrow(meseta)
media <- mean(meseta$consumo_ref)
de <- sd(meseta$consumo_ref)
margen <- qt(0.90, df = n - 1) * de * sqrt(1 + 1 / n)
cat("Media de la meseta =", round(media, 1), "| intervalo de 80 %:", round(media - margen, 1), "a", round(media + margen, 1), "\n")

salida <- rbind(
  data.frame(anio = anual$anio, tipo = "observado", base = anual$consumo_ref, bajo = anual$consumo_ref, alto = anual$consumo_ref),
  data.frame(anio = 2027:2031, tipo = "pronostico", base = media, bajo = media - margen, alto = media + margen))
salida$semana_ancla <- round(26.07 + semanas_anio * (salida$anio - 2019), 2)
salida[c("base", "bajo", "alto")] <- lapply(salida[c("base", "bajo", "alto")], round, 1)
inicial <- data.frame(punto = "Enero de 2019 (semana 0)", semana = 0, consumo_ref = round(consumo_semana0, 1))
anual_tabla <- anual
anual_tabla[c("consumo_aparente", "consumo_ref")] <- lapply(anual_tabla[c("consumo_aparente", "consumo_ref")], round, 1)

metodo <- data.frame(
  concepto = c("Serie", "Fórmula", "Elasticidad", "Precio de referencia (promedio 2019)", "Ventana de entrenamiento",
               "Prueba de tendencia 2019-2026", "Prueba de tendencia en la meseta", "Método de pronóstico",
               "Pronóstico 2027-2031 (base)", "Intervalo de 80 %", "Punto inicial (semana 0)", "Conversión a semanas", "Fecha de corrida"),
  valor = c("Consumo per cápita de referencia (huevos por persona al año)",
            "consumo aparente x (precio real / precio de referencia)^e; precio real en pesos de 2019",
            elasticidad, round(precio_ref, 2), "2019-2026 (2026 = ene-sep)",
            paste0("pendiente ", pruebas$pendiente_huevos_por_anio[1], " huevos/año, p = ", pruebas$p_valor[1]),
            paste0(inicio_meseta, "-2026: pendiente ", pruebas$pendiente_huevos_por_anio[2], " huevos/año, p = ", pruebas$p_valor[2]),
            paste0("Media de la meseta ", inicio_meseta, "-2026 con intervalo de predicción de 80 %"),
            round(media, 1), paste(round(media - margen, 1), "a", round(media + margen, 1)), round(consumo_semana0, 1),
            "Cada valor anual va en la semana de mitad de año (26,07 + 52,18 x (año - 2019)); entre anclas, línea recta",
            format(Sys.Date(), "%Y-%m-%d")))

guardar_excel <- function(hojas, archivo_salida) {
  write_xlsx(hojas, archivo_salida, format_headers = TRUE)
}
guardar_excel(list(pronostico = salida, punto_inicial = inicial, anual_calculo = anual_tabla, pruebas_tendencia = pruebas, metodo = metodo),
              file.path(carpeta, paste0(id, "_pronostico.xlsx")))

g <- ggplot(salida, aes(anio)) +
  geom_ribbon(data = salida[salida$anio >= 2026, ], aes(ymin = ifelse(tipo == "observado", base, bajo), ymax = ifelse(tipo == "observado", base, alto)), fill = "#C9D6EA") +
  geom_line(aes(y = base), colour = "#1F3B70", linewidth = 0.6) + geom_point(aes(y = base, shape = tipo), size = 1.8) +
  scale_shape_manual(values = c(observado = 16, pronostico = 1), labels = c("Calculado con datos", "Pronóstico")) +
  labs(title = "Consumo per cápita de referencia (huevos por persona al año)",
       subtitle = "Media de la meseta 2022-2026 con intervalo de predicción de 80 %", x = NULL, y = NULL, shape = NULL) +
  theme_minimal(base_size = 10) + theme(legend.position = "bottom")
ggsave(file.path(carpeta, paste0(id, "_pronostico.png")), g, width = 16, height = 9, units = "cm", dpi = 200, bg = "white")
cat("Listo:", file.path(carpeta, paste0(id, "_pronostico.xlsx")), "\n")
