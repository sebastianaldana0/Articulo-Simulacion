# =============================================================================
# 02_torta_soya.R
# Pronóstico del precio internacional de la torta de soya, octubre de 2026 a enero de 2031.
#
# Fuente: Banco Mundial, Pink Sheet (archivo CMO-Historical-Data-Monthly.xlsx),
#   torta de soya (soybean meal), US$ por tonelada, mensual. Ojo: el Banco Mundial
#   cambió la definición dentro de la ventana: hasta dic-2020, pellets de Brasil
#   48 % CIF Rotterdam; ene-2021 a dic-2024, pellets de soya 48 % de Brasil CIF
#   Rotterdam; desde ene-2025, harina de soya de EE. UU. 48 % FOB Rotterdam. El
#   script mide el salto de esos dos meses frente a la variación mensual normal.
#
# Método: ARIMA con la metodología de Box y Jenkins.
#   1. Identificación: logaritmo de la serie, prueba de Dickey-Fuller aumentada
#      (ADF) en nivel y en primera diferencia, gráficos ACF y PACF.
#   2. Estimación: nueve candidatos ARIMA(p,1,q) con p y q de 0 a 2; se elige el
#      de menor AICc.
#   3. Diagnóstico: prueba de Ljung-Box sobre los residuos (12 rezagos).
#   4. Validación: se entrena hasta sep-2024 y se pronostican los 24 meses
#      siguientes, que ya se conocen; se compara con la caminata aleatoria
#      (dejar constante el último valor).
#   5. Pronóstico: 52 meses con intervalos de 80 % y 95 %.
#
# Ventana de entrenamiento: ene-2019 a sep-2026 (93 meses), el mismo periodo que
#   el modelo de Vensim simula con datos reales.
# Dos decisiones fijas, respaldadas por 00_eleccion_ventana.R:
#   - d = 1: el precio tiene raíz unitaria (ADF).
#   - Sin deriva: no se supone una tendencia determinística. Con ventanas cortas,
#     una deriva o una segunda diferencia extrapolan el último auge y el error a
#     51 meses se dispara; con d = 1 y sin deriva la ventana de 93 meses rinde
#     igual que la historia completa.
# Escenarios: base = pronóstico central; bajo y alto = límites del intervalo de 80 %.
# El horizonte llega a enero de 2031 porque la última semana de la simulación
#   (semana 626: 31-dic-2030 a 6-ene-2031) tiene seis días de enero.
#
# Correr desde la carpeta del artículo (proyecto de RStudio Articulo-Simulacion),
# con R 4.2 o más reciente.
# =============================================================================

# --- 0. Paquetes ------------------------------------------------------------
paquetes <- c("readxl", "forecast", "tseries", "writexl", "ggplot2")
faltan <- paquetes[!sapply(paquetes, requireNamespace, quietly = TRUE)]
if (length(faltan) > 0) install.packages(faltan)
suppressPackageStartupMessages(invisible(lapply(paquetes, library, character.only = TRUE)))

# --- Parámetros de la serie -------------------------------------------------
id          <- "02_torta_soya"
nombre      <- "Precio internacional de la torta de soya"
unidad      <- "US$/t"
archivo     <- "1_Datos/Fuentes/TRM, maiz, soya/CMO-Historical-Data-Monthly.xlsx"
columna_bm  <- "Soybean meal"
inicio_ent  <- c(2019, 1)
fin_ent     <- c(2026, 9)
fin_valid   <- c(2024, 9)        # validación: entrena hasta aquí y prueba 24 meses
h           <- 52                # oct-2026 a ene-2031
carpeta     <- "4_Pronostico_2030/salidas"
dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)

# --- 1. Datos ---------------------------------------------------------------
leer_banco_mundial <- function(archivo, columna) {
  x <- read_excel(archivo, sheet = "Monthly Prices", col_names = FALSE, .name_repair = "minimal")
  fila_nombres <- which(apply(x, 1, function(r) any(r %in% columna)))[1]
  col <- which(unlist(x[fila_nombres, ]) == columna)[1]
  datos <- x[grepl("^\\d{4}M\\d{2}$", x[[1]]), ]
  inicio <- c(as.integer(substr(datos[[1]][1], 1, 4)), as.integer(substr(datos[[1]][1], 6, 7)))
  ts(suppressWarnings(as.numeric(datos[[col]])), start = inicio, frequency = 12)
}
y <- window(leer_banco_mundial(archivo, columna_bm), start = inicio_ent, end = fin_ent)
ly <- log(y)
cat(nombre, ": ", length(y), " meses de entrenamiento; último dato ", round(tail(y, 1), 1), " ", unidad, "\n", sep = "")

# Cambios de definición del Banco Mundial: ¿el salto de ene-2021 y ene-2025 es atípico?
dly <- diff(ly)
salto_2021 <- as.numeric(window(dly, start = c(2021, 1), end = c(2021, 1)))
salto_2025 <- as.numeric(window(dly, start = c(2025, 1), end = c(2025, 1)))
cat("Cambio del logaritmo en ene-2021 =", round(salto_2021, 3), "| ene-2025 =", round(salto_2025, 3),
    "| desviación estándar mensual =", round(sd(dly), 3), "\n")

# --- 2. Identificación ------------------------------------------------------
adf_nivel <- suppressWarnings(adf.test(ly))$p.value
adf_dif   <- suppressWarnings(adf.test(diff(ly)))$p.value
cat("ADF en nivel p =", round(adf_nivel, 3), "| ADF en diferencia p =", round(adf_dif, 3), "\n")
# p > 0,05 en nivel (no se rechaza raíz unitaria) y p < 0,05 en diferencia -> d = 1
d <- 1

png(file.path(carpeta, paste0(id, "_acf_pacf.png")), width = 1600, height = 700, res = 160)
par(mfrow = c(1, 2))
Acf(diff(ly), lag.max = 24, main = "ACF de la primera diferencia del logaritmo")
Pacf(diff(ly), lag.max = 24, main = "PACF de la primera diferencia del logaritmo")
invisible(dev.off())

# --- 3. Estimación: candidatos ARIMA(p,1,q) ---------------------------------
candidatos <- expand.grid(p = 0:2, q = 0:2)
candidatos$AICc <- NA
candidatos$BIC <- NA
for (i in seq_len(nrow(candidatos))) {
  m <- tryCatch(Arima(y, order = c(candidatos$p[i], d, candidatos$q[i]), lambda = 0),
                error = function(e) NULL)
  if (!is.null(m)) {
    candidatos$AICc[i] <- m$aicc
    candidatos$BIC[i] <- m$bic
  }
}
candidatos <- candidatos[order(candidatos$AICc), ]
candidatos$modelo <- paste0("ARIMA(", candidatos$p, ",1,", candidatos$q, ")")
p <- candidatos$p[1]
q <- candidatos$q[1]
modelo <- Arima(y, order = c(p, d, q), lambda = 0)
etiqueta <- paste0("ARIMA(", p, ",", d, ",", q, ")")
cat("Modelo elegido:", etiqueta, " AICc =", round(modelo$aicc, 2), "\n")
if (length(coef(modelo)) > 0) print(round(coef(modelo), 4)) else cat("Sin coeficientes: es una caminata aleatoria\n")

# Solo para informar: ¿sería significativa una deriva en esta ventana?
con_deriva <- Arima(y, order = c(p, d, q), include.drift = TRUE, lambda = 0)
t_deriva <- unname(coef(con_deriva)["drift"] / sqrt(diag(con_deriva$var.coef))["drift"])
cat("Si se agregara deriva: t =", round(t_deriva, 2), "(no significativa si |t| < 1,96)\n")

# --- 4. Diagnóstico ---------------------------------------------------------
ljung <- Box.test(residuals(modelo), lag = 12, type = "Ljung-Box", fitdf = p + q)
jb <- jarque.bera.test(residuals(modelo))
cat("Ljung-Box (12 rezagos) p =", round(ljung$p.value, 3), "| Jarque-Bera p =", round(jb$p.value, 3), "\n")
png(file.path(carpeta, paste0(id, "_residuos.png")), width = 1600, height = 900, res = 160)
checkresiduals(modelo, lag = 12, test = FALSE)
invisible(dev.off())

# --- 5. Validación fuera de muestra (oct-2024 a sep-2026) -------------------
y_ent <- window(y, end = fin_valid)
y_val <- window(y, start = tsp(y_ent)[2] + 1/12)
m_val <- Arima(y_ent, order = c(p, d, q), lambda = 0)
f_val <- forecast(m_val, h = length(y_val), level = 80)
mape_arima <- mean(abs(as.numeric(f_val$mean) / as.numeric(y_val) - 1)) * 100
mape_rw <- mean(abs(as.numeric(tail(y_ent, 1)) / as.numeric(y_val) - 1)) * 100
cobertura <- mean(y_val >= f_val$lower[, 1] & y_val <= f_val$upper[, 1])
cat("Validación 24 meses: MAPE ARIMA =", round(mape_arima, 1), "% | MAPE caminata =",
    round(mape_rw, 1), "% | cobertura 80 % =", round(cobertura, 2), "\n")
validacion <- data.frame(
  fecha = seq(as.Date(paste(fin_valid[1], fin_valid[2], 1, sep = "-")), by = "month", length.out = length(y_val) + 1)[-1],
  real = round(as.numeric(y_val), 2),
  arima = round(as.numeric(f_val$mean), 2),
  caminata = round(as.numeric(tail(y_ent, 1)), 2),
  inf80 = round(as.numeric(f_val$lower[, 1]), 2),
  sup80 = round(as.numeric(f_val$upper[, 1]), 2))

# --- 6. Pronóstico ----------------------------------------------------------
pron <- forecast(modelo, h = h, level = c(80, 95))
fechas_obs <- seq(as.Date(paste(inicio_ent[1], inicio_ent[2], 1, sep = "-")), by = "month", length.out = length(y))
fechas_pro <- seq(max(fechas_obs), by = "month", length.out = h + 1)[-1]
tabla <- rbind(
  data.frame(fecha = fechas_obs, tipo = "observado", base = as.numeric(y), bajo = as.numeric(y),
             alto = as.numeric(y), inf95 = NA, sup95 = NA),
  data.frame(fecha = fechas_pro, tipo = "pronostico", base = as.numeric(pron$mean),
             bajo = as.numeric(pron$lower[, 1]), alto = as.numeric(pron$upper[, 1]),
             inf95 = as.numeric(pron$lower[, 2]), sup95 = as.numeric(pron$upper[, 2])))
tabla$anio <- as.integer(format(tabla$fecha, "%Y"))
tabla$mes <- as.integer(format(tabla$fecha, "%m"))
tabla <- tabla[, c("fecha", "anio", "mes", "tipo", "base", "bajo", "alto", "inf95", "sup95")]
num <- c("base", "bajo", "alto", "inf95", "sup95")
tabla[num] <- lapply(tabla[num], round, 2)

anual <- aggregate(cbind(base, bajo, alto) ~ anio, data = tabla[tabla$anio <= 2030, ], FUN = mean)
anual$meses_pronosticados <- sapply(anual$anio, function(a) sum(tabla$anio == a & tabla$tipo == "pronostico"))
anual[c("base", "bajo", "alto")] <- lapply(anual[c("base", "bajo", "alto")], round, 1)
dic30 <- tabla[tabla$fecha == as.Date("2030-12-01"), ]

metodo <- data.frame(
  concepto = c("Serie", "Fuente", "Unidad", "Frecuencia", "Ventana de entrenamiento", "Observaciones",
               "Transformación", "ADF en nivel (p)", "ADF en primera diferencia (p)", "Orden de integración d",
               "Modelo elegido (menor AICc)", "Coeficientes", "AICc", "t de una deriva si se agregara",
               "Ljung-Box, 12 rezagos (p)", "Jarque-Bera (p)", "Validación oct-2024 a sep-2026: MAPE ARIMA",
               "Validación: MAPE caminata aleatoria", "Validación: cobertura del intervalo de 80 %",
               "Horizonte", "Pronóstico dic-2030 (base)", "Intervalo de 80 % en dic-2030",
               "Escenarios", "Cambio del logaritmo en los meses de cambio de definición",
               "Fecha de corrida"),
  valor = c(nombre, "Banco Mundial, Pink Sheet (CMO-Historical-Data-Monthly.xlsx)", unidad, "Mensual",
            "ene-2019 a sep-2026 (mismo periodo que el modelo simula con datos)", length(y),
            "Logaritmo natural (lambda = 0)", round(adf_nivel, 3), round(adf_dif, 3), d,
            etiqueta, if (length(coef(modelo)) > 0) paste(names(coef(modelo)), round(coef(modelo), 4), sep = " = ", collapse = "; ") else "ninguno (caminata aleatoria: el mejor pronóstico es el último valor)",
            round(modelo$aicc, 2), round(t_deriva, 2), round(ljung$p.value, 3), round(jb$p.value, 3),
            paste0(round(mape_arima, 1), " %"), paste0(round(mape_rw, 1), " %"), round(cobertura, 2),
            "oct-2026 a ene-2031 (52 meses)", round(dic30$base, 1),
            paste(round(dic30$bajo, 1), "a", round(dic30$alto, 1)),
            "base = pronóstico central (mediana en niveles); bajo y alto = límites del intervalo de 80 %",
            paste0("ene-2021: ", round(salto_2021, 3), "; ene-2025: ", round(salto_2025, 3),
                   "; desviación estándar mensual: ", round(sd(dly), 3)),
            format(Sys.Date(), "%Y-%m-%d")))

# --- 7. Exportar ------------------------------------------------------------
guardar_excel <- function(hojas, archivo_salida) {
  write_xlsx(hojas, archivo_salida, format_headers = TRUE)
}
guardar_excel(list(pronostico = tabla, resumen_anual = anual, metodo = metodo,
                   candidatos = candidatos[, c("modelo", "AICc", "BIC")], validacion = validacion),
              file.path(carpeta, paste0(id, "_pronostico.xlsx")))

g <- ggplot(tabla, aes(fecha)) +
  geom_ribbon(aes(ymin = inf95, ymax = sup95), fill = "#C9D6EA", na.rm = TRUE) +
  geom_ribbon(data = tabla[tabla$tipo == "pronostico", ], aes(ymin = bajo, ymax = alto), fill = "#93ADD4") +
  geom_line(data = tabla[tabla$tipo == "observado", ], aes(y = base), linewidth = 0.5) +
  geom_line(data = tabla[tabla$tipo == "pronostico", ], aes(y = base), colour = "#1F3B70", linewidth = 0.7) +
  labs(title = paste0(nombre, " (", unidad, ")"),
       subtitle = paste0(etiqueta, " en logaritmos, entrenado con ene-2019 a sep-2026; bandas de 80 % y 95 %"),
       x = NULL, y = NULL) +
  theme_minimal(base_size = 10)
ggsave(file.path(carpeta, paste0(id, "_pronostico.png")), g, width = 16, height = 8, units = "cm", dpi = 200, bg = "white")
cat("Listo:", file.path(carpeta, paste0(id, "_pronostico.xlsx")), "\n")
