# Bitácora de depuración y validación — Tornillo de Arquímedes CFD

**Proyecto:** Semillero SIIM — UPB Bucaramanga
**Autor:** Andrés Vidal
**Última actualización:** 11 de agosto de 2026
**Caso de validación:** Dellinger et al. (2018), *Renewable Energy* 118, 847–857
**Documento maestro:** `Protocolo_validacion_modelado_CFD_tornillo.md`

---

## 0. Resumen ejecutivo

Se auditó una corrida de Ansys Fluent v25.2 R2 (9.63 revoluciones, 2382 pasos) que arrojaba un par de **0.1662 N·m** frente a los **0.2370 N·m** de Dellinger (**−29.9 %**), muy fuera de la tolerancia de ±10 % de la §3.4.

Se identificaron **tres defectos**, en orden de importancia:

| # | Defecto | Efecto sobre el par | Estado |
|---|---|---|---|
| 1 | **Falta la 3.ª hélice del tornillo en el CAD** | Causa raíz del déficit restante | ⛔ Pendiente |
| 2 | La pared `artesa` estaba incluida en el reporte de momento | −11.3 % | ⛔ Pendiente |
| 3 | No-conservación de masa de agua de −5.3 % | Incertidumbre | ⛔ Pendiente |

Además, la simulación **nunca alcanzó régimen permanente**, por lo que ningún promedio es todavía válido.

**Conclusión clave:** la geometría reproduce **todos** los parámetros de Dellinger con exactitud milimétrica *excepto* el número de entradas del tornillo (2 en vez de 3).

---

## 1. Configuración auditada de la corrida

### 1.1 Solver

| Parámetro | Valor |
|---|---|
| Versión | Ansys Fluent v25.2 R2, 4 núcleos |
| Velocidad de giro | `−13.636 rad/s` = **130.21 rpm** |
| Paso de tiempo Δt | `0.00192299997434` s = **1.502 °/paso** |
| Periodo de revolución | 0.46078 s = **239.6 → 240 pasos/rev** |
| Pasos ejecutados | 2382 (flow-time 4.4383 s) = **9.63 revoluciones** |
| Primeros 100 pasos | Δt = 0.0005 s (arranque) |
| Max Iterations / Time Step | **20** ⚠️ insuficiente |
| Reporting Interval | 5 |
| Data Sampling for Time Statistics | ❌ desactivado |
| Modelo multifásico | VOF, phase-1 = **aire**, phase-2 = **agua** |

> ⚠️ **Coincidencia afortunada:** 130.21 rpm y Q = 2.800 L/s son *exactamente* el punto ancla de Dellinger (130 rpm, 2.8 L/s). La comparación con 0.2370 N·m es directa, sin correcciones.

### 1.2 Zona celular `rotatoria-open-cascade-step-translator-7.9-1.1`

| Ajuste | Valor | Veredicto |
|---|---|---|
| Mesh Motion | ✅ activado | Correcto |
| Frame Motion (MRF) | ❌ desactivado | Correcto |
| Relative To Cell Zone | `absolute` | Correcto |
| Origen del eje | (0, 0, 0) | Correcto |
| Dirección del eje | (0.913545, 0, −0.406737) | = **24.00° exactos** = β de Dellinger ✅ |

### 1.3 Paredes

| Pared | ID | Movimiento | Referencia | Veredicto |
|---|---|---|---|---|
| `tornillo` | 158 | Moving Wall, Rotational, 0 rad/s | Relative to Adjacent Cell Zone | ✅ Correcto |
| `artesa` | 1 | Moving Wall, Rotational, 0 rad/s | Absolute | ✅ Correcto |

La advertencia de Case Check *"Review wall motion. Stationary wall motion relative to adjacent cell zone detected"* es **benigna**: es la consecuencia esperada de una artesa correctamente fija dentro de una zona celular rotatoria.

### 1.4 Interfaces de malla

Las interfaces funcionan **perfectamente**. Solape del 100 % (todas las zonas `-non-overlapping` leen −0).

| Interfaz | Caudal másico (mezcla) |
|---|---|
| `intf:01:entrada-...::int_rot_arriba` | −2.7928446 kg/s |
| `intf:01:descarga-...::int_rot_abajo` | +2.9546727 kg/s |

> **Hipótesis descartada:** inicialmente se sospechó de interfaces rotas porque el monitor `mdot_intf` leía idénticamente cero. La causa real es que ese monitor apunta a `int_rot_arriba-non-overlapping`, que es una **pared** (id = 6), no la interfaz. Falso positivo de monitoreo.

---

## 2. Auditoría de la geometría (archivo `dominio_3cuerpos_V2.step`)

Se parseó el STEP directamente (5727 entidades, 3 sólidos, 60 caras) y se extrajeron las 24 superficies helicoidales del cuerpo rotatorio.

### 2.1 Parámetros dimensionales — todos correctos

| Parámetro | Símbolo | Medido en el CAD | Dellinger §3.1 | ✓ |
|---|---|---|---|---|
| Radio del núcleo | R_i | **52.000 mm** | 52 mm | ✅ |
| Radio exterior del álabe | R_a | 96 mm (implícito) | 96 mm | ✅ |
| Radio interior de la artesa | — | **97.000 mm** | 97 mm | ✅ |
| Holgura tornillo–artesa | s_sp | **1.000 mm** | 1 mm | ✅ |
| Paso | S | **192.0 mm** | 192 mm | ✅ |
| Longitud roscada | L_B | **400.0 mm** (s = −425 a −25) | 400 mm | ✅ |
| Ángulo de inclinación | β | **24.00°** | 24° | ✅ |
| Espesor del álabe | — | ≈ 3.7 mm | — | — |
| **Número de entradas** | **N** | **2** | **3** | ❌ |

### 2.2 ⛔ Hallazgo crítico: falta la tercera hélice

Se calculó la **fase helicoidal** de cada superficie B-spline (el ángulo azimutal descontando el avance de la hélice, θ − k·s con k = 0.03272 rad/mm). Resultado:

| Fase | N.º de superficies | Interpretación |
|---|---|---|
| **73.0°** y 76.8° | 12 | Álabe 1 (cara de presión + cara de succión) |
| **193.0°** y 196.8° | 12 | Álabe 2 (cara de presión + cara de succión) |
| **313.0°** y 316.8° | **0** | ⛔ **ÁLABE 3 AUSENTE** |

**Evidencias convergentes:**

1. **Separación de 120°** entre las dos fases presentes → el CAD fue *diseñado* como tornillo de 3 entradas; simplemente no se generó la tercera.
2. **Conteo de superficies:** 2 álabes × 2 caras × 6 tramos axiales = **24** superficies, que es exactamente lo que contiene el archivo. Con 3 álabes serían 36.
3. **Análisis espectral (FFT) de la señal de par:** pico medido a **4.244 Hz**. Con f_rot = 2.170 Hz, la frecuencia de paso de álabe sería 4.340 Hz para N = 2 (**−2.2 % de error**) y 6.511 Hz para N = 3 (−34.8 %).
4. **Oscilación violenta del caudal de salida** (σ = 1.44 kg/s = ±51 % del caudal de entrada), compatible con agua cayendo en cascada libre por el hueco angular de **236°** que deja el álabe faltante, en vez de ser transportada en cangilones cerrados.

---

## 3. Auditoría del reporte de par

### 3.1 ⛔ Defecto: la artesa estaba incluida

`report-def-0` (Moment Report) tenía seleccionadas **dos** zonas: `artesa` **y** `tornillo`. Solo debe estar `tornillo` (§6.5 punto 1: *"par sobre todas las paredes del tornillo"*).

Verificación directa hecha por el usuario con `Compute`:

| Zonas seleccionadas | Par instantáneo (último paso) |
|---|---|
| `artesa` + `tornillo` | 0.16621119 N·m |
| **solo `tornillo`** | **0.18741116 N·m** |
| **Factor de corrección** | **× 1.12756** (la artesa suprimía el 11.3 %) |

Centro de momento (0,0,0) ✅ y eje de momento (0.91355, 0, −0.4067) ✅ están correctos.

### 3.2 Resultados del par

Promedios por revolución (ventanas de 240 pasos), con artesa incluida:

| Rev | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 |
|---|---|---|---|---|---|---|---|---|---|
| C̄ [N·m] | 0.11925 | 0.12489 | 0.16422 | 0.16913 | 0.15447 | 0.17040 | 0.18804 | 0.17246 | 0.17097 |
| Δ vs anterior | — | +4.73 % | +31.49 % | +2.99 % | −8.67 % | +10.31 % | +10.35 % | −8.29 % | **−0.87 %** |

El criterio de la §6.6 exige **< 0.5 %** entre revoluciones consecutivas. La última diferencia es −0.87 %: **cerca, pero aún no cumple**.

### 3.3 Balance de resultados

| Magnitud | Con artesa | **Solo tornillo (corregido)** | Dellinger | Error |
|---|---|---|---|---|
| C̄ (últimas 4 rev) | 0.17547 N·m | **≈ 0.1979 N·m** | 0.2370 N·m | **−16.5 %** |
| Potencia mecánica | 2.393 W | **≈ 2.698 W** | 3.232 W | −16.5 % |
| Rendimiento η | 0.556 | **≈ 0.627** | 0.751 | −12.4 pp |

*(P_mec = C·ω con ω = 13.636 rad/s; η = P_mec / (ρgQH) con Q = 2.800 L/s, H ≈ 0.157 m → P_hid = 4.3043 W)*

**Interpretación:** quitar la artesa recupera ~10 puntos porcentuales del déficit (de −26.0 % a −16.5 %). El **−16.5 % restante se atribuye al álabe faltante**.

Estadísticos de la serie (desde el paso 300): media 0.16045, mín 0.05177, máx 0.20808, σ 0.02765 N·m.

> 📌 El valor "0.203" que se perseguía manualmente corresponde al **máximo de la oscilación** (0.20808), no a una tendencia. Una regresión lineal sobre los 19 valores anotados a mano dio R² = 0.098 (t ≈ 1.36, no significativo): **no hay tendencia, hay oscilación.**

---

## 4. Auditoría del balance de masa

### 4.1 Separación de fases (Flux Report, instante final)

| Frontera | Mezcla | Aire (ph-1) | **Agua (ph-2)** |
|---|---|---|---|
| `inlet` | 2.795001 | 0.000328 | **2.794673** |
| `outlet` | −3.488581 | −0.015658 | **−3.472923** |
| `top` | 0.008873 | 0.008873 | **0.000000** |
| `top.1` | 0.007302 | 0.007302 | **0.000000** |
| **NETO** | **−0.677404** | **+0.000845** | **−0.678250** |

✅ **El aire cierra perfectamente.** ✅ **`top` y `top.1` son respiraderos 100 % aire** (fuga de agua exactamente nula) — montaje correcto.
❌ **El desbalance es íntegramente agua.**

> ⚠️ El valor `Net = −0.67869626` que reporta Fluent **no es el balance de masa**: suma interfaces (que se cancelan) y planos `interior--*` (que no son fronteras). El balance real sobre fronteras externas es −0.677404 kg/s.

### 4.2 Error de conservación promediado en el tiempo

El desbalance instantáneo es ruido puro: en las últimas 4 revoluciones va de **−3.22 a +2.57 kg/s** (σ = 1.44). El instante capturado (−0.678) está en el percentil 43, es decir, es típico.

Restando el cambio de almacenamiento de agua del dominio:

| Ventana | Flujo neto | Almacenamiento | **Error de conservación** |
|---|---|---|---|
| Última 1 rev | −0.849 kg/s | −0.710 kg/s | **−0.1395 kg/s (−4.99 %)** |
| Últimas 4 rev | −0.354 kg/s | −0.204 kg/s | **−0.1497 kg/s (−5.36 %)** |
| Últimas 8 rev | +0.347 kg/s | +0.496 kg/s | **−0.1493 kg/s (−5.34 %)** |

El flujo neto **cambia de signo** según la ventana, pero el error de conservación es **idéntico en las tres**. Es una **pérdida numérica sistemática de agua de 0.149 kg/s ≈ 5.3 % del caudal**. La §6.5 exige que tienda a 0; lo aceptable es < 1 %.

**Sospechoso principal:** solo **20 iteraciones internas por paso de tiempo**. Con VOF y malla deslizante rara vez bastan para cerrar continuidad.

### 4.3 Régimen permanente: no alcanzado

| Ventana | dV_agua/dt |
|---|---|
| 1 rev | −7.11×10⁻⁴ m³/s |
| 2 rev | **+1.72×10⁻⁴** |
| 4 rev | −2.05×10⁻⁴ |
| 8 rev | **+4.97×10⁻⁴** |

El signo alterna entre ventanas → el dominio sigue chapoteando, no se ha estabilizado. **Ningún promedio es válido todavía.**

---

## 5. Plan de acción

### FASE A — Corregir la geometría ⛔ BLOQUEANTE

- [ ] **A1.** Abrir el modelo del tornillo en SolidWorks (o SpaceClaim).
- [ ] **A2.** Seleccionar la hélice/barrido existente y aplicar un **patrón circular**: eje = eje del tornillo, **3 instancias, 120°, espaciado igual**. Verificar que aparezcan álabes a 73°, 193° y **313°**.
- [ ] **A3.** Rehacer la resta booleana para obtener el dominio fluido rotatorio.
- [ ] **A4.** Exportar STEP y **verificar que contenga 36 superficies B-spline** (no 24).
- [ ] **A5.** Confirmar que R_i = 52, artesa = 97, S = 192, L_B = 400, β = 24° se conservan.

### FASE B — Corregir el montaje de Fluent

- [ ] **B1.** `report-def-0`: quitar `artesa` de las zonas. Dejar **solo `tornillo`**.
- [ ] **B2.** `report-def-0` y `report-def-1`: poner `Average Over (Time Steps)` = **240** (promedio automático por revolución).
- [ ] **B3.** Redefinir `report-def-1` como **par viscoso** (actualmente duplica a `report-def-0`: 0.16644 vs 0.16643). Así se obtiene C_screw = C_p − C_v (§6.5 punto 2).
- [ ] **B4.** Corregir `mdot_intf`: apuntar a `intf:01:entrada-open-cascade-step::int_rot_arriba`, **no** a `int_rot_arriba-non-overlapping` (que es una pared).
- [ ] **B5.** Subir `Max Iterations/Time Step` de **20 → 40**.
- [ ] **B6.** Revisar el esquema VOF: si es **Explicit**, Courant VOF ≤ 0.25; si es **Implicit**, activar **Implicit Body Force**.
- [ ] **B7.** Ejecutar `General → Check` sobre la malla.
- [ ] **B8.** Confirmar cuál proyecto es el vigente: `TesteoMeshFull_files` (`ASG_M1_LISTOV6`) vs `TesteoSimulacion_files` (de donde salieron los `.out` analizados).
- [ ] **B9.** Activar `File → Write → Start Transcript` **antes** de correr (el `Solution.trn` actual es un log de escritura de malla de 3 segundos, inservible).

### FASE C — Correr hasta régimen y validar

- [ ] **C1.** Correr hasta que las pendientes de `vol_agua_entrada`, `vol_agua_descarga` y `vol_agua_rotatoria` sean ≈ 0 **con signo estable** entre ventanas.
- [ ] **C2.** Verificar residual de continuidad < 10⁻⁵ en cada paso (§6.6).
- [ ] **C3.** Verificar error de conservación de agua **< 1 %**.
- [ ] **C4.** Activar `Data Sampling for Time Statistics` — **solo una vez en régimen**, nunca durante el transitorio.
- [ ] **C5.** Promediar C_screw sobre **4 revoluciones**; exigir < 0.5 % entre revoluciones consecutivas.
- [ ] **C6.** Comparar con Dellinger: par ≤ 10 %, η ≤ 8 pp (§3.4).

### FASE D — Incertidumbre numérica (la respuesta al profesor)

- [ ] **D1.** Construir **3 mallas** (~0.7 M / 1.4 M / 2.2 M celdas, §6.2.1) con razón de refinamiento r ≥ 1.3.
- [ ] **D2.** Correr las tres al mismo punto de operación.
- [ ] **D3.** Calcular orden observado p, valor extrapolado C(h→0) y **GCI** (§6.2.1).
- [ ] **D4.** Reportar el par como **C ± GCI**.

---

## 6. Nota metodológica: la pregunta del profesor

> *"¿Se puede hacer una regresión lineal con los resultados y hacer una proyección del resultado si se tuviera la capacidad computacional?"*

**Respuesta corta: sí, pero no sobre el tiempo — sobre el tamaño de malla.**

- ❌ **Regresión lineal sobre el tiempo de simulación: no es válida.** La señal de par es oscilatoria (paso de álabes), no una tendencia asintótica. Ajustar una recta a 19 valores dio R² = 0.098. La convergencia temporal se demuestra con el criterio de < 0.5 % entre promedios por revolución, no con una regresión.
- ✅ **Extrapolación de Richardson sobre el refinamiento de malla: sí es válida** y es exactamente el método estándar (ASME V&V 20) que ya está escrito en la §6.2.1 del protocolo. Se corren 3 mallas, se ajusta C(h) = C(h→0) + α·h^p y se extrapola a h → 0. El **GCI** cuantifica la banda de incertidumbre.

**Demostración con la propia tabla de Dellinger** (mallas 2.4 M / 5.0 M / 8.8 M → 0.2423 / 0.2370 / 0.2360 N·m):

| Cantidad | Valor |
|---|---|
| Razón de refinamiento r₂₁ | 1.207 |
| ε₂₁ | 0.0010 |
| ε₃₂ | 0.0053 |
| Orden observado p | 7.8 (irrealmente alto → no está en rango asintótico) |
| **C extrapolado (h→0)** | **0.2357 N·m** |
| **GCI₂₁** | **0.16 %** |

> ⚠️ **Advertencia importante:** el refinamiento es **monótonamente decreciente**. Más capacidad computacional daría un par **menor**, no mayor. No se puede extrapolar *hacia arriba* para alcanzar 0.203 — y de hecho el objetivo correcto es 0.2370, no 0.203.

---

## 7. Registro de errores de diagnóstico (y sus retractaciones)

Se documentan para trazabilidad metodológica:

| # | Hipótesis inicial | Veredicto | Causa real |
|---|---|---|---|
| 1 | `mdot_intf ≡ 0` indica interfaz de malla rota | ❌ **Retractada** | El monitor apuntaba a una pared (`int_rot_arriba-non-overlapping`, id = 6). Las interfaces funcionan con 100 % de solape. |
| 2 | n = 86.67 rpm (asumiendo Δt = 1°/paso) | ❌ **Retractada** | Speed = −13.636 rad/s → **130.21 rpm**, Δt = 1.502°/paso, 240 pasos/rev, 9.63 revoluciones (no 6.41). |
| 3 | El desbalance de masa es aire atrapado | ❌ **Descartada** | El aire cierra en +0.000845 kg/s. El desbalance es 100 % agua. |
| 4 | La advertencia de wall motion del Case Check es un error | ❌ **Descartada** | Es benigna y esperada para una artesa fija en zona rotatoria. |

---

## 8. Referencias y rutas

**Bibliografía**
- Dellinger, G. et al. (2018). *Renewable Energy* **118**, 847–857. — caso de validación
- Rohmer, J. et al. (2016). *Renewable Energy* **94**, 136–146.
- ASME V&V 20 — método GCI

**Rutas de trabajo (Windows)**
```
C:\Users\estudiante.upb\Documents\Semillero\Modelos\Workbench\
  ├── TesteoSimulacion_files\dp0\FFF\Fluent\   ← origen de los .out analizados
  └── TesteoMeshFull_files\dp0\FFF\Fluent\     ← proyecto actualmente abierto (ASG_M1_LISTOV6)
```

**Report definitions existentes**
`delta-time`, `iters_per_timestep`, `mdot_inlet`, `mdot_intf`, `mdot_outlet`, `report-def-0` (par), `report-def-1` (par, duplicado), `report-def-2` (`vol_agua_rotatoria`), `vol_agua_descarga`, `vol_agua_entrada`

**Formato de los `.out`:** `("Time Step" "<nombre>" "flow-time")`

---

## 9. Estado global

| Ítem | Estado |
|---|---|
| Interfaces de malla | ✅ Correctas, solape 100 % |
| Mesh Motion (no MRF) | ✅ Correcto |
| Movimiento de paredes (tornillo / artesa) | ✅ Correcto |
| Eje de rotación (24.00°) | ✅ Correcto |
| Geometría: R_i, R_a, S, L_B, β, holgura | ✅ Idénticos a Dellinger |
| Respiraderos `top` / `top.1` | ✅ 100 % aire, sin fuga de agua |
| Balance de aire | ✅ Cierra |
| Punto de operación (130 rpm, 2.8 L/s) | ✅ Coincide con el ancla de Dellinger |
| Monitor `mdot_intf` | ❌ Apunta a una pared |
| `artesa` en el reporte de par | ❌ −11.3 % del par |
| **Falta el 3.er álabe (313°)** | ⛔ **Causa raíz** |
| Conservación de agua | ❌ −5.3 % sistemático |
| Régimen permanente | ❌ No alcanzado |
| Estudio de malla + GCI | ⬜ No iniciado |
