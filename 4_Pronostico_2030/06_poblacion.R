# =============================================================================
# 06_poblacion.R
# Población de Colombia, 2019 a 2031.
#
# Fuente: DANE, Proyecciones de Población y Estudios Demográficos (PPED),
#   actualización del 18 de julio de 2025, serie nacional 2018-2070
#   (PPED-AreaNac-2018-2070- poblacion personas.xlsx), área "Total".
#
# Por qué no se pronostica: el DANE ya proyecta la población con el modelo de
#   componentes de cohortes (fecundidad, mortalidad y migración). Un ARIMA con
#   ocho datos anuales no puede mejorar esa proyección oficial; se toma tal cual.
#   No hay escenarios: el DANE publica una sola proyección (bajo = alto = base).
#
# Conversión: el dato de cada año corresponde al 30 de junio. Para cada mes se
#   interpola en línea recta al día 15, igual que la hoja mensual de la base; las
#   semanas se interpolan en la base con la misma regla.
#
# Correr desde la carpeta del artículo (proyecto de RStudio), con R 4.2 o más reciente.
# =============================================================================

paquetes <- c("readxl", "writexl", "ggplot2")
faltan <- paquetes[!sapply(paquetes, requireNamespace, quietly = TRUE)]
if (length(faltan) > 0) install.packages(faltan)
suppressPackageStartupMessages(invisible(lapply(paquetes, library, character.only = TRUE)))

id      <- "06_poblacion"
archivo <- "1_Datos/Fuentes/Costo, salario, población/PPED-AreaNac-2018-2070- poblacion personas.xlsx"
carpeta <- "4_Pronostico_2030/salidas"
dir.create(carpeta, recursive = TRUE, showWarnings = FALSE)

# --- 1. Datos ---------------------------------------------------------------
x <- read_excel(archivo, sheet = "PobNacionalxÁrea", col_names = FALSE, .name_repair = "minimal")
fila <- which(x[[1]] == "TERRITORIO")[1]
d <- x[(fila + 1):nrow(x), 1:4]
names(d) <- c("territorio", "anio", "area", "poblacion")
d <- d[!is.na(d$area) & d$area == "Total", ]
anual <- data.frame(anio = as.integer(d$anio), poblacion_30_junio = as.numeric(d$poblacion))
anual <- anual[anual$anio >= 2018 & anual$anio <= 2031, ]
anual$crecimiento_pct <- round(c(NA, diff(anual$poblacion_30_junio) / head(anual$poblacion_30_junio, -1) * 100), 3)
anual$tipo <- ifelse(anual$anio <= 2026, "observado", "pronostico")
print(anual, row.names = FALSE)

# --- 2. Interpolación mensual al día 15 ----------------------------------------
fechas <- seq(as.Date("2019-01-01"), as.Date("2031-01-01"), by = "month")
dia15 <- fechas + 14
junios <- as.Date(paste0(anual$anio, "-06-30"))
pob_mes <- approx(as.numeric(junios), anual$poblacion_30_junio, xout = as.numeric(dia15))$y
mensual <- data.frame(fecha = fechas, anio = as.integer(format(fechas, "%Y")), mes = as.integer(format(fechas, "%m")),
                      tipo = ifelse(fechas <= as.Date("2026-09-01"), "observado", "pronostico"),
                      base = round(pob_mes), bajo = round(pob_mes), alto = round(pob_mes))

metodo <- data.frame(
  concepto = c("Serie", "Fuente", "Unidad", "Método", "Escenarios", "Conversión mensual", "Población 2030", "Fecha de corrida"),
  valor = c("Población total de Colombia", "DANE, PPED 2018-2070 (actualización 18-jul-2025), área Total",
            "Personas al 30 de junio", "Proyección oficial por componentes de cohortes; no se ajusta ningún modelo",
            "Uno solo (el DANE publica una sola proyección)", "Interpolación lineal al día 15 de cada mes entre los 30 de junio",
            format(anual$poblacion_30_junio[anual$anio == 2030], big.mark = ".", decimal.mark = ","), format(Sys.Date(), "%Y-%m-%d")))

guardar_excel <- function(hojas, archivo_salida) {
  write_xlsx(hojas, archivo_salida, format_headers = TRUE)
}
guardar_excel(list(pronostico = anual, mensual = mensual, metodo = metodo), file.path(carpeta, paste0(id, "_pronostico.xlsx")))

g <- ggplot(anual, aes(anio, poblacion_30_junio / 1e6, colour = tipo)) + geom_line(linewidth = 0.6) + geom_point(size = 1.4) +
  scale_colour_manual(values = c(observado = "black", pronostico = "#1F3B70"), labels = c("Hasta 2026", "2027-2031")) +
  labs(title = "Población de Colombia al 30 de junio (millones)", subtitle = "DANE, PPED 2018-2070 (actualización de julio de 2025)",
       x = NULL, y = NULL, colour = NULL) +
  theme_minimal(base_size = 10) + theme(legend.position = "bottom")
ggsave(file.path(carpeta, paste0(id, "_pronostico.png")), g, width = 16, height = 9, units = "cm", dpi = 200, bg = "white")
cat("Listo:", file.path(carpeta, paste0(id, "_pronostico.xlsx")), "\n")
