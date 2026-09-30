# =============================================================================
# A3 — Limpieza de datos reales del INE (ENE, trimestre móvil MJJ 2026)
# Fundamentos de Programación para Análisis Económico · UdeC-EAN · Semana 6
#
# Autor : Sebastián Navarrete
# Fecha : 29-09-2026
# Qué hace:
#   Lee la base pública de la Encuesta Nacional de Empleo tal como la publica el
#   INE, conserva solo las variables que necesita mi pregunta, recodifica los
#   códigos a etiquetas, clasifica los faltantes (estructurales vs. reales),
#   limpia los códigos centinela de la duración de búsqueda de empleo.
# =============================================================================


# -----------------------------------------------------------------------------
# 1. PREGUNTA Y FICHA DE LA FUENTE
# -----------------------------------------------------------------------------
# Pregunta:
#   ¿Cuánto difiere la tasa de desocupación entre hombres y mujeres en Chile, y
#   cambia esa brecha según el tramo de edad? (trimestre mayo–julio 2026)
#   Pregunta complementaria: entre las personas desocupadas, ¿llevan más tiempo
#   buscando trabajo las mujeres que los hombres?
#
# Ficha de la fuente:
#   Institución          : Instituto Nacional de Estadísticas de Chile (INE)
#   Encuesta             : Encuesta Nacional de Empleo (ENE)
#   Período              : trimestre móvil mayo–junio–julio 2026 (MJJ, mes central junio)
#   Archivo              : ene-2026-06-mjj.csv (97.946 filas × 222 columnas)
#   Enlace de descarga   : https://www.ine.cl/docs/default-source/ocupacion-y-desocupacion/bbdd/2026/csv/ene-2026-06-mjj.csv
#                          
#   Fecha de descarga    : 2026-09-29
#   Manual               : Libro de códigos ENE (codigos-ene-2020.pdf), act. 31-07-2026

#   Diseño               : muestra probabilística; cada persona representa a
#                          `fact_cal` personas de la población (factor calibrado).
# -----------------------------------------------------------------------------

library(readr)
library(dplyr)
library(tidyr)   

ruta_raw  <- "data/raw/ene-2026-06-mjj.csv"
ruta_proc <- "data/processed/ene_a3.csv"


# -----------------------------------------------------------------------------
# 2. LECTURA Y REDUCCIÓN DE COLUMNAS
# -----------------------------------------------------------------------------
# ¿Por qué no sirve read.csv?
#   read.csv supone separador "," y decimal ".". Este archivo usa ";" como
#   separador y "," como decimal. Con read.csv() las
#   222 columnas quedarían pegadas en UNA sola columna de texto; y aunque se
#   corrigiera el separador (sep = ";"), fact_cal ("1079,2562887644") quedaría
#   como texto y no se podría sumar. Además read.csv() es lento con ~38 MB.
#   Uso readr::read_delim() indicando delim = ";" y decimal_mark = ",".
#   guess_max alto para que readr adivine bien el tipo de columnas que vienen
#   vacías en las primeras miles de filas (p. ej. e6_mes, que solo responden
#   no ocupados).

ene_raw <- read_delim(
  ruta_raw,
  delim  = ";",
  locale = locale(decimal_mark = ","),
  guess_max = 100000,
  show_col_types = FALSE
)

dim(ene_raw)          # 97946 filas, 222 columnas
class(ene_raw$fact_cal)  # "numeric": el decimal con coma se leyó bien

filas_iniciales <- nrow(ene_raw)

# Variables que necesita la pregunta (todas verificadas en el manual):
#   idrph            identificador de persona
#   region           región (para contexto; no se recodifica)
#   mes_encuesta     mes en que se hizo la entrevista (para calcular duración)
#   sexo             1 Hombre, 2 Mujer
#   edad             edad en años 0–120   
#   tramo_edad       12 tramos de 5 años desde 15 años
#   activ            1 Ocupado, 2 Desocupado, 3 Fuera FT
#   cae_especifico   código sumario; lo uso solo para verificar activ
#   e6_mes, e6_ano   "¿Desde cuándo ha estado buscando trabajo?" 
#   fact_cal         factor de expansión trimestral calibrado 
#
# Selector por patrón: starts_with("e6_") trae e6_mes y e6_ano; where() se usa
# después para revisar las columnas numéricas del subconjunto.
# (Ojo: las columnas b1, b2... son preguntas del cuestionario, no indicadores;
#  por eso uso activ y no reconstruyo la condición de actividad a mano.)

ene <- ene_raw |>
  select(idrph, region, mes_encuesta, sexo, edad, tramo_edad,
         activ, cae_especifico, starts_with("e6_"), fact_cal)

names(ene)
ncol(ene)   # 11 columnas de 222

# Chequeo rápido de todas las numéricas con un selector por tipo:
ene |> summarise(across(where(is.numeric), list(min = ~min(.x, na.rm = TRUE),
                                                max = ~max(.x, na.rm = TRUE))))

# Verificación de consistencia: activ debe coincidir con cae_especifico según el
# manual (ocupados = 1:7, desocupados = 8:9, fuera de la FT = 10:28).
table(activ = ene$activ, cae = cut(ene$cae_especifico, c(-1, 0, 7, 9, 28)),
      useNA = "ifany")
# Coinciden exactamente: activ es confiable.


# -----------------------------------------------------------------------------
# 3. RECODIFICACIÓN A ETIQUETAS LEGIBLES (case_when)
# -----------------------------------------------------------------------------
# (a) sexo: 1 = Hombre, 2 = Mujer (manual, variable sexo).
# (b) activ: 1 = Ocupado/a, 2 = Desocupado/a, 3 = Fuera de la FT.
#     NA en activ = menores de 15 años (se revisa en el paso 4).
# (c) grupo_edad: agrupo los 12 tramos de `tramo_edad` en 4 grupos. Decisión:
#     con 12 tramos × 2 sexos quedan celdas con muy pocos desocupados en la
#     muestra (p. ej. mujeres de 70+), y el INE advierte sobre la precisión de
#     estimaciones con pocos casos. Los grupos siguen cortes habituales:
#       15–24 (jóvenes), 25–34, 35–54 (edad central), 55 y más.
#     tramo_edad: 1=15–19, 2=20–24, 3=25–29, 4=30–34, 5=35–39, 6=40–44,
#                 7=45–49, 8=50–54, 9=55–59, 10=60–64, 11=65–69, 12=70+.

ene <- ene |>
  mutate(
    sexo_lbl = case_when(
      sexo == 1 ~ "Hombre",
      sexo == 2 ~ "Mujer",
      TRUE      ~ NA_character_
    ),
    activ_lbl = case_when(
      activ == 1 ~ "Ocupado/a",
      activ == 2 ~ "Desocupado/a",
      activ == 3 ~ "Fuera de la FT",
      TRUE       ~ NA_character_      # menores de 15: fuera de la PET
    ),
    grupo_edad = case_when(
      tramo_edad %in% 1:2   ~ "15-24",
      tramo_edad %in% 3:4   ~ "25-34",
      tramo_edad %in% 5:8   ~ "35-54",
      tramo_edad %in% 9:12  ~ "55+",
      TRUE                  ~ NA_character_   # menores de 15
    )
  )

# Verificación: ¿quedó algún NA inesperado?
table(ene$sexo_lbl,   useNA = "ifany")   # 0 NA: todos son 1 o 2
table(ene$activ_lbl,  useNA = "ifany")   # 15.305 NA
table(ene$grupo_edad, useNA = "ifany")   # 15.305 NA
# Los 15.305 NA de activ_lbl y grupo_edad, ¿son exactamente los menores de 15?
table(menor15 = ene$edad < 15, NA_activ = is.na(ene$activ_lbl))
table(menor15 = ene$edad < 15, NA_grupo = is.na(ene$grupo_edad))
# Sí: coinciden 1 a 1. No hay NA inesperados; son el NA "esperado" de la
# población fuera de la edad de trabajar.


# -----------------------------------------------------------------------------
# 4. FALTANTES: ¿ESTRUCTURALES O REALES?
# -----------------------------------------------------------------------------
na_por_variable <- ene |>
  summarise(across(everything(), ~ sum(is.na(.x)))) |>
  tidyr::pivot_longer(everything(), names_to = "variable", values_to = "n_NA")
na_por_variable

# ¿De quiénes son los NA de e6_mes / e6_ano?
table(activ = ene$activ_lbl, tiene_e6 = !is.na(ene$e6_ano), useNA = "ifany")

# Clasificación variable por variable:
#   idrph, region, mes_encuesta, sexo, edad, cae_especifico, fact_cal : 0 NA.
#   tramo_edad / activ (15.305 NA)  -> ESTRUCTURALES. Son los menores de 15
#        años: nunca se les clasifica en la fuerza de trabajo (no son PET).
#        El dato no se perdió: nunca existió. No se imputan; se excluyen del
#        cálculo de la tasa porque no pertenecen a la población de interés.
#   e6_mes / e6_ano (93.465 NA)     -> ESTRUCTURALES. La pregunta e6 solo se
#        hace a personas NO ocupadas que buscaron trabajo (manual: "Solo
#        responden no ocupados/as"). Los 41.850 ocupados, 36.310 de los 36.379
#        inactivos y los 15.305 menores de 15 no tienen e6 porque no corresponde
#        preguntárselo. Los 4.412 desocupados (y 69 inactivos que buscaron pero
#        no estaban disponibles) sí la tienen.
#   Faltantes REALES: no aparecen como NA sino disfrazados de códigos
#        (88/99 en e6_mes, 8888/9999 en e6_ano): son desocupados a quienes sí
#        se les preguntó y no supieron o no respondieron. Se tratan en el paso 5.
#   (Además revisé edad: llega a 114 y hay 14 personas con 99 años, pero el
#    manual define edad como 0–120 sin códigos especiales y la distribución
#    baja suavemente 97→98→99→100, así que 99 es una edad real, no un centinela.)

# --- Demostración: qué hace na.omit() con mi subconjunto ---------------------
ene_naomit <- na.omit(ene)
nrow(ene)          # 97.946
nrow(ene_naomit)   # 4.481: solo sobreviven quienes tienen e6 respondido
table(ene_naomit$activ_lbl, useNA = "ifany")   # 4.412 desocupados + 69 inactivos
# na.omit() borró 93.465 filas (95% de la base): a TODOS los ocupados (41.850),
# a 36.310 inactivos y a los menores de 15, porque tienen NA estructural en e6_*.
# Consecuencia para mi pregunta: la tasa de desocupación calculada sobre esta
# base da 100%, porque se eliminó justamente el
# denominador (los ocupados). El NA de e6 no significa "dato perdido", sino
# "persona ocupada"; borrarlo es borrar la parte más grande de la fuerza de
# trabajo. Lo muestro:
td_naomit <- with(ene_naomit,
  sum(fact_cal[activ == 2]) / sum(fact_cal[activ %in% 1:2]) * 100)
td_naomit


# -----------------------------------------------------------------------------
# 5. CENTINELAS en e6_mes / e6_ano (duración de la búsqueda de empleo)
# -----------------------------------------------------------------------------
# Solo tiene sentido entre desocupados: ahí la pregunta aplica a todos.
des <- ene |> filter(activ == 2)

sort(table(des$e6_mes), decreasing = TRUE)
sort(table(des$e6_ano), decreasing = TRUE)
# Hallazgos:
#   e6_mes: valores 1–12 (meses) y además 88 (147 casos) y 99 (111 casos).
#           Según el manual, 88 = "No sabe" y 99 = "No responde". Estos NO están
#           en un máximo "evidente" si uno solo mira summary(): se esconden entre
#           los meses válidos en una tabla ordenada por frecuencia.
#   e6_ano: años 2000–2026 y además 9999 (91 casos) y 8888 (1 caso).
#           Manual: 8888 = "No sabe", 9999 = "No responde".
#   Ojo: 166 personas tienen año válido pero mes 88/99, así que no basta con
#   limpiar solo una de las dos variables.

# Construyo la duración de búsqueda en meses:
#   (año y mes de la entrevista) − (año y mes desde que busca)
# Primero, la versión INGENUA (sin limpiar centinelas), para medir el efecto:
des <- des |>
  mutate(meses_busqueda_sucio =
           (2026 * 12 + mes_encuesta) - (e6_ano * 12 + e6_mes))

summary(des$meses_busqueda_sucio)
# Con 9999 como año, la "duración" llega a −95.770 meses; con mes 88/99 da
# valores negativos o absurdos (el promedio simple es −1.989). Promedio
# ponderado ingenuo:
media_sucia <- with(des, weighted.mean(meses_busqueda_sucio, fact_cal))

# Versión LIMPIA: convierto los centinelas a NA con na_if()
des <- des |>
  mutate(
    e6_mes = na_if(e6_mes, 88),
    e6_mes = na_if(e6_mes, 99),
    e6_ano = na_if(e6_ano, 8888),
    e6_ano = na_if(e6_ano, 9999),
    meses_busqueda = (2026 * 12 + mes_encuesta) - (e6_ano * 12 + e6_mes)
  )

sum(is.na(des$meses_busqueda))   # 258 desocupados sin duración (5,8%)
summary(des$meses_busqueda)
# ¿Queda alguna duración negativa (búsqueda que "empieza" después de la
# entrevista)? Revisión:
sum(des$meses_busqueda < 0, na.rm = TRUE)   # 0 casos
# No hay, pero dejo la regla por si se reutiliza el script con otro trimestre:
# un negativo sería un error de respuesta y quedaría NA.
des <- des |> mutate(meses_busqueda = if_else(meses_busqueda < 0, NA_real_, meses_busqueda))

media_limpia   <- with(des, weighted.mean(meses_busqueda, fact_cal, na.rm = TRUE))
# Mediana ponderada: ordeno por duración y busco dónde el peso acumulado
# llega a la mitad de la población desocupada.
mediana_limpia <- des |>
  filter(!is.na(meses_busqueda)) |>
  arrange(meses_busqueda) |>
  mutate(peso_acum = cumsum(fact_cal) / sum(fact_cal)) |>
  filter(peso_acum >= 0.5) |>
  slice(1) |>
  pull(meses_busqueda)

efecto_centinelas <- tibble(
  calculo = c("Con centinelas (sucio)", "Centinelas -> NA (limpio)"),
  media_meses_ponderada = c(media_sucia, media_limpia)
)
efecto_centinelas
mediana_limpia
# Efecto: la media ponderada de meses buscando trabajo pasa de −1.788 meses
# (imposible) a 6,6 meses; la mediana ponderada es 3 meses. Bastan 92
# desocupados con 8888/9999 (2% de 4.412) para destruir el estadístico.

# ¿Imputar los 258 NA con la mediana? No: no sabemos si son búsquedas cortas o
# largas, y quien "no sabe desde cuándo busca" probablemente busca hace mucho.
# Los dejo NA y reporto la duración sobre quienes respondieron.

# Duración por sexo (ponderada):
duracion_sexo <- des |>
  filter(!is.na(meses_busqueda)) |>
  group_by(sexo_lbl) |>
  summarise(
    n_muestra      = n(),
    media_meses    = weighted.mean(meses_busqueda, fact_cal),
    pct_12m_o_mas  = sum(fact_cal[meses_busqueda >= 12]) / sum(fact_cal) * 100,
    .groups = "drop"
  )
duracion_sexo


# -----------------------------------------------------------------------------
# 6. PONDERACIÓN: tasa de desocupación por sexo y grupo de edad
# -----------------------------------------------------------------------------
# TD = desocupados / fuerza de trabajo × 100   (FT = ocupados + desocupados)
# Población: personas de 15+ en la fuerza de trabajo (activ 1 o 2).

ft <- ene |> filter(activ %in% 1:2)

tasa <- function(df) {
  df |> summarise(
    n_muestra       = n(),
    desocupados     = sum(fact_cal[activ == 2]),
    fuerza_trabajo  = sum(fact_cal),
    td_ponderada    = desocupados / fuerza_trabajo * 100,
    td_sin_ponderar = mean(activ == 2) * 100,
    .groups = "drop"
  )
}

td_total      <- tasa(ft)
td_sexo       <- ft |> group_by(sexo_lbl) |> tasa()
td_sexo_edad  <- ft |> group_by(grupo_edad, sexo_lbl) |> tasa()

td_total
td_sexo
td_sexo_edad

# Brecha (Mujer − Hombre) en puntos porcentuales, por grupo de edad:
brecha <- td_sexo_edad |>
  select(grupo_edad, sexo_lbl, td_ponderada, td_sin_ponderar) |>
  tidyr::pivot_wider(names_from = sexo_lbl,
                     values_from = c(td_ponderada, td_sin_ponderar)) |>
  mutate(
    brecha_pp_ponderada    = td_ponderada_Mujer - td_ponderada_Hombre,
    brecha_pp_sin_ponderar = td_sin_ponderar_Mujer - td_sin_ponderar_Hombre
  )
brecha

# Niveles (personas) ponderados vs. sin ponderar:
niveles <- ft |> group_by(sexo_lbl) |>
  summarise(desocupados_muestra = sum(activ == 2),
            desocupados_poblacion = sum(fact_cal[activ == 2]),
            .groups = "drop")
niveles

# Comentario sobre ponderar vs. no ponderar:
#   - NIVEL: sin ponderar solo puedo decir "4.412 desocupados en la muestra"
#     (2.202 hombres y 2.210 mujeres: ¡casi iguales!). Ponderado, son 981.044
#     personas: 515.330 hombres y 465.714 mujeres. Sin fact_cal el nivel no
#     tiene significado poblacional, e incluso ordena mal (en la muestra hay
#     más mujeres desocupadas que hombres; en la población, al revés).
#   - TASA TOTAL: casi no cambia (9,53% ponderada vs. 9,54% sin ponderar).
#   - TASA POR GRUPO: sí cambia, y bastante en los jóvenes. Mujeres 15–24:
#     24,6% ponderada vs. 25,9% sin ponderar; hombres 15–24: 22,7% vs. 21,2%.
#     Por eso la brecha en 15–24 sería 4,7 pp sin ponderar, pero es 1,8 pp
#     ponderada: sin fact_cal habría exagerado la brecha juvenil más del doble.
#     La muestra no es proporcional (sobrerrepresenta regiones pequeñas), y
#     fact_cal corrige eso.
#   => Cambia el nivel siempre, y la tasa cambia poco en el total pero mucho
#      en subgrupos. Todas las cifras del paso 7 son ponderadas.


# -----------------------------------------------------------------------------
# 7. RESPUESTA A LA PREGUNTA  (cifras ponderadas con fact_cal, MJJ 2026)
# -----------------------------------------------------------------------------
# (Las cifras de este bloque se leen de td_sexo, brecha y duracion_sexo.)
#
# En MJJ 2026 la tasa de desocupación fue 9,5% (981 mil personas). Ser mujer
# se asocia con una tasa 1,4 pp más alta: 10,3% vs. 8,9% en hombres. La brecha
# aparece en los cuatro grupos de edad: 1,8 pp entre 15–24 años (24,6% vs.
# 22,7%), 0,9 pp en 25–34 (12,7% vs. 11,8%), 1,3 pp en 35–54 (8,2% vs. 6,9%)
# y 0,8 pp en 55+ (6,9% vs. 6,0%). Entre desocupados, las mujeres llevan en
# promedio 6,9 meses buscando trabajo contra 6,3 de los hombres, y el 18,1%
# de ellas lleva un año o más (14,3% en hombres). Limitación: la TD solo cuenta
# a quien busca activamente; las mujeres que dejan de buscar por razones
# familiares pasan a "fuera de la FT" y no aparecen, así que la brecha puede
# subestimar la diferencia de acceso al empleo. Además no calculo errores
# estándar con el diseño muestral, así que brechas bajo 1 pp podrían no ser
# significativas.


# -----------------------------------------------------------------------------
# 8. GUARDAR BASE LIMPIA Y BITÁCORA
# -----------------------------------------------------------------------------
# Base limpia = personas de 15+ (PET), con etiquetas, con e6_* ya sin
# centinelas y con la duración de búsqueda calculada (NA para no desocupados).
ene_limpia <- ene |>
  filter(!is.na(activ)) |>                         # saca a menores de 15 (NA estructural)
  mutate(
    e6_mes = na_if(na_if(e6_mes, 88), 99),
    e6_ano = na_if(na_if(e6_ano, 8888), 9999),
    meses_busqueda = if_else(activ == 2,
                             (2026 * 12 + mes_encuesta) - (e6_ano * 12 + e6_mes),
                             NA_real_),
    meses_busqueda = if_else(meses_busqueda < 0, NA_real_, meses_busqueda)
  ) |>
  select(idrph, region, mes_encuesta, sexo, sexo_lbl, edad, tramo_edad,
         grupo_edad, activ, activ_lbl, e6_mes, e6_ano, meses_busqueda, fact_cal)

dir.create("data/processed", showWarnings = FALSE)
write.csv(ene_limpia, ruta_proc, row.names = FALSE)

filas_finales <- nrow(ene_limpia)

# --- Resultados impresos ------------------------------------------------------
cat("\n==================== RESULTADOS ====================\n")
cat("TD total ponderada:", round(td_total$td_ponderada, 1), "%  | sin ponderar:",
    round(td_total$td_sin_ponderar, 1), "%\n")
print(td_sexo |> mutate(across(where(is.numeric), ~ round(.x, 1))))
print(brecha  |> mutate(across(where(is.numeric), ~ round(.x, 1))))
print(duracion_sexo |> mutate(across(where(is.numeric), ~ round(.x, 1))))
print(efecto_centinelas)
cat("TD con na.omit() (incorrecta):", round(td_naomit, 1), "%\n")
cat("Filas iniciales:", filas_iniciales, " | finales:", filas_finales, "\n")

# =============================================================================
# BITÁCORA DE LIMPIEZA
# =============================================================================
# 1. Lectura: read_delim(delim = ";", decimal_mark = ","), guess_max = 100000.
#    0 problemas de lectura; fact_cal quedó numérico. data/raw/ no se tocó.
# 2. Columnas: de 222 a 11 (idrph, region, mes_encuesta, sexo, edad,
#    tramo_edad, activ, cae_especifico, e6_mes, e6_ano, fact_cal), con
#    starts_with("e6_") y revisión con where(is.numeric). Se verificó que activ
#    coincide con cae_especifico según el manual.
# 3. Recodificaciones (case_when + TRUE ~): sexo -> sexo_lbl; activ ->
#    activ_lbl; tramo_edad (12 tramos) -> grupo_edad (4 grupos, para no tener
#    celdas con pocos casos). Sin NA inesperados: los 15.305 NA son menores de 15.
# 4. Faltantes: tramo_edad/activ = estructural (menores de 15, excluidos);
#    e6_mes/e6_ano = estructural para ocupados e inactivos (no se les pregunta),
#    no imputados; resto de variables sin NA. na.omit() borraría a todos los
#    ocupados y llevaría la TD cerca de 100%: por eso no se usa.
# 5. Centinelas: e6_mes 88 (No sabe, 147) y 99 (No responde, 111); e6_ano
#    8888 (1) y 9999 (91). Convertidos a NA con na_if(). 258 desocupados
#    (5,8%) quedan sin duración; no se imputan. La media ponderada de meses
#    buscando pasa de −1.788 (sucia) a 6,6 meses (limpia).
#    Revisado edad = 99: no es centinela (manual: 0–120).
# 6. Ponderación: todas las cifras con fact_cal. TD total casi igual
#    (9,53% vs 9,54%), pero la brecha 15–24 pasa de 4,7 pp sin ponderar a
#    1,8 pp ponderada; el nivel pasa de 4.412 casos a 981.044 personas.
# 7. Filas: 97.946 iniciales -> 82.641 finales (PET, 15 años y más).
#    Archivo: data/processed/ene_a3.csv
# =============================================================================
