# A3 — Limpieza de datos reales del INE
### Módulo II · Semana 6 · **Actividad formativa — sin nota, entrega obligatoria**
#### Fundamentos de Programación para Análisis Económico · UdeC-EAN

**Tipo:** formativa. **Prepara directamente la [T3 (S8, regresión)](../slides/semana8_sesion1.qmd)**:
sin datos limpios no hay modelo que valga.
**Entrega:** script `.R` comentado + el dataset limpio, en tu repositorio de GitHub.


> **No lleva nota, pero es obligatoria.** Recibes retroalimentación escrita, y en
> Canvas la actividad debe estar entregada para avanzar en el módulo. El trabajo
> que hagas aquí lo vas a reutilizar en la T3 y en el Proyecto Final.

---

## Objetivo

Tomar un archivo **público, tal como lo publica la institución** y dejarlo listo
para analizar: abrirlo, reducirlo, recodificarlo, distinguir los faltantes que se
imputan de los que no, cazar los códigos centinela, ponderar y **documentar cada
decisión**.

> Datos: `data/raw/ene-2026-06-mjj.csv` — Encuesta Nacional de Empleo (INE),
> trimestre móvil mayo–julio 2026. **97.946 filas y 222 columnas**, separador `;`
> y decimales con coma. Es el archivo con que Chile calcula su tasa de desocupación.
>
> Manual de variables: `data/raw/codigos-ene-2020.pdf`. **Lo vas a necesitar.**
>
> Nadie preparó este archivo para ti. Ese es el punto: es el mismo trabajo que
> harás en el Proyecto Final con la fuente que elijas.

### Esto NO es repetir el laboratorio

El [laboratorio](../labs/semana6_lab_ene_esqueleto.R) te llevó de la mano por un
recorrido fijo: horas trabajadas y tasa de desocupación por región. Aquí eliges
**tu propia pregunta** y limpias **las variables que esa pregunta necesita** —
incluidas algunas que nadie te mostró cómo limpiar.

---

## Qué debes hacer

En un script `scripts/tarea_a3.R`, con encabezado (autor, fecha, qué hace).

### 1. Declara tu pregunta y documenta la fuente

Una pregunta sobre el mercado laboral chileno que **estos datos puedan responder**:

- ❌ «Voy a limpiar la ENE.» → no es una pregunta.
- ✅ «¿Trabajan menos horas los ocupados informales que los formales, y cuánto?»

Y la ficha de la fuente, como en el laboratorio: institución, encuesta, trimestre,
**enlace de descarga, fecha de descarga y unidad de observación**.

> Esta ficha es la que te exigirá el README del Proyecto Final. Acostúmbrate ahora.

### 2. Abre el archivo y reduce las 222 columnas

Justifica en un comentario **por qué** `read.csv()` no sirve aquí.

Quédate solo con las variables que tu pregunta necesita, usando al menos un
**selector por patrón** (`starts_with()`, `where()`) además de los nombres sueltos.

> Recuerda: `activ` es la columna 221. Las columnas `b1`, `b2`… son *preguntas del
> cuestionario*, no indicadores. Si dudas de qué es una variable, búscala en el
> manual antes de usarla.

### 3. Recodifica los códigos a algo legible

Al menos **dos** variables categóricas, con `case_when()`, pasando de números a
etiquetas con significado. Cierra con `TRUE ~` y verifica con
`table(x, useNA = "ifany")` que no quedó ningún `NA` inesperado.

> Los códigos están todos en el manual. Copiarlos mal es el error más común.

### 4. Clasifica los faltantes: estructural o real

Para **cada** variable que conserves, reporta cuántos `NA` tiene y responde en un
comentario: *¿se perdió el dato, o nunca existió?*

Demuestra que entendiste la diferencia con **una** de estas dos vías:

- Corre `na.omit()` sobre tu subconjunto y muestra **a quién borró**; explica por
  qué eso sesgaría tu respuesta.
- O imputa una variable con la mediana y muestra **a quién le inventaste un dato**;
  explica por qué no corresponde.

> No basta con decir «hay 56.096 NA». Hay que decir de quiénes son y qué implica.

### 5. Caza los centinelas — en una variable nueva

En clase limpiamos `habituales` (el `999` visible y el `888` escondido). **Esa ya
no cuenta.** Elige otra variable de tu subconjunto y audítala:

```r
sort(table(tu_variable), decreasing = TRUE)   # mira TODA la distribución
```

Busca valores imposibles o sospechosamente redondos: `88`, `99`, `888`, `999`,
`9999`, `-9`. Confirma en el manual qué significan antes de tocarlos, conviértelos
con `na_if()` y **cuantifica el efecto**: ¿cuánto cambió tu estadístico?

> Pista honesta: hay más de una variable con centinelas en esta base, y no todas
> los esconden en el máximo.

### 6. Pondera

Toda cifra que reportes debe usar `fact_cal`. Incluye **una comparación explícita**
entre tu resultado ponderado y el mismo cálculo sin ponderar, y comenta qué cambió:
¿la tasa, el nivel, o ambos?

### 7. Responde tu pregunta

De **5 a 8 líneas**, con los números que obtuviste. Tres exigencias:

- Cifras **concretas** (puntos porcentuales, horas, personas), no «es más alto».
- Di «**se asocia**», nunca «causa».
- Menciona **una limitación** de estos datos para tu pregunta.

### 8. Guarda y deja la bitácora

```r
dir.create("data/processed", showWarnings = FALSE)
write.csv(tu_base_limpia, "data/processed/ene_a3.csv", row.names = FALSE)
```

Cierra con una bitácora de limpieza: lectura, columnas conservadas, recodificaciones,
faltantes (cuáles y qué hiciste), centinelas encontrados y su efecto, ponderación,
y filas iniciales contra finales.

---

## Qué se revisa (retroalimentación, sin nota)

- [ ] Pregunta propia, respondible con esta base, escrita antes del código.
- [ ] Ficha de la fuente completa, con enlace y fecha de descarga.
- [ ] Lectura correcta del archivo, con la razón explicada.
- [ ] Reducción de columnas con al menos un selector por patrón.
- [ ] Dos recodificaciones con `case_when()`, sin `NA` inesperados.
- [ ] Faltantes clasificados como estructurales o reales, **variable por variable**.
- [ ] Demostración del sesgo de `na.omit()` **o** de la imputación indebida.
- [ ] Centinelas cazados en una variable **distinta de `habituales`**, con su
      significado verificado en el manual y el efecto cuantificado.
- [ ] Resultado ponderado con `fact_cal`, comparado contra el no ponderado.
- [ ] Interpretación con cifras, sin lenguaje causal, con una limitación.
- [ ] Dataset limpio en `data/processed/` y bitácora completa.
- [ ] `data/raw/` intacto.

---

## Entrega

1. `scripts/tarea_a3.R` en tu repositorio.
2. El CSV limpio en `data/processed/`.
3. Pega el enlace del repositorio en Canvas. **Avanza por commits**, no subas todo
   en uno.

---



**Importante en esta actividad:** puedes pedir ayuda con la **sintaxis** (cómo se
usa `na_if` o `case_when`), pero **la estrategia de limpieza debe ser tuya**: qué
está mal, qué hacer con cada problema y por qué. Ese juicio es exactamente lo que
estás entrenando aquí, y es lo que se te preguntará en la T3.

Un aviso concreto: si le pides a ChatGPT que «limpie la ENE», te va a inventar
nombres de variables que no existen en este archivo. La base tiene 222 columnas con
nombres que el modelo no conoce. **El manual manda sobre el chatbot.**
