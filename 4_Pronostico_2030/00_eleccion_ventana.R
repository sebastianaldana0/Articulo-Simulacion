# =============================================================================
# 00_eleccion_ventana.R
# ¿Sirve entrenar el ARIMA de maíz, torta de soya y TRM solo con ene-2019 a
# sep-2026, el periodo que el modelo simula con datos? Prueba hacia atrás
# (backtesting) con origen móvil.
#
# Ventanas que se comparan:
#   - 51 meses: igual al horizonte del pronóstico (oct-2026 a dic-2030).
#   - 93 meses: igual al periodo que el modelo simula con datos (ene-2019 a sep-2026).
#   - 144 meses: igual a todo el horizonte de la simulación (2019-2030, 12 años).
#   - Toda la historia: desde 1990 (Banco Mundial) o 2000 (TRM).
#   - Caminata aleatoria (último valor): referencia que no depende de la ventana.
#
# Dos formas de elegir el modelo en cada ventana:
#   - "libre": auto.arima decide todo (diferencias, deriva, parte estacional).
#   - "Box-Jenkins": d = 1, sin deriva, sin parte estacional, p y q de 0 a 2,
#     menor AICc. Es la especificación de los scripts 01, 02 y 03.
#
# Para cada origen (cada 6 meses, de ene-2012 a jun-2022) se entrena con la
# ventana, se pronostica 51 meses y se mide el error a 12, 24, 36 y 51 meses.
# Tarda unos minutos. Correr desde la carpeta del artículo (proyecto de RStudio).
# =============================================================================

paquetes <- c("readxl", "forecast", "writexl")
faltan <- paquetes[!sapply(paquetes, requireNamespace, quietly = TRUE)]
if (length(faltan) > 0) install.packages(faltan)
suppressPackageStartupMessages(invisible(lapply(paquetes, library, character.only = TRUE)))

dir.create("4_Pronostico_2030/salidas", recursive = TRUE, showWarnings = FALSE)
fin_datos <- c(2026, 9)

# --- Datos -------------------------------------------------------------------
leer_banco_mundial <- function(archivo, columna) {
  x <- read_excel(archivo, sheet = "Monthly Prices", col_names = FALSE, .name_repair = "minimal")
  fila_nombres <- which(apply(x, 1, function(r) any(r %in% columna)))[1]
  col <- which(unlist(x[fila_nombres, ]) == columna)[1]
  datos <- x[grepl("^\\d{4}M\\d{2}$", x[[1]]), ]
  inicio <- c(as.integer(substr(datos[[1]][1], 1, 4)), as.integer(substr(datos[[1]][1], 6, 7)))
  ts(suppressWarnings(as.numeric(datos[[col]])), start = inicio, frequency = 12)
}
archivo_bm <- "1_Datos/Fuentes/TRM, maiz, soya/CMO-Historical-Data-Monthly.xlsx"
maiz  <- window(leer_banco_mundial(archivo_bm, "Maize"), start = c(1990, 1), end = fin_datos)
torta <- window(leer_banco_mundial(archivo_bm, "Soybean meal"), start = c(1990, 1), end = fin_datos)

diaria <- read_excel("1_Datos/Fuentes/TRM, maiz, soya/Tasa de cambio del peso colombiano.xlsx", sheet = "Datos",
                     skip = 2, col_names = FALSE, .name_repair = "minimal")
names(diaria) <- c("fecha", "trm")
diaria <- diaria[!is.na(diaria$trm), ]
diaria$fecha <- as.Date(diaria$fecha, format = "%Y/%m/%d")
mensual <- tapply(as.numeric(diaria$trm), format(diaria$fecha, "%Y-%m"), mean)
primer_mes <- names(mensual)[1]
trm <- ts(as.numeric(mensual), frequency = 12,
          start = c(as.integer(substr(primer_mes, 1, 4)), as.integer(substr(primer_mes, 6, 7))))
trm <- window(trm, start = c(2000, 1), end = fin_datos)   # flotación libre desde sep-1999

series <- list(maiz = maiz, torta = torta, trm = trm)

# --- Especificaciones --------------------------------------------------------
especificaciones <- list(
  "libre" = function(tr) auto.arima(tr, lambda = 0),
  "Box-Jenkins" = function(tr) auto.arima(tr, d = 1, lambda = 0, allowdrift = FALSE, seasonal = FALSE,
                                          max.p = 2, max.q = 2, stepwise = FALSE, approximation = FALSE))

# --- Prueba hacia atrás ------------------------------------------------------
ventanas <- c("51 meses" = 51, "93 meses" = 93, "144 meses" = 144, "Toda la historia" = Inf)
H <- c(12, 24, 36, 51)
origenes <- seq(2012, 2022 + 5/12, by = 0.5)   # ene-2012 a jun-2022

filas <- list()
for (nm in names(series)) {
  y <- series[[nm]]
  for (o in origenes) {
    i_o <- which(abs(time(y) - o) < 1e-6)
    real <- as.numeric(y[i_o + H])
    filas[[length(filas) + 1]] <- data.frame(serie = nm, especificacion = "-", ventana = "Caminata aleatoria",
      origen = o, h = H, ape = abs(as.numeric(y[i_o]) / real - 1) * 100, en80 = NA, deriva = NA, d = NA)
    for (v in names(ventanas)) {
      ini <- if (is.infinite(ventanas[v])) 1 else i_o - ventanas[v] + 1
      if (ini < 1) next
      tr <- ts(y[ini:i_o], end = time(y)[i_o], frequency = 12)
      for (e in names(especificaciones)) {
        fit <- especificaciones[[e]](tr)
        fc <- forecast(fit, h = max(H), level = 80)
        filas[[length(filas) + 1]] <- data.frame(serie = nm, especificacion = e, ventana = v, origen = o, h = H,
          ape = abs(as.numeric(fc$mean[H]) / real - 1) * 100,
          en80 = real >= fc$lower[H, 1] & real <= fc$upper[H, 1],
          deriva = "drift" %in% names(coef(fit)), d = arimaorder(fit)[["d"]])
      }
    }
  }
}
bt <- do.call(rbind, filas)

mape <- aggregate(ape ~ serie + especificacion + ventana + h, bt, mean)
mape <- reshape(mape, idvar = c("serie", "especificacion", "ventana"), timevar = "h", direction = "wide")
names(mape) <- c("serie", "especificacion", "ventana", paste0("MAPE_", H, "m"))
cob <- aggregate(en80 ~ serie + especificacion + ventana, bt[!is.na(bt$en80), ], mean)
names(cob)[4] <- "cobertura80_promedio"
uno <- unique(bt[!is.na(bt$deriva), c("serie", "especificacion", "ventana", "origen", "deriva", "d")])
der <- aggregate(cbind(deriva, d2 = d == 2) ~ serie + especificacion + ventana, uno, mean)
names(der)[4:5] <- c("fraccion_con_deriva", "fraccion_con_d2")
res <- merge(merge(mape, cob, all.x = TRUE), der, all.x = TRUE)
res <- res[order(res$serie, res$especificacion, res$MAPE_51m), ]
num <- sapply(res, is.numeric); res[num] <- lapply(res[num], round, 3)
print(res, row.names = FALSE)

nota <- data.frame(nota = c(
  "Prueba hacia atrás con origen móvil cada 6 meses (ene-2012 a jun-2022); 22 orígenes por serie.",
  "MAPE: error porcentual absoluto medio del pronóstico a 12, 24, 36 y 51 meses.",
  "cobertura80_promedio: fracción de veces que el valor real cayó dentro del intervalo de 80 % (ideal 0,80).",
  "fraccion_con_deriva y fraccion_con_d2: fracción de orígenes en que el modelo elegido incluyó deriva o dos diferencias.",
  "libre: auto.arima decide todo. Box-Jenkins: d = 1, sin deriva, sin parte estacional, p y q de 0 a 2, menor AICc.",
  "ARIMA ajustado en logaritmos (lambda = 0) con el paquete forecast."))
write_xlsx(list(resumen = res, detalle = bt, nota = nota), "4_Pronostico_2030/salidas/00_eleccion_ventana.xlsx")
cat("Listo: Pronostico_2030/salidas/00_eleccion_ventana.xlsx\n")
