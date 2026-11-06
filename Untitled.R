
paquetes <- c("readxl", "dplyr", "tidyr", "ggplot2", "lubridate",
              "patchwork", "sandwich", "lmtest", "writexl", "scales",
              "flextable", "officer")
nuevos <- setdiff(paquetes, rownames(installed.packages()))
if (length(nuevos)) install.packages(nuevos)
invisible(lapply(paquetes, library, character.only = TRUE))

ARCHIVO <- "Base final- Borrador.xlsx"   # ajusta el nombre si cambia
FIN_OBS <- as.Date("2025-12-31")         # la producción ene-sep 2026 es ESTIMADA
LAG_MAX <- 52                            # rezagos de 0 a 52 semanas
dir.create("resultados", showWarnings = FALSE)

# ---- Lectura y preparación ------------------------------------------
sem <- read_excel(ARCHIVO, sheet = "semanal") |>
  mutate(fecha_inicio = as.Date(fecha_inicio),
         fecha_fin    = as.Date(fecha_fin)) |>
  rename(enc = encasetamiento_pollitas,
         prod = produccion_huevos_millones,
         precio = precio_huevo_rojo_aa_promedio,
         precio_real = precio_huevo_real_2019,
         costo = costo_produccion_fenavi)

men <- read_excel(ARCHIVO, sheet = "mensual") |>
  mutate(fecha = as.Date(fecha))

obs <- sem |> filter(fecha_fin <= FIN_OBS)   
# Correlación cruzada: x ADELANTA a y k semanas  ->  cor(x[t], y[t+k])
ccf_cruzada <- function(x, y, lag_max = 52) {
  n <- length(x)
  sapply(0:lag_max, function(k) cor(x[1:(n - k)], y[(1 + k):n]))
}
quitar_tendencia <- function(x) {
  t <- seq_along(x)
  as.numeric(resid(lm(x ~ t)))
}
hac <- function(m, lag) NeweyWest(m, lag = lag, prewhite = FALSE)

# ---- Correlación cruzada (se usa en la figura 1 y en la sección 2) ---
ccf_tab <- tibble(
  lag_sem     = 0:LAG_MAX,
  lag_meses   = round(0:LAG_MAX / 4.345, 1),
  r_nivel     = ccf_cruzada(obs$enc, obs$prod, LAG_MAX),
  r_sin_tend  = ccf_cruzada(quitar_tendencia(obs$enc),
                            quitar_tendencia(obs$prod), LAG_MAX),
  r_dif_anual = ccf_cruzada(diff(obs$enc, lag = 52),
                            diff(obs$prod, lag = 52), LAG_MAX)

# suben con el tiempo y la correlación espuria domina (máximo en lag 0).
lag_opt <- ccf_tab$lag_sem[which.max(ccf_tab$r_sin_tend)]
r_opt   <- max(ccf_tab$r_sin_tend)
# Los datos semanales salen de datos mensuales -> n efectivo ~ n de meses
n_ef  <- n_distinct(format(obs$fecha_inicio, "%Y-%m"))
banda <- 1.96 / sqrt(n_ef)
cat(sprintf("\nRezago óptimo encasetamiento -> producción: %d semanas (%.1f meses), r = %.2f\n",
            lag_opt, lag_opt / 4.345, r_opt))
if (lag_opt >= LAG_MAX - 4)
  cat("AVISO: el máximo cae en el borde de la ventana (0-52). El rezago real\n",
      "      puede ser mayor (el modelo de Fenavi usa meses t-18 a t-5).\n")

# 1. FIGURA: encasetamiento, producción y precio (2019-2026) + rezago

fecha_ini_est <- FIN_OBS + 1
xlim_comun <- c(min(sem$fecha_inicio), max(sem$fecha_fin))   # mismo eje X en los 3 paneles
sombra <- annotate("rect", xmin = fecha_ini_est, xmax = max(sem$fecha_fin),
                   ymin = -Inf, ymax = Inf, alpha = 0.10, fill = "grey40")
tema <- theme_minimal(base_size = 11) +
  theme(panel.grid.minor = element_blank(), legend.position = "top",
        legend.title = element_blank())
eje_x <- list(scale_x_date(date_breaks = "1 year", date_labels = "%Y"),
              coord_cartesian(xlim = xlim_comun))

# Pico de encasetamiento cuyo pico de producción (+ rezago) cae en datos OBSERVADOS
cand      <- obs |> filter(fecha_inicio + 7 * lag_opt <= FIN_OBS)
pico_enc  <- cand$fecha_inicio[which.max(cand$enc)]
pico_prod <- pico_enc + 7 * lag_opt
etq <- sprintf("Rezago ≈ %d sem (%.1f meses)", lag_opt, lag_opt / 4.345)

# encasetamiento reescalado y desplazado lag_opt semanas (para ver el rezago)
esc <- (sem$enc - mean(sem$enc)) / sd(sem$enc) * sd(sem$prod) + mean(sem$prod)
desp <- tibble(fecha = sem$fecha_inicio + 7 * lag_opt, v = esc) |>
  filter(fecha <= max(sem$fecha_fin))   # no dibujar más allá de los datos
y_flecha <- min(sem$prod) + 0.10 * diff(range(sem$prod))

p_enc <- ggplot(sem, aes(fecha_inicio, enc / 1e3)) + sombra +
  geom_line(colour = "#1b6ca8", linewidth = 0.7) +
  geom_vline(xintercept = pico_enc, linetype = "dotted") +
  annotate("text", x = pico_enc, y = -Inf, vjust = -0.8, hjust = -0.05,
           size = 3.2, label = "pico de encasetamiento") +
  labs(y = "Encasetamiento\n(miles de pollitas/sem)", x = NULL) + tema + eje_x

p_prod <- ggplot(sem, aes(fecha_inicio, prod)) + sombra +
  geom_line(data = desp, aes(fecha, v), colour = "#1b6ca8",
            linetype = "dashed", linewidth = 0.6, alpha = 0.7) +
  geom_line(colour = "#c0392b", linewidth = 0.8) +
  geom_vline(xintercept = pico_enc,  linetype = "dotted", colour = "grey50") +
  geom_vline(xintercept = pico_prod, linetype = "dotted") +
  annotate("segment", x = pico_enc, xend = pico_prod, y = y_flecha, yend = y_flecha,
           arrow = arrow(length = unit(0.15, "cm"), ends = "both")) +
  annotate("text", x = pico_enc + 3.5 * lag_opt, y = y_flecha, vjust = -0.8,
           size = 3.2, label = etq) +
  labs(y = "Producción\n(millones de huevos/sem)", x = NULL) + tema + eje_x

pr <- sem |>
  select(fecha_inicio, `Precio nominal` = precio,
         `Precio real (pesos 2019)` = precio_real,
         `Costo Fenavi` = costo) |>
  pivot_longer(-fecha_inicio, names_to = "serie", values_to = "v")
p_precio <- ggplot(pr, aes(fecha_inicio, v, colour = serie, linetype = serie)) +
  sombra + geom_line(linewidth = 0.7) +
  scale_colour_manual(values = c("#27ae60", "#7f8c8d", "#e67e22")) +
  scale_linetype_manual(values = c("solid", "dashed", "solid")) +
  labs(y = "Pesos por huevo", x = NULL) + tema + eje_x

fig1 <- p_enc / p_prod / p_precio +
  plot_annotation(
    title = "Ciclo del huevo en Colombia, 2019-2026",
    subtitle = paste0("Línea azul discontinua: encasetamiento desplazado ",
                      lag_opt, " semanas. Sombreado: producción 2026 estimada."),
    caption = "Fuente: Fenavi, DANE-SIPSA, Banco de la República. Elaboración propia.")
ggsave("resultados/fig1_enc_prod_precio.png", fig1, width = 11, height = 9, dpi = 300)
print(fig1)

# ---- 1b. Figuras auxiliares (series estandarizadas y sin tendencia) ----
z <- function(x) as.numeric(scale(x))
xlim_obs <- range(obs$fecha_inicio)

# Encasetamiento (desplazado) vs producción: co-movimiento POSITIVO
d1b <- bind_rows(
  tibble(fecha = obs$fecha_inicio + 7 * lag_opt,
         serie = sprintf("Encasetamiento (+%d sem)", lag_opt),
         v = z(quitar_tendencia(obs$enc))),
  tibble(fecha = obs$fecha_inicio, serie = "Producción",
         v = z(quitar_tendencia(obs$prod))))
fig1b <- ggplot(d1b, aes(fecha, v, colour = serie)) +
  geom_hline(yintercept = 0, colour = "grey60") +
  geom_line(linewidth = 0.8) +
  scale_colour_manual(values = c("#1b6ca8", "#c0392b")) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  coord_cartesian(xlim = xlim_obs) +
  labs(title = "Encasetamiento y producción (sin tendencia, estandarizadas)",
       subtitle = sprintf("Correlación con rezago de %d semanas: r = %.2f", lag_opt, r_opt),
       x = NULL, y = "Desviaciones estándar", colour = NULL) +
  theme_minimal(base_size = 11) + theme(legend.position = "top")
ggsave("resultados/fig1b_enc_vs_prod.png", fig1b, width = 10, height = 4.5, dpi = 300)
print(fig1b)

# Producción vs precio real: co-movimiento NEGATIVO (mismo período, sin rezago)
r_pp <- cor(quitar_tendencia(obs$prod), quitar_tendencia(obs$precio_real))
d1c <- bind_rows(
  tibble(fecha = obs$fecha_inicio, serie = "Producción",
         v = z(quitar_tendencia(obs$prod))),
  tibble(fecha = obs$fecha_inicio, serie = "Precio real",
         v = z(quitar_tendencia(obs$precio_real))))
fig1c <- ggplot(d1c, aes(fecha, v, colour = serie)) +
  geom_hline(yintercept = 0, colour = "grey60") +
  geom_line(linewidth = 0.8) +
  scale_colour_manual(values = c("#e67e22", "#c0392b")) +
  scale_x_date(date_breaks = "1 year", date_labels = "%Y") +
  coord_cartesian(xlim = xlim_obs) +
  labs(title = "Producción y precio real (sin tendencia, estandarizadas)",
       subtitle = sprintf("Correlación sin rezago: r = %.2f", r_pp),
       x = NULL, y = "Desviaciones estándar", colour = NULL) +
  theme_minimal(base_size = 11) + theme(legend.position = "top")
ggsave("resultados/fig1c_prod_vs_precio.png", fig1c, width = 10, height = 4.5, dpi = 300)
print(fig1c)
# 2. ESTADÍSTICAS, TENDENCIA, VARIACIÓN ANUAL, CORRELACIÓN CRUZADA
etiquetas <- c(enc = "Encasetamiento (pollitas/sem)",
               prod = "Producción (millones huevos/sem)",
               precio = "Precio nominal ($/huevo)",
               precio_real = "Precio real ($2019/huevo)")

# 2.1 Estadísticas básicas (semanal, 2019-2026)
estad <- sem |>
  select(all_of(names(etiquetas))) |>
  pivot_longer(everything(), names_to = "var", values_to = "x") |>
  group_by(var) |>
  summarise(n = n(), media = mean(x), mediana = median(x), desv = sd(x),
            cv = desv / media, min = min(x), p25 = quantile(x, .25),
            p75 = quantile(x, .75), max = max(x), .groups = "drop") |>
  arrange(match(var, names(etiquetas))) |>
  mutate(var = unname(etiquetas[var]))
print(estad, width = Inf)

# 2.2 Tendencia lineal (pendiente por año, errores Newey-West)
tend_una <- function(df, v) {
  t_anios <- as.numeric(df$fecha_inicio - min(df$fecha_inicio)) / 365.25
  m  <- lm(df[[v]] ~ t_anios)
  ct <- coeftest(m, vcov. = hac(m, 26))
  tibble(variable = unname(etiquetas[v]),
         pendiente_anual = ct[2, 1], ee_hac = ct[2, 2], p_valor = ct[2, 4],
         pct_anual_sobre_media = 100 * ct[2, 1] / mean(df[[v]]),
         muestra = paste(format(min(df$fecha_inicio), "%Y-%m"), "a",
                         format(max(df$fecha_inicio), "%Y-%m")))
}
tendencia <- bind_rows(
  tend_una(sem, "enc"),
  tend_una(obs, "prod"),          # producción: solo la parte observada
  tend_una(sem, "precio"),
  tend_una(sem, "precio_real"))
print(tendencia, width = Inf)
# 2.3 Variación anual (años calendario completos, hoja mensual)
anual <- men |>
  mutate(anio = year(fecha)) |>
  group_by(anio) |>
  summarise(meses = n(),
            enc = sum(encasetamiento_pollitas),
            prod = sum(produccion_huevos_millones),
            precio = mean(precio_huevo_rojo_aa_promedio),
            precio_real = mean(precio_huevo_real_2019), .groups = "drop") |>
  filter(meses == 12) |>
  mutate(across(c(enc, prod, precio, precio_real),
                ~ 100 * (.x / lag(.x) - 1), .names = "var_pct_{.col}"))
print(anual, width = Inf)
# Ene-sep 2026 vs ene-sep 2025 (la producción 2026 es estimada)
ytd <- men |>
  mutate(anio = year(fecha), mes = month(fecha)) |>
  filter(anio %in% c(2025, 2026), mes <= 9) |>
  group_by(anio) |>
  summarise(enc = sum(encasetamiento_pollitas), prod = sum(produccion_huevos_millones),
            precio = mean(precio_huevo_rojo_aa_promedio),
            precio_real = mean(precio_huevo_real_2019), .groups = "drop") |>
  summarise(across(c(enc, prod, precio, precio_real),
                   ~ 100 * (.x[anio == 2026] / .x[anio == 2025] - 1),
                   .names = "var_pct_{.col}"))
print(ytd)
# 2.4 Correlación cruzada encasetamiento -> producción, rezagos 0 a 52
print(ccf_tab |> filter(lag_sem %% 4 == 0), n = Inf)
ccf_larga <- ccf_tab |>
  select(lag_sem, `Niveles` = r_nivel, `Sin tendencia` = r_sin_tend,
         `Diferencia anual` = r_dif_anual) |>
  pivot_longer(-lag_sem, names_to = "serie", values_to = "r")
fig2 <- ggplot(ccf_larga, aes(lag_sem, r, colour = serie)) +
  geom_hline(yintercept = 0, colour = "grey50") +
  geom_hline(yintercept = c(-banda, banda), linetype = "dashed", colour = "grey50") +
  geom_line(linewidth = 0.8) +
  geom_vline(xintercept = lag_opt, linetype = "dotted") +
  annotate("text", x = lag_opt, y = -Inf, vjust = -0.6, hjust = 1.05, size = 3.2,
           label = paste0("máx. (sin tendencia): ", lag_opt, " sem")) +
  scale_x_continuous(breaks = seq(0, 52, 4)) +
  labs(title = "Correlación cruzada: encasetamiento(t) vs producción(t+k)",
       subtitle = paste0("Banda ±1.96/√n con n = ", n_ef,
                         " meses (n efectivo: los datos semanales salen de datos mensuales)"),
       x = "Rezago k (semanas)", y = "Correlación", colour = NULL) +
  theme_minimal(base_size = 11) + theme(legend.position = "top")
print(fig2)
# 2.5 TABLAS DE LA PARTE 2 (formato artículo; se exportan a Word)
fmt <- function(x, d = 0) {
  d <- rep_len(d, length(x))
  mapply(function(xx, dd) {
    if (is.na(xx)) return("—")
    format(round(xx, dd), big.mark = ".", decimal.mark = ",",
           nsmall = dd, trim = TRUE, scientific = FALSE)
  }, x, d, USE.NAMES = FALSE)
}
fmt_p <- function(p) ifelse(p < 0.001, "<0,001",
                            formatC(p, digits = 3, format = "f", decimal.mark = ","))

estilo <- function(ft) {
  ft |>
    theme_booktabs() |>
    fontsize(size = 9, part = "all") |>
    align(align = "right", part = "body") |>
    align(j = 1, align = "left", part = "body") |>
    align(align = "center", part = "header") |>
    set_table_properties(width = 1, layout = "autofit")
}

# ---- Tabla 1. Estadísticas básicas (semanal, 2019-2026) --------------
dec_est <- c(0, 1, 0, 0)   # decimales por variable (enc, prod, precio, precio real)
t1 <- tibble(
  Variable     = estad$var,
  n            = as.character(estad$n),
  Media        = fmt(estad$media,   dec_est),
  Mediana      = fmt(estad$mediana, dec_est),
  `Desv. est.` = fmt(estad$desv,    dec_est),
  `CV (%)`     = fmt(100 * estad$cv, 1),
  `Mín.`       = fmt(estad$min, dec_est),
  P25          = fmt(estad$p25, dec_est),
  P75          = fmt(estad$p75, dec_est),
  `Máx.`       = fmt(estad$max, dec_est))
ft1 <- flextable(t1) |> estilo() |>
  add_footer_lines("Datos semanales, 2019-2026. La producción de ene-sep 2026 es estimada.")
ft1
# ---- Tabla 2. Tendencia lineal ---------------------------------------
dec_pend <- c(0, 2, 1, 1)
t2 <- tibble(
  Variable                = tendencia$variable,
  Muestra                 = tendencia$muestra,
  `Pendiente (por año)`   = fmt(tendencia$pendiente_anual, dec_pend),
  `EE (Newey-West)`       = fmt(tendencia$ee_hac, dec_pend),
  `p-valor`               = fmt_p(tendencia$p_valor),
  `% anual sobre la media` = fmt(tendencia$pct_anual_sobre_media, 2))
ft2 <- flextable(t2) |> estilo() |>
  add_footer_lines("Regresión lineal sobre el tiempo; errores estándar Newey-West (rezago 26). La producción se estima solo con datos observados (hasta dic-2025).")
ft2
# ---- Tabla 3. Variación anual (2019-2025 + ene-sep 2026) -------------
t3_niv <- anual |>
  filter(anio >= 2019) |>
  transmute(
    anio     = as.character(anio),
    enc      = fmt(enc / 1e6, 2),        v_enc    = fmt(var_pct_enc, 1),
    prod     = fmt(prod, 0),             v_prod   = fmt(var_pct_prod, 1),
    precio   = fmt(precio, 0),           v_precio = fmt(var_pct_precio, 1),
    preal    = fmt(precio_real, 0),      v_preal  = fmt(var_pct_precio_real, 1))
t3_ytd <- tibble(
  anio = "Ene-sep 2026 vs ene-sep 2025",
  enc = "—",    v_enc    = fmt(ytd$var_pct_enc, 1),
  prod = "—",   v_prod   = fmt(ytd$var_pct_prod, 1),
  precio = "—", v_precio = fmt(ytd$var_pct_precio, 1),
  preal = "—",  v_preal  = fmt(ytd$var_pct_precio_real, 1))
t3 <- bind_rows(t3_niv, t3_ytd)
ft3 <- flextable(t3) |>
  set_header_labels(anio = "Año",
                    enc = "Encasetamiento\n(millones de pollitas)", v_enc = "Var. %",
                    prod = "Producción\n(millones de huevos)",      v_prod = "Var. %",
                    precio = "Precio nominal\n($/huevo)",           v_precio = "Var. %",
                    preal = "Precio real\n($2019/huevo)",           v_preal = "Var. %") |>
  estilo() |>
  add_footer_lines("Encasetamiento y producción: suma anual. Precios: promedio anual. La producción de 2026 es estimada.")
ft3
# ---- Tabla 4. Correlación cruzada encasetamiento -> producción -------
t4_raw <- ccf_tab |>
  filter(lag_sem %% 4 == 0 | lag_sem == lag_opt) |>
  distinct(lag_sem, .keep_all = TRUE)
t4 <- tibble(
  `Rezago (semanas)` = as.character(t4_raw$lag_sem),
  `Rezago (meses)`   = fmt(t4_raw$lag_meses, 1),
  `Niveles`          = fmt(t4_raw$r_nivel, 2),
  `Sin tendencia`    = fmt(t4_raw$r_sin_tend, 2),
  `Diferencia anual` = fmt(t4_raw$r_dif_anual, 2))
fila_max <- which(t4_raw$lag_sem == lag_opt)
ft4 <- flextable(t4) |> estilo() |>
  bold(i = fila_max, part = "body") |>
  bg(i = fila_max, bg = "#fff2cc", part = "body") |>
  add_footer_lines(sprintf(
    "r(k) = cor(encasetamiento[t], producción[t+k]), k = 0 a 52 semanas (se muestra cada 4). En negrita: máximo de la serie sin tendencia. Banda aproximada ±%s (n efectivo = %d meses).",
    fmt(banda, 2), n_ef))
ft4
# 3a. PERÍODO DEL CICLO (2 a 4 años) - hoja mensual, 2017-2025 observado
mo <- men |> filter(fecha <= FIN_OBS)
series_ciclo <- list(
  "Encasetamiento"          = mo$encasetamiento_pollitas,
  "Producción"              = mo$produccion_huevos_millones,
  "Precio real"             = mo$precio_huevo_real_2019)
t_anios_m <- (seq_len(nrow(mo)) - 1) / 12
periodos  <- seq(2, 4, by = 0.05)

ajuste_armonico <- function(x, t, periodos) {
  x <- as.numeric(resid(lm(x ~ t)))            # sin tendencia lineal
  r2 <- sapply(periodos, function(p) {
    m <- lm(x ~ cos(2 * pi * t / p) + sin(2 * pi * t / p))
    summary(m)$r.squared
  })
  tibble(periodo = periodos, r2 = r2)
}
perfiles <- bind_rows(lapply(names(series_ciclo), function(nm)
  ajuste_armonico(series_ciclo[[nm]], t_anios_m, periodos) |> mutate(serie = nm)))

# Periodograma (con relleno de ceros para interpolar la frecuencia)
pico_periodograma <- function(x) {
  x <- ts(as.numeric(resid(lm(x ~ seq_along(x)))), frequency = 12)
  sp <- spec.pgram(x, taper = 0.1, pad = 3, detrend = FALSE, plot = FALSE)
  d <- tibble(periodo = 1 / sp$freq, esp = sp$spec) |> filter(periodo >= 2, periodo <= 4)
  d$periodo[which.max(d$esp)]
}
ciclo <- perfiles |>
  group_by(serie) |>
  slice_max(r2, n = 1, with_ties = FALSE) |>
  ungroup() |>
  mutate(periodo_periodograma = sapply(series_ciclo[serie], pico_periodograma),
         en_borde = abs(periodo - 2) < 1e-9 | abs(periodo - 4) < 1e-9) |>
  rename(periodo_regr_armonica = periodo, r2_armonico = r2)
cat("\nPeríodo del ciclo (años), banda 2-4:\n"); print(ciclo)
if (any(ciclo$en_borde))
  cat("AVISO: algún máximo cae en el borde 2/4 años; con ~9 años de datos el\n",
      "      período no se identifica con precisión (solo ~2-4 ciclos).\n")

fig3 <- ggplot(perfiles, aes(periodo, r2, colour = serie)) +
  geom_line(linewidth = 0.8) +
  labs(title = "R² de un ajuste sinusoidal según el período (2 a 4 años)",
       x = "Período (años)", y = "R²", colour = NULL) +
  theme_minimal(base_size = 11) + theme(legend.position = "top")
ggsave("resultados/fig3_periodo_ciclo.png", fig3, width = 8, height = 4.5, dpi = 300)

# 3b. ELASTICIDAD PRECIO DE LA DEMANDA (log-log, hoja mensual)
el <- men |>
  filter(fecha <= FIN_OBS, !is.na(poblacion)) |>
  mutate(q = log(produccion_huevos_millones * 1e6 / dias_mes / poblacion),
         p = log(precio_huevo_real_2019),
         w = log(salario_minimo * 102.56 / ipc_total),   # salario mínimo real 2019
         t = (row_number() - 1) / 12,
         dq = q - lag(q, 12), dp = p - lag(p, 12), dw = w - lag(w, 12))

extraer <- function(m, nombre, term) {
  ct <- coeftest(m, vcov. = hac(m, 12))
  est <- ct[term, 1]; ee <- ct[term, 2]
  tibble(modelo = nombre, n = nobs(m), elasticidad_precio = est, ee_hac = ee,
         ic95_inf = est - 1.96 * ee, ic95_sup = est + 1.96 * ee,
         p_valor = ct[term, 4], r2 = summary(m)$r.squared)
}
m1 <- lm(q ~ p + t, data = el)
m2 <- lm(q ~ p + t + w, data = el)
m3 <- lm(dq ~ dp + dw, data = el)    # diferencias anuales + ingreso (preferido)
m4 <- lm(dq ~ dp, data = el)         # diferencias anuales, solo precio
elasticidad <- bind_rows(
  extraer(m1, "M1: niveles + tendencia", "p"),
  extraer(m2, "M2: niveles + tendencia + salario real", "p"),
  extraer(m3, "M3: dif. anuales + salario real (preferido)", "dp"),
  extraer(m4, "M4: dif. anuales, solo precio", "dp"))
print(elasticidad, width = Inf)
cat("\nElasticidad-ingreso (M3, salario mínimo real):",
    round(coef(m3)["dw"], 2), "\n")
cat("|e| < 1 => demanda inelástica. Con tendencia y precio real ambos crecientes,\n",
    "los modelos en niveles (M1-M2) son frágiles; M3-M4 quitan la tendencia.\n")

# 4. TABLA DE PARÁMETROS (valor y fuente)
costo_2019 <- mean(sem$costo[year(sem$fecha_inicio) == 2019])
costo_2026 <- mean(sem$costo[year(sem$fecha_inicio) == 2026])
costo_ult  <- tail(sem$costo, 1)
URL_HYLINE <- "Hy-Line Brown Max Pro, Guía de rendimiento (oct. 2025), sistemas convencionales: hyline.com"

parametros <- tribble(
  ~parametro, ~valor, ~unidad, ~fuente, ~observacion,
  "Levante (modelo)", "20", "semanas",
  "Fenavi, modelo de población (citado en hoja notas_fuentes §3.3 de la base)",
  "Pollita a inicio de postura; es el valor que usa la base.",
  "Levante (referencia técnica)", "17 (crianza) / ~20 (50% de postura)", "semanas",
  URL_HYLINE,
  "Crianza hasta sem. 17; 50% de producción a los 139 días (≈19.9 sem).",
  "Vida productiva (postura)", "60 (sem. 20 a 80 de edad)", "semanas",
  "Fenavi, modelo de población: 80 sem. de vida total (notas_fuentes §3.3)",
  "Equivale a la ventana t-18 a t-5 meses de la base. La guía técnica llega a 100 sem.",
  "Mortalidad en levante", "2.0", "% acumulado a sem. 17",
  URL_HYLINE, "Viabilidad 98%. Referencia internacional, no dato de campo colombiano.",
  "Mortalidad en postura", "5.28 (≈0.085 por semana)", "% acumulado sem. 18-80",
  URL_HYLINE, "0.085 = 5.28 / 62 semanas (cálculo propio).",
  "Postura semanal (pico)", "6.7 a 6.9", "huevos/ave/semana",
  URL_HYLINE, "95.1-98.6% ave-día en sem. 27-29, por 7 días (cálculo propio).",
  "Postura semanal (promedio sem. 18-80)", "6.0 a 6.4", "huevos/ave/semana",
  URL_HYLINE, "381-400 huevos ave-día acumulados a sem. 80, entre 63 semanas (cálculo propio).",
  "Postura efectiva del modelo", "350 por ave alojada (≈5.8/sem; k = 24.66 huevos/pollita/mes)", "huevos",
  "Fenavi (notas_fuentes §3.3) y hoja aux_produccion de la base",
  "Valor calibrado a Colombia; menor que el estándar genético, razonable.",
  "Costo unitario por huevo (2019)", sprintf("%.0f", costo_2019), "pesos corrientes/huevo",
  "Fenavi - Fenaviquín, 'Impacto de costos' (hoja semanal de la base)", "Sin amortización del ave.",
  "Costo unitario por huevo (ene-sep 2026)", sprintf("%.0f", costo_2026), "pesos corrientes/huevo",
  "Fenavi - Fenaviquín (hoja semanal de la base)", "Sin amortización del ave.",
  "Costo unitario por huevo (última semana)", sprintf("%.0f", costo_ult), "pesos corrientes/huevo",
  "Fenavi - Fenaviquín (hoja semanal de la base)", "Sin amortización del ave.",
  "Costo de la pollita / amortización del ave", "PENDIENTE", "pesos/ave",
  "Por buscar (Fenaviquín, proveedores o la hoja de costos de Fenavi)",
  "La base no lo incluye; hace falta si el modelo amortiza el ave.")
print(parametros, width = Inf)

# Exportar todo a Excel

write_xlsx(list(tabla1_estadisticas = t1, tabla2_tendencia = t2,
                tabla3_variacion_anual = t3, tabla4_ccf = t4,
                estadisticas = estad, tendencia = tendencia,
                variacion_anual = anual, variacion_ene_sep_2026 = ytd,
                ccf_0_52_sem = ccf_tab, ciclo_2_4_anios = ciclo,
                elasticidad = elasticidad, parametros = parametros),
           "resultados/resultados_ciclo_huevo.xlsx")
cat("\nListo. Revisa la carpeta 'resultados/'.\n")

