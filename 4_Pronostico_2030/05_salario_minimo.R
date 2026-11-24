# =============================================================================
# 05_salario_minimo.R
# Proyección del salario mínimo mensual de Colombia, 2027 a 2031.
#
# Fuentes: Banco de la República (Salario minimo.xlsx, serie anual 1984-2026);
#   DANE, IPC (anex-IPC-Indices-sep2026.xlsx) para la inflación observada; y la
#   inflación proyectada que deja 04_ipc.R (correr antes ese script).
#
# Por qué no se usa ARIMA: el salario mínimo no es una serie que se mueva sola.
#   Es un dato al año, fijado por concertación o por decreto, y en 2026 subió
#   23 %, un salto de política que un ARIMA convertiría en tendencia.
#
# Método: la regla con la que se fija. El aumento es la inflación de diciembre a
#   diciembre del año anterior más una prima (productividad y negociación):
#     salario_a = salario_(a-1) * (1 + inflación_(a-1) + prima)
#   La prima se mide en la ventana de entrenamiento, 2019-2026, igual que las
#   demás series, como aumento observado menos inflación del año anterior.
#
# Escenarios de la prima (puntos porcentuales):
#   base: mediana 2019-2026 (no se deja arrastrar por el salto de 2026).
#   bajo: 0, el piso legal. La Corte Constitucional (Sentencia C-815 de 1999)
#         dispuso que el reajuste no puede ser inferior a la inflación del año
#         que termina.
#   alto: la prima más alta de la ventana sin contar los años atípicos según la
#         regla de Tukey (por encima de Q3 + 1,5 x RIC), que marca a 2026.
# Cada escenario usa la inflación de su mismo escenario en 04_ipc.R.
# El salario de 2027 se decreta en diciembre de 2026: cuando salga, escribirlo en
# salario_2027_decretado (abajo) y volver a correr. Los tres escenarios parten de
# ese valor y 2028-2031 siguen la regla.
#
# Correr desde la carpeta del artículo (proyecto de RStudio), con R 4.2 o más reciente.
# =============================================================================

paquetes <- c("readxl", "writexl", "ggplot2")
faltan <- paquetes[!sapply(paquetes, requireNamespace, quietly = TRUE)]
if (length(faltan) > 0) install.packages(faltan)
suppressPackageStartupMessages(invisible(lapply(paquetes, library, character.only = TRUE)))

id          <- "05_salario_minimo"
archivo_smi <- "1_Datos/Fuentes/Costo, salario, población/Salario minimo.xlsx"
archivo_ipc <- "1_Datos/Fuentes/IPC/anex-IPC-Indices-sep2026.xlsx"
archivo_pro <- "4_Pronostico_2030/salidas/04_ipc_pronostico.xlsx"
ventana     <- 2019:2026
salario_2027_decretado <- NA     # cuando se decrete, por ejemplo 1950000
carpeta     <- "4_Pronostico_2030/salidas"
dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)
if (!file.exists(archivo_pro)) stop("Falta ", archivo_pro, ": correr antes 04_ipc.R")

# --- 1. Datos ---------------------------------------------------------------
smi <- suppressWarnings(read_excel(archivo_smi, sheet = "Series de datos", skip = 3, col_names = FALSE,
                                   col_types = c("date", "numeric", "numeric", "numeric", "numeric"),
                                   .name_repair = "minimal"))
smi <- data.frame(anio = as.integer(format(smi[[1]], "%Y")), salario = smi[[3]])
smi <- smi[!is.na(smi$anio) & !is.na(smi$salario), ]

x <- read_excel(archivo_ipc, col_names = FALSE, .name_repair = "minimal")
fila <- which(x[[1]] == "Mes")[1]
anios <- suppressWarnings(as.integer(unlist(x[fila, -1]))); anios <- anios[!is.na(anios)]
dic <- suppressWarnings(as.numeric(unlist(x[fila + 12, 2:(length(anios) + 1)])))
infl_obs <- data.frame(anio = anios[-1], inflacion = (dic[-1] / dic[-length(dic)] - 1) * 100)
infl_obs <- infl_obs[!is.na(infl_obs$inflacion), ]

resumen_ipc <- read_excel(archivo_pro, sheet = "resumen_anual")
infl_pro <- resumen_ipc[resumen_ipc$anio >= 2026, c("anio", "inflacion_dic_base", "inflacion_dic_bajo", "inflacion_dic_alto")]
# inflación de 2031 (para enero de 2031 no se necesita: el salario de 2031 usa la de 2030)

# --- 2. Prima observada en la ventana -----------------------------------------
d <- merge(smi, transform(infl_obs, anio = anio + 1, inflacion_anio_anterior = inflacion)[, c("anio", "inflacion_anio_anterior")], by = "anio")
d$aumento <- (d$salario / smi$salario[match(d$anio - 1, smi$anio)] - 1) * 100
d$prima <- d$aumento - d$inflacion_anio_anterior
v <- d[d$anio %in% ventana, ]
q <- quantile(v$prima, c(0.25, 0.75), type = 7)
cerca <- q[2] + 1.5 * (q[2] - q[1])
v$atipico <- v$prima > cerca
prima <- c(base = median(v$prima), bajo = 0, alto = max(v$prima[!v$atipico]))
cat("Prima por año en la ventana (pp):\n"); print(round(v[, c("anio", "aumento", "inflacion_anio_anterior", "prima")], 2), row.names = FALSE)
cat("Cerca superior de Tukey =", round(cerca, 2), "| atípicos:", v$anio[v$atipico], "\n")
cat("Prima base =", round(prima["base"], 2), "| bajo =", prima["bajo"], "| alto =", round(prima["alto"], 2), "\n")

# --- 3. Proyección -------------------------------------------------------------
proy <- data.frame(anio = 2027:2031)
for (esc in c("base", "bajo", "alto")) {
  s <- smi$salario[smi$anio == 2026]
  vals <- numeric(0)
  for (a in proy$anio) {
    inf_prev <- as.numeric(infl_pro[infl_pro$anio == a - 1, paste0("inflacion_dic_", esc)])
    s <- round(s * (1 + inf_prev / 100 + prima[esc] / 100))
    if (a == 2027 && !is.na(salario_2027_decretado)) s <- salario_2027_decretado
    vals <- c(vals, s)
  }
  proy[[esc]] <- vals
}
proy$aumento_base_pct <- round((proy$base / c(smi$salario[smi$anio == 2026], head(proy$base, -1)) - 1) * 100, 2)
print(proy, row.names = FALSE)

# --- 4. Tablas de salida -------------------------------------------------------
anual <- rbind(data.frame(anio = smi$anio[smi$anio %in% 2019:2026], tipo = "observado",
                          base = smi$salario[smi$anio %in% 2019:2026], bajo = smi$salario[smi$anio %in% 2019:2026],
                          alto = smi$salario[smi$anio %in% 2019:2026]),
               data.frame(anio = proy$anio, tipo = "pronostico", base = proy$base, bajo = proy$bajo, alto = proy$alto))
fechas <- seq(as.Date("2019-01-01"), as.Date("2031-01-01"), by = "month")
mensual <- data.frame(fecha = fechas, anio = as.integer(format(fechas, "%Y")), mes = as.integer(format(fechas, "%m")))
mensual$tipo <- ifelse(mensual$fecha <= as.Date("2026-09-01"), "observado", "pronostico")
mensual <- cbind(mensual, anual[match(mensual$anio, anual$anio), c("base", "bajo", "alto")])

metodo <- data.frame(
  concepto = c("Serie", "Fuentes", "Unidad", "Ventana de entrenamiento", "Método",
               "Prima base (mediana 2019-2026, pp)", "Prima bajo (pp)", "Prima alto (pp)", "Años atípicos (Tukey)",
               "Inflación usada", "Salario 2027 (base / bajo / alto)", "Salario 2030 (base / bajo / alto)", "Nota", "Fecha de corrida"),
  valor = c("Salario mínimo mensual legal", "Banco de la República (Salario minimo.xlsx); DANE (IPC); 04_ipc.R",
            "COP por mes", "2019-2026 (primas de esos ocho años)",
            "salario_a = salario_(a-1) x (1 + inflación dic/dic del año anterior + prima)",
            round(prima["base"], 2), "0 (piso legal: Corte Constitucional, Sentencia C-815 de 1999)",
            paste0(round(prima["alto"], 2), " (máxima de la ventana sin años atípicos)"),
            paste(v$anio[v$atipico], collapse = ", "),
            "La del mismo escenario en 04_ipc.R (2026: 7,1 % en los tres)",
            paste(proy$base[proy$anio == 2027], proy$bajo[proy$anio == 2027], proy$alto[proy$anio == 2027], sep = " / "),
            paste(proy$base[proy$anio == 2030], proy$bajo[proy$anio == 2030], proy$alto[proy$anio == 2030], sep = " / "),
            ifelse(is.na(salario_2027_decretado),
                   "El salario de 2027 se decreta en diciembre de 2026; cuando se conozca, escribirlo en salario_2027_decretado y volver a correr.",
                   paste("Salario de 2027 decretado:", salario_2027_decretado)),
            format(Sys.Date(), "%Y-%m-%d")))

guardar_excel <- function(hojas, archivo_salida) {
  write_xlsx(hojas, archivo_salida, format_headers = TRUE)
}
prima_tabla <- v[, c("anio", "salario", "aumento", "inflacion_anio_anterior", "prima", "atipico")]
prima_tabla[c("aumento", "inflacion_anio_anterior", "prima")] <- lapply(prima_tabla[c("aumento", "inflacion_anio_anterior", "prima")], round, 2)
guardar_excel(list(pronostico = mensual, anual = anual, prima_2019_2026 = prima_tabla, metodo = metodo),
              file.path(carpeta, paste0(id, "_pronostico.xlsx")))

largo <- rbind(data.frame(anio = anual$anio, valor = anual$base / 1e6, serie = ifelse(anual$tipo == "observado", "Observado", "Base")),
               data.frame(anio = proy$anio, valor = proy$bajo / 1e6, serie = "Bajo"),
               data.frame(anio = proy$anio, valor = proy$alto / 1e6, serie = "Alto"))
g <- ggplot(largo, aes(anio, valor, colour = serie)) + geom_step(linewidth = 0.6) + geom_point(size = 1.2) +
  scale_colour_manual(values = c(Observado = "black", Base = "#1F3B70", Bajo = "#5B8C5A", Alto = "#B03A2E")) +
  labs(title = "Salario mínimo mensual (millones de pesos)",
       subtitle = "Regla: inflación del año anterior + prima medida en 2019-2026", x = NULL, y = NULL, colour = NULL) +
  theme_minimal(base_size = 10) + theme(legend.position = "bottom")
ggsave(file.path(carpeta, paste0(id, "_pronostico.png")), g, width = 16, height = 9, units = "cm", dpi = 200, bg = "white")
cat("Listo:", file.path(carpeta, paste0(id, "_pronostico.xlsx")), "\n")
