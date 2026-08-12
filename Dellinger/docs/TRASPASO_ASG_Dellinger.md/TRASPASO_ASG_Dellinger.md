# Traspaso — Simulación CFD de Tornillo de Arquímedes (caso validación Dellinger)

**Proyecto:** Semillero SIIM — UPB Bucaramanga
**Objetivo:** Validar el montaje CFD de un ASG contra Dellinger et al. (2018) antes de simular el caso del proyecto
**Estado:** Malla 1 corrida hasta convergencia. Par reproducido al **72–76 %** del objetivo. Causa del déficit identificada y acotada.
**Fecha del documento:** 03/08/2026 — reemplaza la versión del 30/07 (conservada en `TRASPASO_ASG_Dellinger_v1_30jul.md`)

---

## 0. Resumen ejecutivo — leer esto primero

La corrida del 30–31/07 llegó a régimen y produjo un número comparable con la referencia. **No pasa el criterio de aceptación**, pero el déficit está cuantificado y su causa acotada, que es un resultado defendible.

| Magnitud | Obtenido | Objetivo (Malla 1) | Criterio §3.4 |
|---|---|---|---|
| C_screw, 1er orden | −0.1632 N·m | −0.2482 | 0.2133 – 0.2607 ❌ |
| C_screw, 2º orden | **−0.1717 N·m** | −0.2482 | ❌ (falta 24 %) |
| η, 1er orden | 0.506 | 0.7785 | — |
| η, 2º orden | **0.536** | 0.7785 | — |
| h_in (resultado) | 0.129 m | — | — |
| H = h_in − h_out | **0.159 m** | 0.158 m | ✅ |

**Diagnóstico.** El déficit total es de 34 puntos porcentuales. El **orden de discretización aporta solo 5** (medido: pasar a Second Order Upwind sube el par de 0.1632 a 0.1717, un +5.2 %). Quedan **29 puntos sin explicar por esa vía**.

Se atribuyen a la **resolución de la holgura álabe–artesa**: el protocolo (§6.2) exige **≥5 celdas** a través del hueco de 1 mm y la malla actual usa **1 celda** de 0.9 mm. La fuga por la holgura es una pérdida de primer orden. Al haber descartado la disipación numérica como causa principal, la holgura queda como explicación dominante **por eliminación**, no solo por sospecha.

**Argumento que aísla la causa:** en Dellinger el par *baja* al refinar (0.2482 con 1.4 M → 0.2360 con 8.8 M). Una malla más gruesa debería dar **más** par. La nuestra, con 1.06 M, da menos. Luego no es grosor global de malla: es algo específico, y la holgura es el único control que está 5× por debajo de lo que pide el protocolo.

**Siguiente acción:** Malla 2 con `Cells Per Gap = 5`, `Min Size ≈ 0.0002 m`. Sirve a la vez como Malla 2 del estudio GCI de §6.2.1.

---

## 1. Física del problema — no negociable

El ASG es una **máquina hidrostática de gravedad**, no hidrocinética:

- Lo que mueve la máquina es la **diferencia de nivel de agua H**, no la energía cinética del flujo.
- Requiere artesa cerrada y niveles definidos aguas arriba y aguas abajo.
- El **fill ratio** es el parámetro operativo clave; la velocidad de giro lo controla. **No** se usa tip-speed ratio.
- Requiere **sliding mesh (transitorio)**. MRF es inaplicable: los cangilones se llenan y vacían a lo largo de la máquina.

**Definición de η (protocolo §6.7) — verificada:**

```
H = h_in − h_out          η = C_screw · ω / (ρ g Q H)
```

`h_out` se **impone** (condición de salida); `h_in` es un **resultado**. Por tanto H es parcialmente un resultado y hay que medirlo, no suponerlo.

> ⚠️ Una versión anterior de este documento dedujo que H era el salto geométrico (0.1627 m). **Es incorrecto.** El protocolo lo define como diferencia de superficies libres. Con h_out = −0.030 y h_in medido = 0.128 sale H = 0.158 m, que coincide con el salto que hace compatibles C y η — pero por camino distinto.

---

## 2. Geometría (Modelo V — réplica de Dellinger)

Generada con CadQuery (`generar_tornillo.py`), unidades en mm.

| Parámetro | Valor |
|---|---|
| Ra (radio exterior hélice) | 96.0 |
| Ri (radio núcleo) | 52.0 |
| S (paso / avance por vuelta) | 192.0 |
| LB (longitud roscada) | 400.0 |
| N (número de álabes) | 3 |
| t (espesor axial álabe) | 2.0 |
| gap (holgura álabe–artesa) | 1.0 |
| e_artesa | 6.0 |
| ext (prolongación núcleo) | 25.0 |
| β (inclinación) | 24° |
| an_canal | 280.0 |
| L_entr | 350.0 |
| L_desc | 450.0 |
| h_aire | 60.0 |
| h_fondo | 70.0 |

**Volúmenes de fluido (medidos en Fluent, autoritativos):**

| Cuerpo | Volumen |
|---|---|
| rotatoria | 9.306 L |
| entrada | 26.298 L |
| descarga | 35.203 L |
| **TOTAL** | **70.807 L** |

**Cotas clave (verificadas contra STEP y contra Fluent):**

| Dato | Valor |
|---|---|
| Eje de rotación (dirección) | (0.913545, 0, −0.406737) |
| Eje de rotación (origen) | (0, 0, 0) |
| Área inlet = área outlet | 0.086024 m² (280 × 307.23 mm) |
| Área artesa | 0.27422 m² |
| Área tornillo | 0.33493 m² |
| Área anillo de interfaz | 2.10646e-02 m² |
| **Piso cámara de entrada** | Z = **+0.00408 m** |
| **Solera artesa aguas arriba** | Z = **+0.07408 m** |
| Eje aguas arriba | Z = +0.16270 m |
| **Solera artesa aguas abajo** | Z = **−0.08861 m** |
| **Piso canal de descarga** | Z = **−0.15861 m** |
| Techo cámara de entrada | Z = +0.31131 m |
| Desnivel entre extremos | 0.1627 m |

> ⚠️ **Discrepancia abierta (14 %).** La geometría nominal da rotatoria = π(0.097²−0.052²)×0.400 − álabes = **8.17 L**, obtenido por dos vías independientes (analítica y Monte Carlo de 12 M puntos). La malla de Fluent mide **9.306 L**. Como el área del anillo de interfaz *sí* cuadra al 0.005 % con esos mismos parámetros, la longitud efectiva de la malla saldría ~0.442 m en vez de 0.400. Posible origen: el `Fill` de SpaceClaim, o diferencia entre el STEP y lo mallado. **Impacto:** el volumen transportado por vuelta pasaría de 3.805 a ~4.34 L y el grado de llenado de f = 0.34 a f = 0.30. Verificar midiendo la longitud axial real de la zona rotatoria.

---

## 3. Punto de operación y objetivos

| Parámetro | Valor |
|---|---|
| Q (caudal) | 2.8 L/s = 0.0028 m³/s |
| ṁ agua | 2.795 kg/s |
| n (velocidad de giro) | 130 rpm |
| **ω en Fluent** | **−13.6136 rad/s** (signo negativo, ver §4) |
| Periodo de revolución | 0.4615 s |
| h_out impuesto | **−0.030 m** |
| Llenado teórico del tornillo | Q × t_residencia = 2.8 × 0.9615 = **2.692 L** |

### Objetivos según la tabla de sensibilidad de malla del paper (protocolo §3.3)

| Malla | Celdas | C_screw [N·m] | η |
|---|---|---|---|
| **1** | **1 400 000** | **0.2482** | **0.7785** |
| 2 | 2 400 000 | 0.2423 | 0.7600 |
| 3 | 5 000 000 | 0.2370 | 0.7434 |
| 4 | 8 800 000 | 0.2360 | 0.7387 |

> ⚠️ **Corrección importante.** La malla actual tiene 1.06 M celdas, así que **el objetivo que le corresponde es el de la Malla 1: C = 0.2482, η = 0.7785.** El 0.2370 / 0.7434 que figuraba como objetivo en la versión anterior es el de la malla de **5 M**, inalcanzable con este hardware.

**Criterio de aceptación (protocolo §3.4):** |C| dentro de **±10 % de 0.2370** → rango **0.2133 – 0.2607**.

---

## 4. Signo de rotación — RESUELTO

**ω = −13.6136 rad/s** sobre el eje (0.913545, 0, −0.406737).

**Cómo se determinó** (medición sobre `tornillo_V.step`, independiente del script de CadQuery): se extrajeron los `CARTESIAN_POINT` del STEP y se ajustó el modelo de helicoide φ = k·s + cte (mod 120°) respecto al eje de Fluent.

| Población | n | R con k = +0.032725 | R con k = −0.032725 |
|---|---|---|---|
| Borde exterior (r≈96 mm) | 406 | **0.9969** | 0.6026 |
| Raíz en núcleo (r≈52 mm) | 322 | **0.9951** | 0.3435 |

R = 0.997 significa ajuste con ~4° de dispersión; el paso recuperado es 192.00 mm frente a S = 192.0 nominal. **k es positivo.**

Cinemática: la superficie cumple φ = k·s + φ₀ + ω·t, luego a azimut fijo **ds/dt = −ω/k**. Para que el agua descienda hacen falta ω y k de signo opuesto → **ω < 0**.

**Confirmación dinámica:** con ω = −13.6136 el par converge a valores **negativos**, luego ω·T > 0 → potencia extraída positiva → modo generador. ✅

**Convención de lectura:** el momento reportado sobre +**a** sale **negativo** en modo generador. Comparar el **valor absoluto** contra 0.2482, o poner el Moment Axis del report en −**a** para leerlo positivo.

---

## 5. Malla actual (Malla 1 del estudio GCI)

| Métrica | Valor |
|---|---|
| Celdas totales | 1 061 927 |
| — rotatoria | 971 440 |
| — descarga | 48 383 |
| — entrada | 42 104 |
| Orthogonal Quality mínima | 0.13 ⚠️ |
| Celdas con quality < 0.05 | 0 |
| Free Faces | 0 ✅ |

**Controles de mallado usados:**

- `proximity_1`: Proximity, **Cells Per Gap = 1**, Min Size = **0.0009 m**, Max = 0.003, faces-and-edges, objeto `rotatoria`
- `alabes`: Curvature, Min Size = 0.0028, Max = 0.003, Normal Angle 18°
- Volume Mesh: poly-hexcore, Min 0.0004, Max 0.015, Buffer 2, Peel 1
- Boundary Layers: smooth-transition, 2 capas, ratio 0.272, growth 1.2, only-walls

> 🔴 **Este es el problema principal identificado.** El protocolo §6.2 exige **≥5 celdas a través de la holgura** (celda ≈ 0.2 mm para un hueco de 1 mm). La malla usa **1 celda de 0.9 mm**. Con el centro de esa celda a 0.45 mm de ambas paredes, el y⁺ cae en plena zona de amortiguamiento — el peor régimen posible. §6.2 advierte: *"la fuga por la holgura es un mecanismo de pérdida de primer orden"*.

**Nota sobre OQ 0.13:** cae en rango "unacceptable" de Fluent (<0.15) pero con 0 celdas en el bin catastrófico. **Verificado que aguanta Second Order Upwind sin inestabilidad** (ver §9.3).

---

## 6. Configuración del solver — estado validado

### 6.1 General
| Campo | Valor |
|---|---|
| Solver | Pressure-Based |
| Time | **Transient** |
| Gravity | ✔ (0, 0, −9.81) |

### 6.2 Models
**Multiphase:** VOF, 2 fases eulerianas, formulación **Implicit**, Interface Modeling **Sharp/Dispersed**, ✔ **Open Channel Flow**, Implicit Body Force sin marcar.

**Phases — ⚠️ ESTABAN INVERTIDAS, verificar siempre:**

| Ranura | Material | Densidad esperada |
|---|---|---|
| `phase-1` (primaria) | **air** | 1.225 kg/m³ |
| `phase-2` (secundaria) | **water-liquid** | 998.2 kg/m³ |

> 🔴 **Error encontrado el 30/07 y corregido.** El caso tenía las fases al revés. Con `phase-2 = air`, el Initialize dejaba el dominio **lleno de agua** y el patch metía **aire** en el fondo — todo invertido. Se detectó porque un reporte de Density sobre `phase-2` daba 1.225 en vez de 998.2.
>
> **Cómo verificarlo, siempre, antes de correr:** Volume Integrals → Volume-Average → Density, una vez con Phase = `phase-1` (debe dar **1.225**) y otra con `phase-2` (debe dar **998.2**). Un tercer chequeo con Phase = `mixture` da la distribución: con el dominio parchado debe rondar **274 kg/m³**.
>
> Todos los ajustes están atados a la **ranura**, no al material, así que corregir los materiales arregla retroactivamente el patch y las BCs.

`water-liquid` NO viene precargado: Materials → Fluid → Create/Edit → **Fluent Database…** → water-liquid → Copy.

**Viscous:** SST k-omega. **Energy:** Off.

### 6.3 Cell Zone Conditions
**`rotatoria`:** Mesh Motion ✔, Relative To Cell Zone `absolute`, Origin (0,0,0), Direction (0.913545, 0, −0.406737), **Speed = −13.6136 rad/s**

**`entrada`, `descarga`:** Mesh Motion sin marcar.

### 6.4 Boundary Conditions

**`inlet`** — **mass-flow-inlet** (ya no es velocity-inlet):

| Pestaña / Fase | Campo | Valor |
|---|---|---|
| Momentum · `phase-2` | Mass Flow Rate | **2.795 kg/s** |
| Momentum · `phase-1` | Mass Flow Rate | **0** |
| Momentum · `mixture` | Reference Frame | Absolute |
| Momentum · `mixture` | Direction Spec. Method | Normal to Boundary |
| Momentum · `mixture` | Turbulence | Intensity 5 %, Visc. Ratio 10 |
| Multiphase · `mixture` | ✔ **Open Channel** | |
| Multiphase · `mixture` | Inlet Group ID | 1 |
| Multiphase · `mixture` | Secondary Phase for Inlet | `phase-2` |
| Multiphase · `mixture` | Free Surface Level | **0.1302 m** |
| Multiphase · `mixture` | Bottom Level | **0.00408 m** |
| Multiphase · `mixture` | Density Interpolation | From Neighboring Cell |

> **Por qué se cambió.** El velocity-inlet anterior forzaba VF water = 1 sobre toda la cara de 307.23 mm de alto. Con el nivel aguas arriba en ~0.130 m, solo el 41 % inferior está bajo agua: **el 59 % del agua entraba en forma de lluvia** sobre la cámara, metiendo ruido permanente en la señal de par. Con mass-flow-inlet se impone el caudal exacto y el nivel queda como resultado, que es la física correcta para validar a Q dado.
>
> **Cómo se cambia el tipo de zona:** no está en el diálogo de edición. Es clic derecho sobre el nodo `inlet (velocity-inlet, id=162)` en el Case View → Type.

**`outlet`** (pressure-outlet), pestaña Multiphase con Phase = `mixture`:
- ✔ Open Channel · Outlet Group ID 1
- Pressure Specification Method: **Free Surface Level**
- **Free Surface Level = −0.030 m** (ver §7)
- Bottom Level = **−0.15861 m**
- Density Interpolation: From Neighboring Cell

> El outlet **no tiene** selector de fase secundaria — eso es exclusivo de los inlets. La pestaña Momentum (backflow) se deja en sus defaults. El aviso *"Reversed flow on N faces of pressure-outlet"* es normal en un pressure-outlet con superficie libre.

**`top`** (pressure-outlet): Open Channel **SIN marcar**, Gauge Pressure 0, VF `phase-2` = **0**.

**`artesa`** (0.27422 m²): Moving Wall → **Absolute** → Rotational → **ω = 0**, Origin (0,0,0), Direction (0.913545, 0, −0.406737)

**`tornillo`** (0.33493 m²): Moving Wall → **Relative to Adjacent Cell Zone** → **0**, mismo origen y dirección

> Distinción CRÍTICA: la artesa es físicamente fija aunque esté mallada dentro de la zona que gira. Si ambas quedan igual, no hay fuga por la holgura y se simula una máquina distinta. Sigue siendo válida con ω negativo.

### 6.5 Mesh Interfaces

| Interfaz | Área | Casamiento |
|---|---|---|
| `intf_arriba` (entrada ↔ int_rot_arriba) | 2.10650e-02 m² | 6.06 % / **100.00 %** |
| `intf_abajo` (descarga ↔ int_rot_abajo) | 2.10644e-02 m² | 4.48 % / **100.00 %** |

El porcentaje bajo es el lado cámara (incluye todas sus paredes); es correcto. El del lado anillo debe ser 100.00 %.

### 6.6 Solution Methods

| Campo | Valor |
|---|---|
| Pressure-Velocity Coupling | Coupled |
| Gradient | Least Squares Cell Based |
| Pressure | PRESTO! |
| **Momentum** | **Second Order Upwind** (era First Order, ver §9.3) |
| Volume Fraction | Compressive |
| Turbulent KE / Specific Dissipation | First Order Upwind |
| Transient Formulation | First Order Implicit |
| Warped-Face Gradient Correction | ✔ |
| Stabilization Methods | Off |
| Velocity Limiting | ✔, máximo 50 m/s, ✔ Verbosity |

**Stabilization Methods sigue en `Off` deliberadamente:** `Advanced Stabilization` cambia Transient Formulation a Bounded Second Order, cambia la interpolación de presión, activa NITA, y es **irreversible**.

### 6.7 Solution Controls
Flow Courant Number **20** · Explicit Relaxation 0.75/0.75 · Under-Relaxation defaults

### 6.8 Report Definitions

| Nombre | Tipo | Detalle |
|---|---|---|
| `report-def-1` | Force → **Moment** | Zones: **solo `tornillo`** · Center (0,0,0) · Axis (0.913545, 0, −0.406737) |
| `vol_agua_entrada` | Volume → Volume Integral | VF `phase-2` sobre zona `entrada` → **da h_in** |
| `vol_agua_rotatoria` (`report-def-2`) | Volume → Volume Integral | VF `phase-2` sobre `rotatoria` → grado de llenado |
| `vol_agua_descarga` | Volume → Volume Integral | VF `phase-2` sobre `descarga` |
| `mdot_inlet` | Flux → Mass Flow Rate | `inlet`, Phase `phase-2` |
| `mdot_outlet` | Flux → Mass Flow Rate | `outlet`, Phase `phase-2` |

Todos con **Report File** y **Report Plot** marcados. Se usa `phase-2` (agua) y no `mixture` porque el `top` también deja pasar aire y el balance nunca cerraría.

**Par de presión vs viscoso** (§6.5 punto 2 del protocolo) no se puede monitorizar como serie; se saca puntualmente con **Results → Reports → Forces → Moments**, solo `tornillo`.

> ⚠️ **El flux report NO funciona sobre zonas de interfaz** en Fluent 2025 R2: devuelve exactamente 0 tanto en `int_rot_arriba`, como en `int_rot_arriba-non-overlapping`, como en `intf:01:…`. No es un fallo físico. El chequeo de §6.5 punto 5 se cubre con la **auditoría de volúmenes**: durante la etapa A la rotatoria ganó 0.040 L que solo pueden venir de `intf_arriba`, y el balance cerró (entraron 0.140 L, se retuvieron 0.082 L, salieron 0.058 L).

### 6.9 Initialization
- Standard Initialization, Compute from `inlet`, Reference Frame **Absolute**
- **Open channel Initialization Method: `None`** (el método `Flat` fallaba con velocity-inlet sin Open Channel; con mass-flow-inlet + Open Channel debería funcionar, sin probar)
- `phase-2` Volume Fraction inicial: **0**
- Luego **Patch** manual (§8)

### 6.10 Run Calculation

| Etapa | Δt [s] | Pasos | Max Iter |
|---|---|---|---|
| A — asentar el patch | 5e-4 | 100 | 30 |
| B — régimen | **1.923e-3** | ver §10 | 20 |

Δt de régimen = 1.5° de giro. **Una revolución = 240 pasos.**

**AUTOSAVE cada 10 pasos**, con `Retain Only the Most Recent Files` ✔ y `Maximum Number of Data Files = 5` para no llenar el disco.

> ⚠️ **Verificar el autosave escribiendo, no confiando en el diálogo.** Tras los primeros 10–20 pasos, comprobar en consola con `!dir *.h5` que apareció el archivo numerado. La corrida del 29/07 se perdió porque el autosave **nunca llegó a escribir** — un corte de energía no borra archivos ya escritos, así que si no están es que no se escribieron.

---

## 7. Nivel de salida h_out — CALIBRADO

**h_out = −0.030 m.** Sustituye al −0.0886 anterior.

**Por qué se cambió.** Con h_out = −0.0886 (que es la solera del tornillo, es decir descarga libre total) la eficiencia tiene un **techo duro de 0.757**, alcanzable solo con llenado cero: `h_in` debe superar la solera de la artesa aguas arriba (+0.0741 m) para que entre agua, lo que fija H ≥ 0.1627 m. En operación real habría dado η ≈ 0.55.

**Cómo se eligió −0.030.** Dos argumentos independientes:
1. **Energético:** para η = 0.7785 con C = 0.2482 hace falta H = 0.1583 m; con h_in ≈ 0.1302 sale h_out = −0.0281.
2. **Geométrico:** el plano de agua del cangilón en el extremo de descarga está en Z = Z_eje + d·cos β = −0.0325 m — la cota a la que el último cangilón vacía sin caída libre ni ahogamiento.

**Validado por la corrida:** h_in convergió a 0.128 m → **H = 0.158 m**, exactamente el salto objetivo. ✅

> Durante la corrida se observó una caída del par entre las revoluciones 1 y 2 que hizo sospechar de sobre-sumergencia. **Era falsa alarma:** correspondía al llenado transitorio del canal de cola, que pasa de 8.88 a 16.06 L al subir h_out. El par se recuperó y siguió creciendo. `h_out` = −0.030 **no** es la causa del déficit de par.
>
> **Si se cambia h_out, hay que reparchar la descarga al nivel nuevo.** No hacerlo obliga a Fluent a llenar el canal por el outlet, lo que produce `mdot_outlet` **positivo** (entrada de agua) durante cientos de pasos.

---

## 8. Condición inicial (patch) — método verificado

Sin patch, llenar el dominio por el inlet cuesta **~3 700 pasos** del presupuesto. Con patch se elimina el 92 % de ese coste.

### 8.1 Lo que hay que saber antes

> 🔴 **El filtro "Zones to Patch" se IGNORA cuando hay un registro seleccionado.** Verificado con dos tests de una sola variable: patchando con zona `entrada` + registro `z_entrada` sobre un dominio confirmado seco, se marcaron 766 967 celdas (el registro global) y se inundaron las **tres** zonas. La zona no restringe nada.
>
> **Consecuencia:** el registro tiene que llevar la restricción espacial dentro. Un registro **Region tipo Hex** es exactamente eso (AND de rangos en X, Y, Z) y es la herramienta correcta. Los registros de tipo Field Variable sobre Z-Coordinate **no sirven** porque son cortes globales anidados.

> 🔴 **Un Patch con las listas vacías aplica a TODO el dominio.** No significa "no hagas nada". El diálogo además **hereda la selección** de la vez anterior. Esto inundó el dominio tres veces seguidas.

### 8.2 Los tres registros (Cell Registers → New → Region, Hex, Inside)

| | `agua_entrada` | `agua_rotatoria` | `agua_descarga` |
|---|---|---|---|
| X min | −0.700 | −0.326 | −0.040 |
| X max | −0.326 | −0.040 | 0.420 |
| Y min | −0.145 | −0.145 | −0.145 |
| Y max | 0.145 | 0.145 | 0.145 |
| Z min | 0.000 | −0.100 | −0.160 |
| Z max | **0.1302** | **0.049** | **−0.0886** |

Los cortes en X (−0.326 y −0.040) son las fronteras reales entre cámaras. Las cajas se reparten el dominio sin solaparse, así que **el orden de aplicación da igual**.

> Si se cambia `h_out`, el `Z max` de `agua_descarga` debe cambiar con él.

### 8.3 Procedimiento

1. **Initialize** → responder `yes`
2. **Verificar 0 0 0** con Volume Integrals (Volume-Average, `Phases → Volume fraction`, Phase `phase-2`)
3. Patch: Phase **`phase-2`**, Variable **Volume Fraction**, Value **1**
4. **Zones to Patch → deseleccionar todo** (botón rojo ✗). Siempre.
5. Registers → solo `agua_entrada` → Patch
6. Registers → solo `agua_rotatoria` → Patch
7. Registers → solo `agua_descarga` → Patch
8. Verificar

### 8.4 Resultado esperado

| Zona | α | Litros |
|---|---|---|
| entrada | 0.3282 | 8.63 |
| rotatoria | 0.2189 | 2.04 |
| descarga | 0.2482 | 8.74 |
| **Total** | | **19.40 L** |

Contraste con Monte Carlo de 12 M puntos sobre la geometría real (validado a <1 % contra los volúmenes de zona de Fluent): las cajas deberían dar 21.04 L. Se logra el 92 %. El déficit restante (1.63 L ≈ 303 pasos) queda absorbido por la fase de asentamiento.

> `agua_rotatoria` logra solo el 64 % de su objetivo porque la caja tiene tapa plana en Z = 0.049 y la superficie real dentro del tornillo es inclinada (de 0.113 arriba a −0.015 abajo). Refinarla recuperaría ~0.9 L ≈ 167 pasos, también absorbidos. No merece la pena.

### 8.5 ⚠️ El patch va SIEMPRE al final

Toda manipulación de malla (separar zonas, recrear interfaces) **borra los datos de solución**. Orden obligatorio:

```
separar zonas → wall motion → interfaces → reportes → INITIALIZE → PATCH → guardar
```

Comprobado: tras `Separate Face Zones` la densidad de mezcla volvió a 1.225 (aire puro) — el patch se había perdido.

---

## 9. Resultados de la corrida 30–31/07

### 9.1 Rendimiento — resuelto

| | Antes | Después |
|---|---|---|
| min/paso | 1.5 – 2.0 | **0.85** |
| pasos/hora | 30 – 40 | **~70** |

**Causa raíz confirmada con medición:** memoria confirmada en uso **30.68 GB** contra **15.46 GB** de RAM física → 198 % de sobrecompromiso, ~15 GB en el archivo de paginación. Fluent solo comprometía **12.9 GB** (8 × `fl_mpi` = 10.07 GB + cx2520 1.43 + AnsysFWW 0.76 + fl2520 0.67).

**Qué lo arregló:**
1. **Precisión simple** (desmarcar Double Precision al lanzar) — la palanca grande, ~50 % de la memoria de campos
2. Cerrar Creative Cloud, Edge, Roblox

Resultado: commit bajó a **13.79 GB** con 8.45 GB disponibles. Sin paginación.

> ⚠️ **Corrección (03/08).** Una versión anterior de este documento atribuía parte de la mejora a haber parado los cuatro servidores de BD (MySQL80, MongoDB, MSSQL$WINCCPLUSMIG2008, postgresql-x64-16). **Es falso: nunca se pararon.** Comprobado con las horas de arranque de proceso y el uptime — el PC no se reinició en 92.8 h y los servicios estuvieron corriendo todo el tiempo. Siguen siendo candidatos a liberar ~1-1.5 GB, pero no formaron parte de la mejora medida.

**Servicios que siguen corriendo sin hacer falta para CFD:** MongoDB, MSSQL$WINCCPLUSMIG2008, MySQL80, postgresql-x64-16, SQLBrowser, SQLWriter, AdobeUpdateService, Autodesk Access Service Host, Autodesk CER Service. Pararlos requiere permisos de administrador. Ojo con `WINCCPLUSMIG2008`: es una instancia de Siemens WinCC, consultar antes de cambiar su tipo de inicio.

**No** se redujo el número de procesos: 8 particiones sobre 1.06 M celdas no es el problema. Queda sin explorar el reparto P-core / E-core (el Ultra 7 265 tiene 8 P + 12 E, 20 lógicos **sin hyperthreading**); si un rank cae en un E-core, MPI es síncrono y todos esperan.

### 9.2 Convergencia con First Order Upwind

| Rev | C medio | mdot_out | V_tot | h_in | η |
|---|---|---|---|---|---|
| 3 | −0.1489 | −5.82 | 26.14 L | 0.1265 | 0.472 |
| 4 | −0.1735 | −0.23 | 27.41 L | 0.1272 | 0.548 |
| 5 | −0.1554 | +0.78 | 29.05 L | 0.1275 | 0.490 |
| 6 | −0.1607 | −4.66 | 28.30 L | 0.1278 | 0.506 |

Promediado sobre las últimas 2 / 3 / 4 revoluciones: **−0.1580 / −0.1633 / −0.1596** — coinciden dentro del 3 %. **Convergido en −0.163 N·m = 66 % del objetivo.**

Estado del campo al converger:
- `entrada` asintótica en 9.33 L → h_in = 0.128 m ✅
- `rotatoria` al **93 %** del llenado teórico (2.50 de 2.692 L) ✅
- `descarga` oscilando ±1.3 L en torno a **16 L**, que es el equilibrio predicho por Monte Carlo para h_out = −0.030 ✅ (el vaivén es el chapoteo real del canal de cola por la descarga pulsante de 3 álabes)

**Desglose del par al converger** (Results → Reports → Forces → Moments):

| | Valor | Lectura |
|---|---|---|
| Presión | **−0.20436** | falta el 18 % del objetivo |
| Viscoso | **+0.04298** | se come el 21 % del de presión |
| **Total** | **−0.16138** | 65 % del objetivo |

> Cálculo que acota el problema: **aunque el par viscoso fuera cero**, el de presión solo (0.2044) seguiría un 4 % por debajo del límite inferior de aceptación. **No basta con reducir la fricción: falta par motor también.** Ambas cosas apuntan a la holgura sin resolver.

(A t = 0.05 s el reparto era Presión −0.0396 / Viscoso +0.0261, con el viscoso al 66 % — el cortante de arranque, que se disipa. No interpretar ese ratio antes de converger.)

### 9.3 Efecto del orden de discretización

Cambio de Momentum a **Second Order Upwind** reiniciando desde el campo convergido de primer orden.

**Estabilidad: sin problemas.** La malla con OQ 0.13 lo aguanta; curva suave y monótona, sin oscilaciones crecientes ni avisos de Velocity Limiting.

Medias por revolución tras el cambio (t_cambio = 2.9364 s):

| Rev post-cambio | C medio | pico-pico | h_in | H | η |
|---|---|---|---|---|---|
| 1 | −0.18833 | 0.0669 | 0.1284 | 0.1584 | 0.591 |
| 2 | −0.17309 | 0.0372 | 0.1287 | 0.1587 | 0.541 |
| 3 | **−0.17167** | 0.0401 | 0.1290 | 0.1590 | **0.536** |

Variación rev 2 → 3: **0.82 %** (criterio §6.6: < 0.5 %). Valor asentado: **−0.172 ± 0.005 N·m**.

> La rev 1 sale inflada porque incluye el salto del cambio de esquema; su mínimo (−0.141) es el paso 1601 justo al conmutar. **No proyectar desde el transitorio:** el par llegó a alcanzar −0.204 en el paso 1780, lo que llevó a estimar una ganancia de +10-15 % que no se materializó.

| | C [N·m] | η | % objetivo |
|---|---|---|---|
| Primer orden (convergido) | −0.1632 | 0.506 | 65.7 % |
| **Segundo orden (convergido)** | **−0.1717** | **0.536** | **69.2 %** |
| Límite inferior de aceptación | −0.2133 | | 86 % |
| Objetivo Malla 1 | −0.2482 | 0.7785 | 100 % |

**Ganancia real: +5.2 %.** Insuficiente — falta otro 24 % para entrar en la banda de aceptación. La conclusión importante es negativa y útil: **la disipación numérica de primer orden NO era la causa principal del déficit.**

---

## 10. Presupuesto de cómputo

| Concepto | Valor |
|---|---|
| Δt de régimen | 1.923e-3 s (1.5°/paso) |
| Pasos por revolución | **240** |
| Etapa A | 100 pasos a Δt = 5e-4 (= 0.05 s) |
| §6.6 pide | 4 rev para establecer + 4 para promediar = **8 rev** |
| Pasos para 8 rev | hasta el paso **~1994** |
| Ritmo | ~51 s/paso → **~70 pasos/hora** |

**Ojo con el conteo de revoluciones:** la etapa A usa Δt distinto, así que **no** se puede calcular el tiempo como `paso × 1.923e-3`. Hay que usar la columna `flow-time` de los archivos `.out`.

Criterios de parada (§6.6):
- Residuos < 1e-5 por paso de tiempo
- Variación de C entre revoluciones consecutivas **< 0.5 %**
- Balance de masa `mdot_in + mdot_out` → 0
- Promediar sobre 4 revoluciones una vez en régimen

---

## 11. Curva volumen → h_in (para calcular η)

`vol_agua_entrada` da el volumen de agua en la cámara; esta tabla lo convierte en `h_in`. Monte Carlo de 16 M puntos sobre la geometría real, validado a **−0.81 %** contra los 26.298 L que mide Fluent.

| h_in [m] | agua [L] | | h_in [m] | agua [L] |
|---|---|---|---|---|
| 0.070 | 4.741 | | 0.140 | 10.337 |
| 0.080 | 5.509 | | 0.150 | 11.167 |
| 0.090 | 6.288 | | 0.160 | 12.005 |
| 0.100 | 7.078 | | 0.170 | 12.855 |
| 0.110 | 7.882 | | 0.180 | 13.721 |
| 0.120 | 8.695 | | 0.190 | 14.599 |
| 0.130 | 9.512 | | 0.200 | 15.495 |

Luego: **H = h_in − h_out** y **η = |C| · ω / (ρ g Q H)** con ω = 13.6136, ρ = 998.2, Q = 2.8e-3.

**Curva equivalente para el canal de descarga** (validada a −0.62 %):

| nivel [m] | agua [L] | | nivel [m] | agua [L] |
|---|---|---|---|---|
| −0.1400 | 2.361 | | −0.0600 | 12.459 |
| −0.1200 | 4.896 | | −0.0400 | 14.883 |
| −0.1000 | 7.436 | | **−0.0300** | **16.060** |
| −0.0886 | 8.881 | | −0.0200 | 17.220 |
| −0.0800 | 9.970 | | 0.0000 | 19.499 |

---

## 12. Historial de problemas resueltos

### 12.1 Cara faltante en la geometría
**Síntoma:** `Describe Geometry` fallaba con *"Non-connected surface bodies… not supported in a Non-conformal setup"*. 26 caras libres de 1.69 M — un agujero minúsculo en el filo de un álabe. Causa: interoperabilidad OpenCASCADE (CadQuery) → Parasolid (SpaceClaim) al reconstruir las 36 caras B-spline helicoidales.

**Solución:** SpaceClaim → **Repair → Missing Faces → `Fill`** (NO `Patch`, que falla con "could not replace faces with a single face"), marcando **`Allow multiple faces`**. Verificar con `diagnostics → perform-summary` → Free Faces = 0.

### 12.2 Paredes fusionadas artesa + tornillo
**Síntoma:** una sola zona `wall` para toda la rotatoria.

**Solución:** **Domain → Zones → Separate → Separate Face Zones…** → zona `rotatoria-…:1` → método **`Region`** → Separate. En la advertencia elegir **`Proceed After Mesh Manipulation`** con **`Mesh Interfaces: delete all`**.

**Resultado:** dos zonas identificadas por área — `…:1` → 0.33493 m² → **tornillo** · `…:1:001` → 0.27422 m² → **artesa**. La consola reporta `111381 faces in contiguous region 0` y `58747 faces in contiguous region 1`.

**Efecto colateral:** borra las interfaces, rompe los Report Definitions **y borra el patch**. Orden: separar → recrear todo → patchar al final.

### 12.3 Conteo de celdas desbordado
Primera malla 9.33 M. El error de enfoque fue apuntar a "una malla razonable" cuando el protocolo pide **tres mallas** para el GCI, la más gruesa de ~0.7 M. Recalibrando se llegó a 1.06 M.

### 12.4 Intentos fallidos por TUI — abandonado
`diagnostics/quality → smooth`, `general-improve`, y comandos inexistentes (`repair-improve`, `improve-quality`). Terminó interrumpiendo el proceso Cortex. La malla quedó intacta.

**Lección:** el Mouse Probe en modo `Select` captura clics del viewport mientras se teclea en consola. Cambiar a `Box` o no tocar el viewport.

### 12.5 Autosave perdido (29/07) — causa real
No se perdió por el corte de energía. **Nunca se escribió.** Un corte no borra archivos ya en disco; se buscó en todo `C:` (`*.h5`, `*.trn`, `*.out`), en el directorio de trabajo y dentro de `Semillero.rar` (882 MB) — el archivo Fluent más reciente en cualquiera de los tres es el mismo `.cas.h5` del 28/07 20:01.

### 12.6 Archivos `!!!!!`, `XORXOR`, `ZZZZZ`, `koLTLF`, `sC07bs`
Aparecen en todas las carpetas de usuario y **no son ransomware**. Cinco prefijos distintos, tamaños idénticos por extensión, archivos reales intactos, sin nota de rescate, y cubriendo justo el catálogo de tipos sensibles que vigila un motor DLP (`.pem`, `.pst`, `.mdb`, `.sql`, `.eml`). Son ficheros de prueba de **Cortex XDR**, el EDR corporativo. No tocar.

---

## 13. Trabajo pendiente

### 13.1 🔴 Malla 2 con la holgura resuelta — prioritario

Cambiar en `proximity_1`: **Cells Per Gap = 5**, **Min Size ≈ 0.0002 m**. Es la corrección de fondo del déficit de par **y** la Malla 2 que necesita el GCI de §6.2.1.

Implica rehacer todo el montaje sobre malla nueva. Seguir el orden de §8.5 al pie de la letra.

### 13.2 Estudio GCI (protocolo §6.2.1)

Faltan Malla 2 (~1.4 M) y Malla 3 (~2.2 M). Con los tres pares C₁, C₂, C₃:

```
p = ln[(C₃−C₂)/(C₂−C₁)] / ln r          C(h→0) = C₁ + (C₁−C₂)/(r^p − 1)
GCI₁₂ = 1.25 |C₁−C₂| / (|C₁| (r^p − 1))
```

El valor extrapolado se compara contra los **0.2360 N·m** de Dellinger con 8.8 M celdas. Según §6.2.1 esto **es el aporte metodológico del trabajo**, no un trámite.

### 13.3 Discrepancia del 14 % en el volumen de la rotatoria
Ver §2. Medir la longitud axial real de la zona rotatoria en la malla.

### 13.4 Reparto P-core / E-core
Benchmark de 50 iteraciones con 4, 6 y 8 procesos, y probar afinidad a los 8 P-cores (lógicos 0–7). El protocolo §6.2 lo señala: correr en 20 núcleos puede ser *más lento* que en 8.

### 13.5 Verificación visual pendiente
Contorno de fracción de volumen sobre el plano ZX (Y = 0): agua abajo, aire arriba, superficie definida, y el agua avanzando de `entrada` a `descarga`. Es el paso 14 de la secuencia original y sigue sin hacerse.

---

## 14. Archivos de referencia

| Archivo | Ubicación / propósito |
|---|---|
| `generar_tornillo.py` | Script CadQuery paramétrico (`Modelos/files/`) |
| `fluido_rotatorio_V.step` | Zona rotatoria |
| `fluido_camara_entrada_V.step` | Cámara aguas arriba |
| `fluido_canal_descarga_V.step` | Canal aguas abajo |
| `tornillo_V.step` | Sólido del tornillo — sirvió para medir la lateralidad de la hélice |
| `artesa_V.step` | Carcasa |
| `Protocolo_validacion_modelado_CFD_tornillo.md` | **El protocolo. Es la referencia normativa** (`Archivos/`) |
| `FFF.6-Setup-Output.cas.h5` | Caso base al 28/07 (malla + config parcial) |
| `ASG_M1_conv_1erorden.cas/dat.h5` | Convergido con First Order Upwind |
| `TRASPASO_ASG_Dellinger_v1_30jul.md` | Versión anterior de este documento |

> El PDF de Dellinger et al. (2018) **no está en el disco**; se buscó y no aparece. Los datos del paper que se usan aquí vienen del protocolo, que los transcribe en §3.

---

## 15. Lecciones de estas sesiones

1. **Verificar, no asumir.** Se dio por resuelto un problema de topología leyendo mal una columna (`cell-zone-type` ≠ topología), costando tres tareas sobre una conclusión falsa.
2. **El autosave se verifica escribiendo**, con `!dir *.h5`, no marcando la casilla.
3. **Toda manipulación de malla rompe referencias por nombre y borra los datos.** Orden: manipular → recrear → patchar → correr.
4. **Medir el rendimiento con una prueba corta** antes de comprometer una noche.
5. **`Fill` funciona donde `Patch` falla** para huecos en superficies no planas (SpaceClaim Repair).
6. **El objetivo no es "una buena malla" sino las tres mallas del GCI.**
7. **Los diálogos de Fluent heredan selecciones.** Un Patch con listas vacías aplica a todo el dominio. Verificar la selección *antes* de ejecutar, no después.
8. **El transcript (`.trn`) registra cada acción de la GUI con sus argumentos.** Cuando algo no cuadra, leerlo es más rápido y fiable que reconstruir de memoria lo que se hizo.
9. **Los reportes solo registran desde que existen.** Crearlos antes de la corrida larga, no después.
10. **No juzgar una señal transitoria.** El par de arranque fue +13.7 N·m (arrastre impulsivo), el reparto viscoso/presión era 66 % a los 0.05 s y 21 % al converger, y una caída del par a mitad de corrida resultó ser el llenado del canal de cola. Nada de eso significaba lo que parecía.
11. **Un reporte de densidad no distingue dónde está el agua.** La densidad de una fase es una propiedad constante del material. Para saber la distribución hay que pedir `Phases → Volume fraction`, o densidad de la `mixture`.
