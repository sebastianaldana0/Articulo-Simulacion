# =============================================================================
# 04_ipc.R
# Pronóstico del IPC de Colombia (dic-2018 = 100), octubre de 2026 a enero de 2031.
#
# Fuente: DANE, IPC total, serie de empalme 2003-2026 (anex-IPC-Indices-sep2026.xlsx).
#
# Por qué no se usa ARIMA: el script ajusta primero un ARIMA estacional con la
#   ventana ene-2019 a sep-2026 solo como contraste. Ese modelo arrastra la
#   inflación alta de 2021-2026 y la proyecta hasta 2030, cuando el Banco de la
#   República tiene una meta de 3 % y todas las proyecciones oficiales esperan
#   que la inflación baje. A varios años, las encuestas y las metas creíbles
#   pronostican mejor que los modelos univariados (Faust y Wright, 2013).
#
# Método: senda oficial de inflación anual (diciembre contra diciembre), repartida
#   mes a mes con el patrón estacional que tuvo el IPC en la ventana de
#   entrenamiento (2019-2025, años completos):
#     cambio del logaritmo en el mes m del año a = log(1 + inflación_a) / 12 + s_m,
#   donde s_m es la desviación promedio del mes m frente al promedio de su año
#   (las s_m suman cero, así que el año termina exactamente en la inflación meta).
#
# Escenarios de inflación anual (%), diciembre contra diciembre:
#   2026: 7,1 en los tres (Banco de la República, Informe de Política Monetaria
#         de octubre de 2026, publicado el 4-nov-2026; el año ya está casi cerrado).
#   2027: base 4,8 (mismo informe); bajo 4,4 (Marco Fiscal de Mediano Plazo 2026,
#         12-jun-2026); alto 5,19 (analistas, Encuesta mensual de expectativas
#         del Banco de la República, octubre de 2026).
#   2028-2031: base 3,0 (meta del Banco de la República; el informe espera que la
#         inflación se acerque a ella en 2028); bajo 2,0 y alto 4,0 (límites del
#         rango meta, 3 % ± 1).
#
# Correr desde la carpeta del artículo (proyecto de RStudio), con R 4.2 o más reciente.
# =============================================================================

paquetes <- c("readxl", "forecast", "writexl", "ggplot2")
faltan <- paquetes[!sapply(paquetes, requireNamespace, quietly = TRUE)]
if (length(faltan) > 0) install.packages(faltan)
suppressPackageStartupMessages(invisible(lapply(paquetes, library, character.only = TRUE)))

id         <- "04_ipc"
archivo    <- "1_Datos/Fuentes/IPC/anex-IPC-Indices-sep2026.xlsx"
inicio_ent <- c(2019, 1)
fin_ent    <- c(2026, 9)
carpeta    <- "4_Pronostico_2030/salidas"
dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)

metas <- data.frame(
  anio = 2026:2031,
  base = c(7.1, 4.8, 3.0, 3.0, 3.0, 3.0),
  bajo = c(7.1, 4.4, 2.0, 2.0, 2.0, 2.0),
  alto = c(7.1, 5.19, 4.0, 4.0, 4.0, 4.0),
  fuente = c("BanRep, IPOM oct-2026 (los tres escenarios)",
             "base: BanRep IPOM oct-2026; bajo: MFMP 2026; alto: Encuesta de expectativas oct-2026",
             "base: meta 3 %; bajo y alto: rango meta 2 % a 4 %",
             "base: meta 3 %; bajo y alto: rango meta 2 % a 4 %",
             "base: meta 3 %; bajo y alto: rango meta 2 % a 4 %",
             "base: meta 3 %; bajo y alto: rango meta 2 % a 4 % (solo para enero de 2031)"))

# --- 1. Datos ---------------------------------------------------------------
x <- read_excel(archivo, col_names = FALSE, .name_repair = "minimal")
fila <- which(x[[1]] == "Mes")[1]
anios <- suppressWarnings(as.integer(unlist(x[fila, -1])))
anios <- anios[!is.na(anios)]
bloque <- x[(fila + 1):(fila + 12), 2:(length(anios) + 1)]
valores <- suppressWarnings(as.numeric(as.matrix(bloque)))       # columnas = años
ipc_todo <- ts(valores[!is.na(valores)], start = c(anios[1], 1), frequency = 12)
y <- window(ipc_todo, start = inicio_ent, end = fin_ent)
cat("IPC: ", length(y), " meses; sep-2026 = ", tail(y, 1), "\n", sep = "")

# --- 2. Contraste: ARIMA estacional con la ventana 2019-2026 -------------------
arima_c <- auto.arima(y, lambda = 0, stepwise = FALSE, approximation = FALSE)
lb_c <- Box.test(residuals(arima_c), lag = 24, type = "Ljung-Box",
                 fitdf = sum(arimaorder(arima_c)[c("p", "q", "P", "Q")], na.rm = TRUE))
pron_c <- forecast(arima_c, h = 52)
dic_c <- c(tail(y[cycle(y) == 12], 1),
           as.numeric(pron_c$mean)[cycle(pron_c$mean) == 12])
infl_c <- round((dic_c[-1] / dic_c[-length(dic_c)] - 1) * 100, 2)
cat("ARIMA de contraste:", capture.output(print(arima_c))[2], "| Ljung-Box p =", round(lb_c$p.value, 3), "\n")
cat("Inflación diciembre contra diciembre que implicaría (2026-2030):", infl_c, "\n")

# --- 3. Patrón estacional de la ventana (años completos 2019-2025) -----------
dl <- diff(log(window(ipc_todo, start = c(2018, 12), end = c(2025, 12))))
mat <- matrix(as.numeric(dl), ncol = 12, byrow = TRUE)               # filas = 2019..2025
desv <- mat - rowMeans(mat)
s <- colMeans(desv)
names(s) <- month.abb
estacional <- data.frame(mes = 1:12, desviacion_log = round(s, 5),
                         puntos_porcentuales_mensuales = round(s * 100, 3))
cat("Patrón estacional (puntos porcentuales sobre el promedio del año):\n"); print(round(s * 100, 2))

# --- 4. Sendas mensuales por escenario ---------------------------------------
dic_2025 <- as.numeric(window(ipc_todo, start = c(2025, 12), end = c(2025, 12)))
sep_2026 <- as.numeric(tail(y, 1))
fechas_pro <- seq(as.Date("2026-10-01"), as.Date("2031-01-01"), by = "month")
senda <- function(esc) {
  infl <- setNames(metas[[esc]] / 100, metas$anio)
  out <- numeric(length(fechas_pro))
  # oct-dic 2026: llegar de sep-2026 al diciembre que fija la meta de 2026
  G <- log(dic_2025 * (1 + infl["2026"]) / sep_2026)
  inc <- G / 3 + (s[10:12] - mean(s[10:12]))
  nivel <- sep_2026
  for (k in seq_along(fechas_pro)) {
    a <- as.integer(format(fechas_pro[k], "%Y")); m <- as.integer(format(fechas_pro[k], "%m"))
    d <- if (a == 2026) inc[m - 9] else log(1 + infl[as.character(a)]) / 12 + s[m]
    nivel <- nivel * exp(d)
    out[k] <- nivel
  }
  out
}
tabla <- rbind(
  data.frame(fecha = seq(as.Date("2019-01-01"), by = "month", length.out = length(y)), tipo = "observado",
             base = as.numeric(y), bajo = as.numeric(y), alto = as.numeric(y)),
  data.frame(fecha = fechas_pro, tipo = "pronostico", base = senda("base"), bajo = senda("bajo"), alto = senda("alto")))
tabla$anio <- as.integer(format(tabla$fecha, "%Y")); tabla$mes <- as.integer(format(tabla$fecha, "%m"))
tabla$arima_contraste <- NA
tabla$arima_contraste[tabla$tipo == "pronostico"] <- as.numeric(pron_c$mean)
tabla <- tabla[, c("fecha", "anio", "mes", "tipo", "base", "bajo", "alto", "arima_contraste")]
tabla[c("base", "bajo", "alto", "arima_contraste")] <- lapply(tabla[c("base", "bajo", "alto", "arima_contraste")], round, 3)

# Comprobación: la inflación diciembre contra diciembre debe dar la meta
dic <- tabla[tabla$mes == 12, ]
anual <- data.frame(anio = dic$anio[-1],
                    inflacion_dic_base = round((dic$base[-1] / dic$base[-nrow(dic)] - 1) * 100, 2),
                    inflacion_dic_bajo = round((dic$bajo[-1] / dic$bajo[-nrow(dic)] - 1) * 100, 2),
                    inflacion_dic_alto = round((dic$alto[-1] / dic$alto[-nrow(dic)] - 1) * 100, 2))
prom <- aggregate(cbind(base, bajo, alto) ~ anio, tabla[tabla$anio <= 2030, ], mean)
names(prom) <- c("anio", "ipc_promedio_base", "ipc_promedio_bajo", "ipc_promedio_alto")
anual <- merge(anual, prom, by = "anio", all = TRUE)
anual[grep("promedio", names(anual))] <- lapply(anual[grep("promedio", names(anual))], round, 2)
print(anual, row.names = FALSE)

metodo <- data.frame(
  concepto = c("Serie", "Fuente", "Unidad", "Ventana de entrenamiento", "Contraste ARIMA (ventana 2019-2026)",
               "Contraste: Ljung-Box, 24 rezagos (p)", "Contraste: inflación dic/dic implícita 2026-2030 (%)",
               "Método usado", "Patrón estacional", "Escenarios", "Fuentes de las metas", "Fecha de corrida"),
  valor = c("IPC total (dic-2018 = 100)", "DANE, anex-IPC-Indices-sep2026.xlsx", "Índice",
            "ene-2019 a sep-2026 (93 meses); patrón estacional con los años completos 2019-2025",
            capture.output(print(arima_c))[2], round(lb_c$p.value, 3), paste(infl_c, collapse = "; "),
            "Senda oficial de inflación anual repartida por mes con el patrón estacional de la ventana",
            "s_m = promedio 2019-2025 de (cambio del log en el mes m - cambio promedio del año); suma cero",
            "Ver hoja metas: base, bajo y alto por año",
            "BanRep, Informe de Política Monetaria oct-2026 (7,1 % en 2026; 4,8 % en 2027; inflación acercándose a la meta de 3 % en 2028); MFMP 2026 (4,4 % en 2027); Encuesta mensual de expectativas oct-2026 (5,19 % en 2027); meta 3 % y rango 2-4 %",
            format(Sys.Date(), "%Y-%m-%d")))

guardar_excel <- function(hojas, archivo_salida) {
  write_xlsx(hojas, archivo_salida, format_headers = TRUE)
}
guardar_excel(list(pronostico = tabla, resumen_anual = anual, metas = metas, estacionalidad = estacional, metodo = metodo),
              file.path(carpeta, paste0(id, "_pronostico.xlsx")))

largo <- rbind(data.frame(fecha = tabla$fecha, valor = tabla$base, serie = ifelse(tabla$tipo == "observado", "Observado", "Base")),
               data.frame(fecha = tabla$fecha[tabla$tipo == "pronostico"], valor = tabla$bajo[tabla$tipo == "pronostico"], serie = "Bajo"),
               data.frame(fecha = tabla$fecha[tabla$tipo == "pronostico"], valor = tabla$alto[tabla$tipo == "pronostico"], serie = "Alto"),
               data.frame(fecha = tabla$fecha[tabla$tipo == "pronostico"], valor = tabla$arima_contraste[tabla$tipo == "pronostico"], serie = "ARIMA (contraste)"))
g <- ggplot(largo, aes(fecha, valor, colour = serie, linetype = serie)) + geom_line(linewidth = 0.6) +
  scale_colour_manual(values = c(Observado = "black", Base = "#1F3B70", Bajo = "#5B8C5A", Alto = "#B03A2E", "ARIMA (contraste)" = "grey55")) +
  scale_linetype_manual(values = c(Observado = "solid", Base = "solid", Bajo = "solid", Alto = "solid", "ARIMA (contraste)" = "dashed")) +
  labs(title = "IPC total de Colombia (dic-2018 = 100)",
       subtitle = "Senda oficial con el patrón estacional 2019-2025; ARIMA solo como contraste",
       x = NULL, y = NULL, colour = NULL, linetype = NULL) +
  theme_minimal(base_size = 10) + theme(legend.position = "bottom")
ggsave(file.path(carpeta, paste0(id, "_pronostico.png")), g, width = 16, height = 9, units = "cm", dpi = 200, bg = "white")
cat("Listo:", file.path(carpeta, paste0(id, "_pronostico.xlsx")), "\n")
