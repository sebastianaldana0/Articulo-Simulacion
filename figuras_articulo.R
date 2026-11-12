
# =====================================================================
# FIGURAS Y TABLAS DEL ARTÍCULO: descripción del problema
# Ciclo del huevo en Colombia, 2019-2026


paquetes <- c("readxl", "dplyr", "tidyr", "ggplot2", "lubridate",
              "patchwork", "scales", "flextable", "ragg")
nuevos <- setdiff(paquetes, rownames(installed.packages()))
if (length(nuevos)) install.packages(nuevos)
invisible(lapply(paquetes, library, character.only = TRUE))

ARCHIVO    <- "Base final- Borrador.xlsx"
CARPETA    <- "figuras_articulo"
FIN_OBS    <- as.Date("2025-12-31")   # producción observada hasta dic-2025; ene-sep 2026 estimada
INICIO     <- as.Date("2019-01-01")   # inicio de las figuras (igual que el modelo)
CON_TITULO <- FALSE   # TRUE pone el título dentro de cada figura; FALSE lo deja para la leyenda de Word
ANCHO      <- 16.5    # cm: ancho útil de una hoja carta con márgenes de 2,5 cm
DPI        <- 300
dir.create(CARPETA, showWarnings = FALSE)

# ---- Colores, estilo y funciones de apoyo ---------------------------
COL <- c(enc = "#1b6ca8", prod = "#c0392b", precio = "#e67e22",
         costo = "#27ae60", razon = "#8e44ad")
COL_FASE <- c(`Encasetamiento en expansión` = "#f5b041",
              `Encasetamiento en contracción` = "#5dade2")
COL_CCF <- c(`Sin tendencia` = "#8e44ad", `Diferencia anual` = "#1b6ca8")
tema <- theme_minimal(base_size = 9.5) +
  theme(panel.grid.minor = element_blank(),
        legend.position = "top", legend.title = element_blank(),
        legend.margin = margin(0, 0, 0, 0),
        axis.title.y = element_text(size = 8.5),
        plot.subtitle = element_text(size = 8.5, colour = "grey20"),
        plot.caption = element_text(hjust = 0, colour = "grey30", size = 7.5),
        plot.tag = element_text(face = "bold", size = 9.5))
eje_fecha <- function(desde = INICIO, hasta = max(men$fecha)) {
  list(scale_x_date(date_breaks = "1 year", date_labels = "%Y", expand = c(0.01, 0)),
       coord_cartesian(xlim = c(desde, hasta)))
}
tit <- function(t) if (CON_TITULO) t else NULL
# Parte la nota en renglones que caben en el ancho de la figura; cada "\n" abre párrafo
envolver <- function(x, ancho = 118)
  paste(unlist(lapply(strsplit(x, "\n", fixed = TRUE)[[1]], strwrap, width = ancho)), collapse = "\n")
anotacion <- function(titulo = NULL, nota = NULL, letras = TRUE)
  plot_annotation(title = tit(titulo), caption = envolver(nota),
                  tag_levels = if (letras) "a" else NULL, tag_prefix = "(", tag_suffix = ")",
                  theme = theme(plot.caption = element_text(hjust = 0, colour = "grey30", size = 7.5),
                                plot.title = element_text(size = 11)))
guardar <- function(p, nombre, alto_cm) {
  ggsave(file.path(CARPETA, nombre), p, width = ANCHO, height = alto_cm,
         units = "cm", dpi = DPI, bg = "white")
  cat("  guardado:", nombre, "\n")
}
guardar_tabla <- function(ft, nombre) {
  save_as_image(ft, path = file.path(CARPETA, nombre), res = DPI)
  cat("  guardado:", nombre, "\n")
}
estilo_tabla <- function(ft, anchos, nota) {
  ft |>
    theme_booktabs() |>
    fontsize(size = 8.5, part = "all") |>
    bold(part = "header") |>
    align(align = "center", part = "header") |>
    valign(valign = "top", part = "body") |>
    set_table_properties(layout = "fixed") |>
    width(j = seq_along(anchos), width = anchos) |>
    add_footer_lines(nota) |>
    fontsize(size = 7.5, part = "footer")
}
# Números con coma decimal y punto de miles
fmt <- function(x, d = 1) ifelse(is.na(x), "—",
  formatC(x, format = "f", digits = d, big.mark = ".", decimal.mark = ","))
fmt_pct <- function(x, d = 1) ifelse(is.na(x), "—", paste0(ifelse(x > 0, "+", ""), fmt(x, d), "%"))
MESES <- c("ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic")
mes_anio <- function(f) sprintf("%s-%d", MESES[month(f)], year(f))
# Suma móvil de 12 meses (quita la estacionalidad y el ruido mensual)
s12 <- function(x) {
  cs <- cumsum(x)
  out <- cs - dplyr::lag(cs, 12, default = 0)
  out[seq_len(min(11, length(x)))] <- NA
  out
}
# Correlación cruzada: x ADELANTA a y k pasos  ->  cor(x[t], y[t+k])
ccf_cruzada <- function(x, y, lag_max) {
  n <- length(x)
  sapply(0:lag_max, function(k) cor(x[1:(n - k)], y[(1 + k):n]))
}
quitar_tendencia <- function(x) as.numeric(resid(lm(x ~ seq_along(x))))

# ---- Datos ------------------------------------------------------------
men <- read_excel(ARCHIVO, sheet = "mensual") |>
  mutate(fecha = as.Date(fecha)) |> arrange(fecha)
sem <- read_excel(ARCHIVO, sheet = "semanal") |>
  mutate(fecha_inicio = as.Date(fecha_inicio), fecha_fin = as.Date(fecha_fin))
anu <- read_excel(ARCHIVO, sheet = "anual") |> mutate(anio = as.numeric(anio))
ipc19 <- mean(men$ipc_total[year(men$fecha) == 2019])   # base del precio real (pesos de 2019)

d <- men |>
  mutate(estimada    = fecha > FIN_OBS,
         enc_m       = encasetamiento_pollitas / 1e6,
         enc_12      = s12(encasetamiento_pollitas),
         enc_prom12  = enc_12 / 12 / 1e6,
         prod        = produccion_huevos_millones,
         prod_12     = s12(prod),
         precio_real = precio_huevo_real_2019,
         costo_real  = costo_produccion_fenavi * ipc19 / ipc_total,
         razon       = precio_huevo_rojo_aa_promedio / costo_produccion_fenavi,
         v_enc       = 100 * (enc_12 / lag(enc_12, 12) - 1),    # últimos 12 meses vs 12 anteriores
         v_prod      = 100 * (prod_12 / lag(prod_12, 12) - 1),
         pc          = prod * 1e6 * 12 / poblacion)              # huevos por habitante al año

# ---- Cálculos que usan varias figuras y tablas -------------------------
# Fases de expansión / contracción del encasetamiento (signo de su variación anual)
fases0 <- d |>
  filter(!is.na(v_enc)) |>
  mutate(fase = ifelse(v_enc >= 0, "expansión", "contracción"),
         grupo = cumsum(fase != lag(fase, default = first(fase)))) |>
  group_by(grupo, fase) |>
  summarise(xmin = min(fecha), xmax = max(fecha) %m+% months(1), meses = n(), .groups = "drop")
fases <- fases0 |>
  filter(xmax > INICIO) |>
  mutate(xmin = pmax(xmin, INICIO),
         fase = ifelse(fase == "expansión", names(COL_FASE)[1], names(COL_FASE)[2]))
capa_fases <- function()
  geom_rect(data = fases, aes(xmin = xmin, xmax = xmax, ymin = -Inf, ymax = Inf, fill = fase),
            inherit.aes = FALSE, alpha = 0.18)
escala_fases <- scale_fill_manual(values = COL_FASE)

# Rezago entre las variaciones anuales de encasetamiento y producción (meses, observado)
obs_m  <- d |> filter(!estimada, !is.na(v_enc), !is.na(v_prod))
cc12   <- ccf_cruzada(obs_m$v_enc, obs_m$v_prod, 24)
lag12  <- which.max(cc12) - 1
r12    <- max(cc12)
# Picos y valles: máximos o mínimos locales (en una ventana de ±12 meses) de cada
# variación anual. Cada extremo del encasetamiento se une con el primer extremo del
# mismo tipo de la producción entre 6 y 18 meses después (ventana t-18 a t-5 de Fenavi).
extremos <- function(x, tipo, ventana = 12) {
  n <- length(x)
  which(vapply(seq_len(n), function(i) {
    if (is.na(x[i]) || i == n) return(FALSE)          # el último dato no es extremo confirmado
    w <- max(1, i - ventana):min(n, i + ventana)
    if (tipo == "max") x[i] == max(x[w], na.rm = TRUE) else x[i] == min(x[w], na.rm = TRUE)
  }, logical(1)))
}
mes_num <- function(f) year(f) * 12 + month(f)
eventos <- bind_rows(lapply(c("max", "min"), function(tipo) {
  ie <- extremos(d$v_enc, tipo)
  ip <- extremos(d$v_prod, tipo)
  bind_rows(lapply(ie, function(i) {
    dif <- mes_num(d$fecha[ip]) - mes_num(d$fecha[i])
    j <- ip[dif >= 6 & dif <= 18]
    if (!length(j)) return(NULL)
    j <- j[1]
    tibble(tipo = tipo, f_enc = d$fecha[i], v_enc = d$v_enc[i],
           f_prod = d$fecha[j], v_prod = d$v_prod[j],
           meses = mes_num(d$fecha[j]) - mes_num(d$fecha[i]))
  }))
})) |> filter(f_enc >= INICIO) |> arrange(f_enc)

# Encasetamiento -> producción, semanal (rezagos 0 a 104 semanas, solo producción observada)
obs_s  <- sem |> filter(fecha_fin <= FIN_OBS)
LAG_S  <- 104
ccf_s  <- tibble(
  k = 0:LAG_S,
  `Sin tendencia` = ccf_cruzada(quitar_tendencia(obs_s$encasetamiento_pollitas),
                                quitar_tendencia(obs_s$produccion_huevos_millones), LAG_S),
  `Diferencia anual` = ccf_cruzada(diff(obs_s$encasetamiento_pollitas, lag = 52),
                                   diff(obs_s$produccion_huevos_millones, lag = 52), LAG_S))
lag_s   <- ccf_s$k[which.max(ccf_s$`Sin tendencia`)]
r_s     <- max(ccf_s$`Sin tendencia`)
n_ef    <- n_distinct(format(obs_s$fecha_inicio, "%Y-%m"))   # n efectivo: meses
banda_s <- 1.96 / sqrt(n_ef)
r_pp    <- cor(quitar_tendencia(obs_s$produccion_huevos_millones),
               quitar_tendencia(obs_s$precio_huevo_real_2019))

# Margen -> encasetamiento, mensual (rezagos 0 a 24 meses; todo observado)
mg <- d |> filter(!is.na(razon)) |>
  mutate(enc_dia = encasetamiento_pollitas / dias_mes)   # quita el efecto del número de días
LAG_M <- 24
ccf_m <- tibble(
  k = 0:LAG_M,
  `Sin tendencia` = ccf_cruzada(quitar_tendencia(log(mg$razon)),
                                quitar_tendencia(log(mg$enc_dia)), LAG_M),
  `Diferencia anual` = ccf_cruzada(diff(log(mg$razon), lag = 12),
                                   diff(log(mg$enc_dia), lag = 12), LAG_M))
n_m     <- nrow(mg) - 12
banda_m <- 1.96 / sqrt(n_m)
lag_dec <- ccf_m$k[which.max(ccf_m$`Diferencia anual`)]
r_dec   <- max(ccf_m$`Diferencia anual`)
sobre   <- ccf_m$`Diferencia anual` > banda_m
i_ini <- i_fin <- which(ccf_m$k == lag_dec)
while (i_ini > 1 && sobre[i_ini - 1]) i_ini <- i_ini - 1
while (i_fin < nrow(ccf_m) && sobre[i_fin + 1]) i_fin <- i_fin + 1
tramo_dec <- ccf_m$k[c(i_ini, i_fin)]

# Brecha de oferta: producción por habitante frente a su tendencia log-lineal
d3 <- d |> filter(!is.na(poblacion)) |> mutate(t = row_number())
obs3 <- !d3$estimada
fq <- lm(log(pc) ~ t, data = d3[obs3, ])
fp <- lm(log(precio_real) ~ t, data = d3[obs3, ])
d3 <- d3 |>
  mutate(brecha = 100 * (pc / exp(predict(fq, newdata = d3)) - 1),
         dev_p  = 100 * (precio_real / exp(predict(fp, newdata = d3)) - 1),
         tipo   = ifelse(brecha >= 0, "Sobreoferta (sobre la tendencia)",
                         "Faltante (bajo la tendencia)"))
r_bp    <- with(d3[obs3, ], cor(brecha, dev_p))
crec_pc <- 100 * (exp(coef(fq)[["t"]] * 12) - 1)   # crecimiento anual de la tendencia
ini_pc  <- mes_anio(min(d3$fecha))

ley <- list()   # leyendas sugeridas para Word
cat("\nGenerando figuras y tablas en la carpeta", CARPETA, "\n")

# =====================================================================
# 01. TABLA 1. Datos utilizados
# =====================================================================
periodo <- function(v) {
  f <- men$fecha[!is.na(men[[v]])]
  paste(mes_anio(min(f)), "a", mes_anio(max(f)))
}
t1 <- tribble(
  ~Variable, ~Unidad, ~Frecuencia, ~Periodo, ~Fuente,
  "Encasetamiento de pollitas de postura", "pollitas/mes", "Mensual",
  periodo("encasetamiento_pollitas"), "Fenavi, estadísticas de encasetamiento",
  "Producción de huevo", "millones de huevos/mes", "Mensual",
  "ene-2017 a dic-2025 (ene-sep 2026 estimada)",
  "Fenavi, Fenaviquín ed. 440; 2026: estimación propia con el encasetamiento",
  "Precio mayorista del huevo rojo AA", "pesos/unidad", "Mensual",
  periodo("precio_huevo_rojo_aa_promedio"), "DANE, SIPSA (promedio de 19 mercados)",
  "Costo de producción por huevo", "pesos/unidad", "Mensual",
  periodo("costo_produccion_fenavi"), "Fenavi, Fenaviquín (sin amortización del ave)",
  "Índice de precios al consumidor", "dic-2018 = 100", "Mensual",
  periodo("ipc_total"), "DANE",
  "Precio del maíz amarillo", "US$/tonelada", "Mensual",
  periodo("precio_maiz_usd_t"), "Banco Mundial, Pink Sheet",
  "Precio de la torta de soya", "US$/tonelada", "Mensual",
  periodo("precio_torta_soya_usd_t"), "Banco Mundial, Pink Sheet",
  "Tasa representativa del mercado", "pesos/US$", "Diaria",
  periodo("trm"), "Banco de la República",
  "Salario mínimo", "pesos/mes", "Anual",
  "2017 a 2026", "Banco de la República",
  "Población", "personas", "Anual (30 de junio)",
  "2018 a 2028", "DANE, proyecciones de población (actualización jul-2025)",
  "Capacidad instalada de postura", "aves", "Anual", "2019 a 2025",
  "ICA, censo pecuario avícola")
ft1 <- flextable(t1) |>
  set_header_labels(Periodo = "Período") |>
  estilo_tabla(c(1.7, 1.05, 0.8, 1.35, 1.6),
               "Todas las series se llevan a frecuencia semanal y mensual en la base de datos del modelo.")
guardar_tabla(ft1, "01_tabla1_datos.png")
ley$t1 <- c("Tabla 1. Datos utilizados.",
            "Fuente: elaboración propia con base en Fenavi, DANE, Banco Mundial, Banco de la República e ICA.")

# =====================================================================
# 02. FIGURA 1. Series temporales (modo de referencia)
# =====================================================================
d1 <- d |> filter(fecha >= INICIO)
p1a <- ggplot(d1, aes(fecha)) + capa_fases() + escala_fases +
  geom_line(aes(y = enc_m, colour = "Mensual"), linewidth = 0.35) +
  geom_line(aes(y = enc_prom12, colour = "Promedio de 12 meses"), linewidth = 0.9) +
  scale_colour_manual(values = c(Mensual = "#9ec3e0", `Promedio de 12 meses` = COL[["enc"]])) +
  guides(fill = guide_legend(order = 1, nrow = 1), colour = guide_legend(order = 2, nrow = 1)) +
  labs(x = NULL, y = "Encasetamiento\n(millones de pollitas/mes)") +
  tema + theme(legend.box = "vertical", legend.spacing.y = unit(0, "pt")) + eje_fecha()
p1b <- ggplot(d1, aes(fecha, prod)) + capa_fases() + escala_fases +
  geom_line(data = filter(d1, !estimada), colour = COL[["prod"]], linewidth = 0.9) +
  geom_line(data = filter(d1, fecha >= FIN_OBS - 31), colour = COL[["prod"]],
            linewidth = 0.9, linetype = "22") +
  annotate("text", x = as.Date("2026-05-01"), y = max(d1$prod) * 1.01, vjust = 0,
           size = 2.8, label = "estimada") +
  labs(x = NULL, y = "Producción\n(millones de huevos/mes)") +
  tema + theme(legend.position = "none") + eje_fecha()
d1c <- d1 |>
  select(fecha, `Precio real` = precio_real, `Costo real` = costo_real) |>
  pivot_longer(-fecha, names_to = "serie", values_to = "v")
p1c <- ggplot(d1c, aes(fecha, v)) + capa_fases() + escala_fases +
  geom_line(aes(colour = serie), linewidth = 0.8, na.rm = TRUE) +
  scale_colour_manual(values = c(`Precio real` = COL[["precio"]], `Costo real` = COL[["costo"]])) +
  guides(fill = "none") +
  labs(x = NULL, y = "Pesos de 2019\npor huevo") + tema + eje_fecha()
fig1 <- p1a / p1b / p1c +
  anotacion("Encasetamiento, producción, precio y costo del huevo en Colombia, 2019-2026",
            paste0("Nota: sombreado según el signo de la variación anual del encasetamiento (suma de 12 meses). ",
                   "Precio: huevo rojo AA, mayorista; costo: Fenavi, sin amortización del ave; ",
                   "ambos deflactados con el IPC. Línea discontinua: producción estimada.\n",
                   "Fuente: elaboración propia con base en Fenavi, DANE-SIPSA y DANE-IPC."))
guardar(fig1, "02_figura1_series_temporales.png", 19)
ley$f1 <- c("Figura 1. Encasetamiento, producción, precio y costo del huevo en Colombia, 2019-2026.",
            paste0("Cada fase de expansión del encasetamiento antecede un aumento de la producción y una caída del ",
                   "precio real; las fases de contracción, lo contrario. La producción de ene-sep 2026 es estimada."),
            "Fuente: elaboración propia con base en Fenavi, DANE-SIPSA y DANE-IPC.")

# =====================================================================
# 03. TABLA 2. Magnitud del problema (cuánto)
# =====================================================================
an <- men |>
  mutate(anio = year(fecha)) |>
  group_by(anio) |>
  summarise(meses = n(),
            enc = sum(encasetamiento_pollitas) / 1e6,
            prod = sum(produccion_huevos_millones),
            precio_real = mean(precio_huevo_real_2019),
            costo_real = mean(costo_produccion_fenavi * ipc19 / ipc_total),
            razon = mean(precio_huevo_rojo_aa_promedio / costo_produccion_fenavi),
            .groups = "drop") |>
  filter(meses == 12) |>
  left_join(anu |> transmute(anio, pc = consumo_per_capita_aparente,
                             cap = ica_postura_capacidad_instalada / 1e6), by = "anio") |>
  arrange(anio)
ytd <- men |>
  filter(year(fecha) %in% c(2025, 2026), month(fecha) <= 9) |>
  group_by(anio = year(fecha)) |>
  summarise(enc = sum(encasetamiento_pollitas), prod = sum(produccion_huevos_millones),
            precio_real = mean(precio_huevo_real_2019),
            costo_real = mean(costo_produccion_fenavi * ipc19 / ipc_total),
            razon = mean(precio_huevo_rojo_aa_promedio / costo_produccion_fenavi),
            pob = mean(poblacion), .groups = "drop") |>
  summarise(across(-anio, ~ 100 * (.x[anio == 2026] / .x[anio == 2025] - 1))) |>
  mutate(pc = 100 * ((1 + prod / 100) / (1 + pob / 100) - 1))

fila_mag <- function(v, nombre, unidad, d_niv = 1) {
  x  <- an |> select(anio, val = all_of(v)) |> mutate(var = 100 * (val / lag(val) - 1))
  xs <- x |> filter(anio >= 2019, !is.na(val))
  vv <- xs |> filter(!is.na(var))
  tibble(Variable = nombre, Unidad = unidad,
         Promedio = fmt(mean(xs$val), d_niv),
         `Mínimo (año)` = sprintf("%s (%d)", fmt(min(xs$val), d_niv), xs$anio[which.min(xs$val)]),
         `Máximo (año)` = sprintf("%s (%d)", fmt(max(xs$val), d_niv), xs$anio[which.max(xs$val)]),
         `Mayor alza anual` = sprintf("%s (%d)", fmt_pct(max(vv$var)), vv$anio[which.max(vv$var)]),
         `Mayor caída anual` = sprintf("%s (%d)", fmt_pct(min(vv$var)), vv$anio[which.min(vv$var)]),
         `Ene-sep 2026 vs 2025` = if (v %in% names(ytd)) fmt_pct(ytd[[v]]) else "—")
}
t2 <- bind_rows(
  fila_mag("enc", "Encasetamiento", "millones de pollitas/año", 1),
  fila_mag("prod", "Producción", "millones de huevos/año", 0),
  fila_mag("pc", "Consumo aparente por habitante", "huevos/año", 0),
  fila_mag("precio_real", "Precio real", "pesos de 2019/huevo", 0),
  fila_mag("costo_real", "Costo real", "pesos de 2019/huevo", 0),
  fila_mag("razon", "Razón precio/costo", "veces", 2),
  fila_mag("cap", "Capacidad instalada de postura (ICA)", "millones de aves", 1))
ft2 <- flextable(t2) |>
  estilo_tabla(c(1.25, 0.95, 0.6, 0.8, 0.8, 0.75, 0.75, 0.6),
               paste0("Años completos 2019-2025; la variación anual de 2019 se calcula frente a 2018 cuando hay dato. ",
                      "Consumo aparente = producción / población. Razón = precio mayorista / costo sin amortización ",
                      "del ave. En 2026 la producción es estimada.")) |>
  align(j = 3:8, align = "center", part = "body")
guardar_tabla(ft2, "03_tabla2_magnitud_problema.png")
ley$t2 <- c("Tabla 2. Magnitud de las oscilaciones del sector, 2019-2026.",
            "Fuente: elaboración propia con base en Fenavi, DANE-SIPSA, DANE e ICA.")

# =====================================================================
# 04. FIGURA 2. El rezago: encasetamiento -> producción
# =====================================================================
d2 <- d |> filter(fecha >= INICIO, !is.na(v_enc)) |>
  select(fecha, estimada, Encasetamiento = v_enc, Producción = v_prod) |>
  pivot_longer(c(Encasetamiento, Producción), names_to = "serie", values_to = "v")
fig2 <- ggplot(d2, aes(fecha, v, colour = serie)) +
  geom_hline(yintercept = 0, colour = "grey50") +
  geom_line(data = filter(d2, !(serie == "Producción" & estimada)), linewidth = 0.9) +
  geom_line(data = filter(d2, serie == "Producción", fecha >= FIN_OBS - 31),
            linewidth = 0.9, linetype = "22", show.legend = FALSE) +
  geom_segment(data = eventos, aes(x = f_enc, y = v_enc, xend = f_prod, yend = v_prod),
               inherit.aes = FALSE, colour = "grey25", linewidth = 0.4,
               arrow = arrow(length = unit(0.16, "cm"), type = "closed")) +
  geom_point(data = eventos, aes(f_enc, v_enc), inherit.aes = FALSE, colour = COL[["enc"]], size = 1.6) +
  geom_point(data = eventos, aes(f_prod, v_prod), inherit.aes = FALSE, colour = COL[["prod"]], size = 1.6) +
  geom_label(data = eventos, aes(x = f_enc + (f_prod - f_enc) / 2, y = (v_enc + v_prod) / 2,
                                 label = paste0("+", meses, " meses")),
             inherit.aes = FALSE, size = 2.9, fontface = "bold", colour = "grey15",
             fill = "white", label.size = 0, label.padding = unit(0.12, "lines")) +
  scale_colour_manual(values = c(Encasetamiento = COL[["enc"]], Producción = COL[["prod"]])) +
  labs(x = NULL, y = "Variación anual (%)\n(suma de 12 meses)", title = tit("El rezago entre encasetamiento y producción"),
       caption = envolver(sprintf(paste0(
         "Nota: variación de la suma de 12 meses frente a los 12 anteriores. Las flechas unen cada pico o valle ",
         "del encasetamiento (extremo en una ventana de ±12 meses) con el de la producción entre 6 y 18 meses ",
         "después. La correlación entre las dos variaciones es máxima con %d meses de rezago (r = %s). ",
         "Línea discontinua: producción estimada.\n",
         "Fuente: elaboración propia con base en Fenavi."), lag12, fmt(r12, 2)))) +
  tema + theme(plot.caption.position = "plot") + eje_fecha()
guardar(fig2, "04_figura2_rezago_encasetamiento_produccion.png", 9.5)
ley$f2 <- c("Figura 2. Variación anual del encasetamiento y de la producción de huevo, 2019-2026.",
            sprintf(paste0("La producción repite los movimientos del encasetamiento con un rezago de %s meses ",
                           "(correlación máxima a los %d meses, r = %s): lo que se encaseta hoy define la oferta ",
                           "del año siguiente."),
                    if (min(eventos$meses) == max(eventos$meses)) as.character(min(eventos$meses))
                    else sprintf("%d a %d", min(eventos$meses), max(eventos$meses)),
                    lag12, fmt(r12, 2)),
            "Fuente: elaboración propia con base en Fenavi.")

# =====================================================================
# 05. FIGURA 3. Sobreoferta y precio
# =====================================================================
d3f <- d3 |> filter(fecha >= INICIO)
p3a <- ggplot(d3f, aes(fecha, brecha, fill = tipo)) +
  geom_hline(yintercept = 0, colour = "grey50") +
  geom_col(aes(alpha = estimada), width = 25) +
  scale_alpha_manual(values = c(`FALSE` = 0.9, `TRUE` = 0.4), guide = "none") +
  scale_fill_manual(values = c(`Sobreoferta (sobre la tendencia)` = COL[["prod"]],
                               `Faltante (bajo la tendencia)` = "#5d6d7e")) +
  labs(x = NULL, y = "Producción por habitante\nfrente a su tendencia (%)") + tema + eje_fecha()
p3b <- ggplot(d3f, aes(fecha, dev_p)) +
  geom_hline(yintercept = 0, colour = "grey50") +
  geom_line(colour = COL[["precio"]], linewidth = 0.9) +
  labs(x = NULL, y = "Precio real frente\na su tendencia (%)") + tema + eje_fecha()
fig3 <- p3a / p3b +
  anotacion("Sobreoferta de huevo y precio real, 2019-2026",
            sprintf(paste0("Nota: tendencias log-lineales estimadas con %s a dic-2025; la producción por habitante crece %s%% ",
                           "al año en tendencia, que se toma como referencia del consumo que el mercado absorbe sin cambiar ",
                           "el precio. Barras claras: producción 2026 estimada. Correlación entre (a) y (b): r = %s.\n",
                           "Fuente: elaboración propia con base en Fenavi, DANE-SIPSA y DANE (población)."),
                    ini_pc, fmt(crec_pc, 1), fmt(r_bp, 2)))
guardar(fig3, "05_figura3_sobreoferta_precio.png", 12)
ley$f3 <- c("Figura 3. Producción por habitante frente a su tendencia y precio real del huevo, 2019-2026.",
            sprintf(paste0("Los periodos en que la producción supera su tendencia (sobreoferta) coinciden con precios ",
                           "reales por debajo de la suya, y viceversa (r = %s)."), fmt(r_bp, 2)),
            "Fuente: elaboración propia con base en Fenavi, DANE-SIPSA y DANE.")

# =====================================================================
# 06. FIGURA 4. Margen y decisión de encasetar
# =====================================================================
d4 <- d |> filter(fecha >= INICIO)
m_min <- mg |> filter(year(fecha) %in% 2020:2021) |> slice_min(razon, n = 1)
m_max <- mg |> slice_max(razon, n = 1)
e_min <- d4 |> filter(year(fecha) %in% 2021:2022) |> slice_min(v_enc, n = 1)
e_max <- d4 |> filter(year(fecha) %in% 2024:2025) |> slice_max(v_enc, n = 1)
e_ult <- d4 |> filter(!is.na(v_enc)) |> slice_tail(n = 1)
p4a <- ggplot(mg, aes(fecha, razon)) +
  geom_hline(yintercept = mean(mg$razon), linetype = "dashed", colour = "grey60") +
  geom_line(colour = COL[["razon"]], linewidth = 0.8) +
  annotate("point", x = c(m_min$fecha, m_max$fecha), y = c(m_min$razon, m_max$razon)) +
  annotate("text", x = m_min$fecha, y = m_min$razon, hjust = -0.1, size = 2.8,
           label = sprintf("margen estrecho (%s)", mes_anio(m_min$fecha))) +
  annotate("text", x = m_max$fecha, y = m_max$razon, hjust = 1.08, size = 2.8,
           label = sprintf("margen máximo (%s)", mes_anio(m_max$fecha))) +
  labs(x = NULL, y = "Razón precio / costo") + tema + eje_fecha()
p4b <- ggplot(d4, aes(fecha, v_enc)) +
  geom_hline(yintercept = 0, colour = "grey50") +
  geom_line(colour = COL[["enc"]], linewidth = 0.8, na.rm = TRUE) +
  annotate("point", x = c(e_min$fecha, e_max$fecha, e_ult$fecha),
           y = c(e_min$v_enc, e_max$v_enc, e_ult$v_enc)) +
  annotate("text", x = e_min$fecha, y = e_min$v_enc, vjust = 1.6, size = 2.8,
           label = fmt_pct(e_min$v_enc)) +
  annotate("text", x = e_max$fecha, y = e_max$v_enc, vjust = -0.9, size = 2.8,
           label = fmt_pct(e_max$v_enc)) +
  annotate("text", x = e_ult$fecha, y = e_ult$v_enc, hjust = 1.15, size = 2.8,
           label = fmt_pct(e_ult$v_enc)) +
  labs(x = NULL, y = "Encasetamiento: variación\nanual (%, suma de 12 meses)") + tema + eje_fecha()
fig4 <- p4a / p4b +
  anotacion("Margen del productor y decisión de encasetamiento, 2019-2026",
            sprintf(paste0("Nota: razón = precio mayorista del huevo rojo AA / costo de producción de Fenavi sin amortización ",
                           "del ave (línea discontinua: promedio, %s); mide la holgura del margen, no la utilidad del ",
                           "productor. La razón adelanta al encasetamiento: correlación máxima a los %d meses (r = %s).\n",
                           "Fuente: elaboración propia con base en Fenavi y DANE-SIPSA."),
                    fmt(mean(mg$razon), 2), lag_dec, fmt(r_dec, 2)))
guardar(fig4, "06_figura4_margen_encasetamiento.png", 12)
ley$f4 <- c("Figura 4. Razón precio/costo y variación anual del encasetamiento, 2019-2026.",
            sprintf(paste0("El margen estrecho de 2020-2021 precede la caída del encasetamiento de 2021-2022; el margen ",
                           "máximo de %s precede el récord de 2024-2025, y su descenso, el recorte de 2026."),
                    mes_anio(m_max$fecha)),
            "Fuente: elaboración propia con base en Fenavi y DANE-SIPSA.")

# =====================================================================
# 07. FIGURA 5. Evidencia estadística de los dos retardos
# =====================================================================
graf_ccf <- function(df, banda, breaks, x_lab, subt, extra = NULL) {
  dl <- pivot_longer(df, -k, names_to = "serie", values_to = "r")
  ggplot(dl, aes(k, r, colour = serie)) + extra +
    geom_hline(yintercept = 0, colour = "grey50") +
    geom_hline(yintercept = c(-banda, banda), linetype = "dashed", colour = "grey55") +
    geom_line(linewidth = 0.8) +
    scale_x_continuous(breaks = breaks) +
    scale_colour_manual(values = COL_CCF) +
    labs(x = x_lab, y = "Correlación", subtitle = subt) + tema
}
p5a <- graf_ccf(ccf_s, banda_s, seq(0, LAG_S, 8), "Rezago k (semanas)",
                "Encasetamiento(t) y producción(t+k)",
                list(annotate("rect", xmin = 20, xmax = 80, ymin = -Inf, ymax = Inf,
                              alpha = 0.08, fill = COL[["enc"]]),
                     annotate("text", x = 66, y = -0.1, size = 2.8, label = "postura (semanas 20 a 80)"),
                     geom_vline(xintercept = lag_s, linetype = "dotted"),
                     annotate("text", x = lag_s, y = -0.1, hjust = 1.05, size = 2.8,
                              label = paste0("máx.: ", lag_s, " semanas"))))
p5b <- graf_ccf(ccf_m, banda_m, seq(0, LAG_M, 2), "Rezago k (meses)",
                "Razón precio/costo(t) y encasetamiento(t+k)",
                list(geom_vline(xintercept = lag_dec, linetype = "dotted"),
                     annotate("text", x = lag_dec, y = -0.1, hjust = 1.05, size = 2.8,
                              label = paste0("máx.: ", lag_dec, " meses")))) +
  theme(legend.position = "none")
fig5 <- p5a / p5b +
  anotacion("Correlación cruzada de los dos retardos del bucle",
            sprintf(paste0("Nota: líneas discontinuas: banda ±1,96/√n (n = %d y %d meses), referencia aproximada que supone ",
                           "ruido blanco. La producción de Fenavi se calcula a partir del encasetamiento, por lo que (a) ",
                           "confirma la demora pero no es evidencia independiente. Solo producción observada (hasta dic-2025).\n",
                           "Fuente: elaboración propia con base en Fenavi y DANE-SIPSA."), n_ef, n_m))
guardar(fig5, "07_figura5_correlacion_retardos.png", 13)
ley$f5 <- c("Figura 5. Correlación cruzada entre encasetamiento y producción (a) y entre margen y encasetamiento (b).",
            sprintf(paste0("La producción responde al encasetamiento entre las semanas 20 y 80 (máximo a las %d, r = %s); ",
                           "el encasetamiento responde al margen entre %d y %d meses después (máximo a los %d, r = %s)."),
                    lag_s, fmt(r_s, 2), tramo_dec[1], tramo_dec[2], lag_dec, fmt(r_dec, 2)),
            "Fuente: elaboración propia con base en Fenavi y DANE-SIPSA.")

# =====================================================================
# 08. TABLA 3. Eslabones del bucle: retardos y evidencia
# =====================================================================
t3 <- tribble(
  ~Eslabon, ~Mecanismo, ~Retardo, ~Evidencia, ~Fuente,
  "Margen → encasetamiento", "Decisión del productor",
  sprintf("%d a %d meses (máx. %d)", tramo_dec[1], tramo_dec[2], lag_dec),
  sprintf("r = %s entre la razón precio/costo y el encasetamiento (variaciones anuales)", fmt(r_dec, 2)),
  "Cálculo propio con Fenavi y DANE-SIPSA",
  "Encasetamiento → inicio de postura", "Levante de la pollita", "20 semanas",
  "Supuesto del modelo de población de Fenavi; la guía genética da 50% de postura cerca de la semana 20",
  "Fenavi; Hy-Line (2025)",
  "Encasetamiento → producción", "Vida productiva del ave",
  sprintf("Semanas 20 a 80 (máx. %d); %d meses en variación anual", lag_s, lag12),
  sprintf("r = %s (semanal, sin tendencia); r = %s (variaciones anuales). La producción de Fenavi se calcula con el encasetamiento",
          fmt(r_s, 2), fmt(r12, 2)),
  "Cálculo propio con Fenavi",
  "Producción → precio", "Mercado", "Sin rezago",
  sprintf("r = %s (semanal, sin tendencia); r = %s entre la brecha de producción por habitante y el precio",
          fmt(r_pp, 2), fmt(r_bp, 2)),
  "Cálculo propio con Fenavi, DANE-SIPSA y DANE",
  "Precio → margen", "Ingreso frente al costo", "Inmediato",
  "La razón usa el precio del mismo mes; el costo depende del maíz, la soya y la TRM (exógenos)",
  "Fenavi; DANE-SIPSA")
ft3 <- flextable(t3) |>
  set_header_labels(Eslabon = "Eslabón", Evidencia = "Evidencia en los datos") |>
  estilo_tabla(c(1.3, 1.0, 1.1, 2.1, 1.0),
               paste0("Bucle de balance con retardos: margen alto → más encasetamiento → (levante y postura) → más ",
                      "producción → precio más bajo → margen más bajo. Las correlaciones son descriptivas; sus bandas ",
                      "de significancia son aproximadas."))
guardar_tabla(ft3, "08_tabla3_eslabones_bucle.png")
ley$t3 <- c("Tabla 3. Eslabones del bucle de producción de huevo: retardos y evidencia en los datos.",
            "Fuente: elaboración propia.")

# =====================================================================
# 09. TABLA 4. Fases del ciclo, año por año
# =====================================================================
num4 <- an |>
  mutate(v_enc = 100 * (enc / lag(enc) - 1), v_cap = 100 * (cap / lag(cap) - 1),
         v_prod = 100 * (prod / lag(prod) - 1), v_pc = 100 * (pc / lag(pc) - 1),
         v_preal = 100 * (precio_real / lag(precio_real) - 1)) |>
  filter(anio >= 2019) |>
  transmute(anio = as.character(anio), razon, v_enc, v_cap, v_prod, v_pc, v_preal) |>
  bind_rows(tibble(anio = "Ene-sep 2026",
                   razon = mean(mg$razon[year(mg$fecha) == 2026]),
                   v_enc = ytd$enc, v_cap = NA, v_prod = ytd$prod, v_pc = ytd$pc,
                   v_preal = ytd$precio_real))
t4 <- num4 |>
  transmute(anio, razon = fmt(razon, 2), v_enc = fmt_pct(v_enc), v_cap = fmt_pct(v_cap),
            v_prod = fmt_pct(v_prod), v_pc = fmt_pct(v_pc), v_preal = fmt_pct(v_preal))
paleta <- c("#2e86c1", "#f7f7f7", "#e67e22")   # azul = bajo o caída; naranja = alto o alza
pal_var <- col_numeric(paleta, domain = c(-15, 15))
col_var <- function(x) ifelse(is.na(x), "white", pal_var(pmax(pmin(x, 15), -15)))
m_r <- mean(mg$razon)
pal_r <- col_numeric(paleta, domain = c(m_r - 0.2, m_r + 0.2))
col_r <- function(x) ifelse(is.na(x), "white", pal_r(pmax(pmin(x, m_r + 0.2), m_r - 0.2)))
ft4 <- flextable(t4) |>
  set_header_labels(anio = "Año", razon = "Razón\nprecio/costo",
                    v_enc = "Encasetamiento", v_cap = "Capacidad de\npostura (ICA)",
                    v_prod = "Producción", v_pc = "Consumo por\nhabitante", v_preal = "Precio real") |>
  add_header_row(values = c("", "Nivel", "Variación anual"), colwidths = c(1, 1, 5)) |>
  estilo_tabla(c(0.95, 0.85, 1.0, 0.95, 0.9, 0.9, 0.9),
               sprintf(paste0("Colores: naranja = alza o valor alto; azul = caída o valor bajo (variaciones hasta ±15%%; ",
                              "razón frente a su promedio de %s). Ene-sep 2026 frente a ene-sep 2025, con producción ",
                              "estimada. Razón = precio mayorista / costo sin amortización del ave."), fmt(m_r, 2))) |>
  align(j = 2:7, align = "center", part = "body") |>
  bg(j = "razon", bg = col_r(num4$razon), part = "body") |>
  bg(j = "v_enc", bg = col_var(num4$v_enc), part = "body") |>
  bg(j = "v_cap", bg = col_var(num4$v_cap), part = "body") |>
  bg(j = "v_prod", bg = col_var(num4$v_prod), part = "body") |>
  bg(j = "v_pc", bg = col_var(num4$v_pc), part = "body") |>
  bg(j = "v_preal", bg = col_var(num4$v_preal), part = "body") |>
  hline(i = nrow(t4) - 1, border = officer::fp_border(color = "grey60", width = 0.5), part = "body")
guardar_tabla(ft4, "09_tabla4_fases_ciclo.png")
ley$t4 <- c("Tabla 4. Fases del ciclo del huevo en Colombia, 2019-2026.",
            paste0("Los años de margen alto preceden la expansión del encasetamiento y de la capacidad instalada; ",
                   "uno o dos años después crece la producción y cae el precio real."),
            "Fuente: elaboración propia con base en Fenavi, DANE-SIPSA, DANE e ICA.")

# ---- Leyendas sugeridas para Word -------------------------------------
orden <- c("t1", "f1", "t2", "f2", "f3", "f4", "f5", "t3", "t4")
con <- file(file.path(CARPETA, "leyendas.txt"), open = "w", encoding = "UTF-8")
writeLines(c("Leyendas sugeridas (título, lectura y fuente), en el orden del artículo", ""), con)
for (k in orden) writeLines(c(ley[[k]], ""), con)
close(con)
cat("  guardado: leyendas.txt\n")
cat("\nListo. Las imágenes están en la carpeta '", CARPETA, "' en el orden del artículo.\n", sep = "")
