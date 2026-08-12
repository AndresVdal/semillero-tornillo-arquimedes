# Modelo V — tornillo de validación (Dellinger et al. 2018)
## Guía de arranque

---

## 1. Qué hay en esta carpeta

| Archivo | Qué es | Para qué |
|---|---|---|
| `fluido_rotatorio_V.step` | Fluido dentro de la artesa, ya restado el tornillo | **Zona rotatoria** (Mesh Motion) |
| `fluido_camara_entrada_V.step` | Cámara de entrada, aguas arriba | Zona fija |
| `fluido_canal_descarga_V.step` | Canal de descarga, aguas abajo | Zona fija; aquí va `outlet` |
| `dominio_completo_V.step` | Los tres cuerpos unidos | Comprobación visual |
| `tornillo_V.step` | Sólido del tornillo (núcleo + 3 álabes) | Referencia / SolidWorks |
| `artesa_V.step` | Artesa cilíndrica, radio interior 97 mm | Referencia / fabricación |
| `tornillo_V.stl` | Malla superficial fina | Respaldo (Dellinger usó .stl) |
| `generar_tornillo.py` | Script paramétrico + estimador de celdas y RAM | Regenerar y pasar al Modelo P |
| `vista_previa_dominio_V.png` | Render del dominio completo | Comparar visualmente |
| `vista_previa_tornillo_V.png` | Render del tornillo | Comparar visualmente |

**Los tres cuerpos de fluido ya están recortados para acoplarse exactamente:** solo se tocan, no se solapan (verificado: solape = 0.0001 L, ruido numérico) y forman un único sólido conectado de 69.32 L. No hay que construir cajas a mano.

| Cuerpo | Volumen |
|---|---|
| Zona rotatoria (dentro de la artesa) | 8.244 L |
| Cámara de entrada | 26.086 L |
| Canal de descarga | 34.990 L |
| **Total** | **69.320 L** |

Extensión total del dominio: 1086 × 280 × 470 mm.

Unidades: **milímetros**. Al importar a ANSYS, confirmar que lee mm.

---

## 2. Geometría construida

| Parámetro | Valor | Fuente |
|---|---|---|
| Radio exterior R_a | 96.0 mm | Dellinger Tabla 1 |
| Radio interior R_i | 52.0 mm | Dellinger Tabla 1 |
| Paso S | 192.0 mm | Dellinger Tabla 1 |
| Longitud roscada L_B | 400.0 mm | Dellinger Tabla 1 |
| Entradas N | 3 | Dellinger Tabla 1 |
| Holgura s_sp | 1.0 mm | Dellinger (valor máximo medido) |
| Inclinación β | 24° | Dellinger, caso CFD |
| Espesor de álabe | 2.0 mm (axial) | Adoptado; el paper no lo especifica |
| Prolongación del núcleo | 25 mm por lado | Adoptado, para los apoyos |

### Verificación numérica ya hecha

| Comprobación | Resultado |
|---|---|
| Radio exterior en 6 estaciones axiales | 96.0000 mm — desviación **0 µm** |
| Holgura álabe–artesa | 1.0000 mm uniforme |
| Bounding box | 192.000 × 192.000 × 450.000 mm ✔ |
| Resta booleana fluido < cilindro | ✔ (8.244 L < 11.824 L) |
| Vueltas roscadas | 2.083 = 400/192 ✔ |
| Volumen libre por paso | 3.957 L |
| **Q_nom a 70 rpm (f = 0.5)** | **2.31 L/s** vs. **2.32 L/s** reportado por Dellinger |

El último punto confirma que el sólido reproduce la capacidad de trago del tornillo de referencia. Si el paso, el número de entradas o el barrido estuvieran mal, ese volumen no cuadraría.

> Nota honesta: el factor de llenado f = 0.5 se calibró contra estos mismos datos, así que la coincidencia verifica la **geometría del CAD**, no es una validación independiente del método. La validación real es la de la Fase 1 (par y eficiencia).

---

## 3. Ruta recomendada — importar el STEP (30 min hasta tener malla)

Es la más rápida y la geometría ya está verificada.

1. **ANSYS Workbench** → nuevo sistema **Fluid Flow (Fluent with Fluent Meshing)**.
2. **Geometry → Import Geometry** → importar los **tres** STEP de fluido. Abrir en **SpaceClaim**.
3. Seleccionar los tres cuerpos → **Share Topology = Share**.
4. Nombrar las caras (*Named Selections*): `inlet`, `outlet`, `techo`, `pared_artesa`, `pared_tornillo`, `simetria_lateral`.
5. **Fluent Meshing → Watertight Geometry** con la receta de §6.
6. **Fluent Solution** → configuración del protocolo, §6 del documento principal.

> El tornillo **no** se importa como sólido: ya está restado del fluido. Sus paredes son las caras internas de `fluido_rotatorio_V.step`.

> Si van a usar SolidWorks como entregable del proyecto, abrir `tornillo_V.step` en SolidWorks y guardar como `.SLDPRT` toma 30 segundos. Queda un sólido sin árbol de operaciones — sirve para CFD, pero no como "diseño paramétrico". Para eso, la ruta de §4.

---

## 4. Ruta paramétrica en SolidWorks (≈15 min)

El objetivo específico 3 del proyecto pide archivos paramétricos de SolidWorks, así que conviene tener también esta versión. Ustedes ya saben hacer la hélice (se ve en la captura del `Hélice/Espiral2`), así que van los números exactos y los dos puntos donde suele fallar.

**Paso 1 — Núcleo**
Croquis en el plano *Alzado*: círculo Ø104 mm centrado en el origen.
`Saliente extruido` → **Dos direcciones**: 400 mm + 25 mm, y 25 mm hacia atrás. Total 450 mm.

**Paso 2 — Hélice**
Croquis nuevo en el mismo plano: círculo Ø192 mm (es solo la guía de la hélice).
`Curvas → Hélice/Espiral`
- Definido por: **Paso y revolución**
- Paso = **192 mm**
- Revoluciones = **2.0833** (= 400/192)
- Ángulo inicial = 0°
- Sentido: horario (o antihorario — solo define hacia qué lado gira; anotarlo)

**Paso 3 — Perfil del álabe**
Croquis en el plano *Vista lateral* (el que **contiene el eje**, no el perpendicular).
Una línea recta **radial**: de r = 52 mm a r = 96 mm, colineal con el eje de la hélice.
El extremo de la línea debe estar **coincidente con el punto inicial de la hélice** (relación de coincidencia).

**Paso 4 — Barrido — aquí es donde falla**
`Saliente/Base barrido`
- Perfil: la línea del paso 3
- Trayectoria: la hélice
- **Opciones → Orientación/tipo de torsión = "Seguir trayectoria"**
- **Vector de dirección = el eje del núcleo** ← *esto es lo crítico*
- `Dar espesor` = **2 mm**, tipo dos direcciones (1 mm a cada lado)

Sin fijar el vector de dirección al eje, el perfil se retuerce y el borde exterior deja de estar a radio constante. Eso es probablemente lo que se ve en su Imagen 4 (bordes festoneados).

**Paso 5 — Las 3 entradas**
`Matriz circular` alrededor del eje del núcleo, **3 instancias, 360°, espaciado igual**.

**Paso 6 — Artesa** (pieza aparte, en un ensamblaje)
Croquis: círculo Ø194 mm y círculo Ø206 mm concéntricos. Extruir 400 mm.
El Ø194 = 2 × (96 + 1) → holgura de 1 mm.

**Paso 7 — Ensamblaje**
Insertar tornillo y artesa coaxiales. Inclinar el conjunto **24°**.

### Verificación obligatoria antes de exportar

- [ ] `Insertar → Vista de sección` con plano **perpendicular al eje** en 5 estaciones (z = 20, 100, 200, 300, 380 mm). Medir el radio del borde del álabe: debe ser **96.00 mm en todas**.
- [ ] `Herramientas → Evaluar → Detección de interferencias` entre tornillo y artesa → **0 interferencias**.
- [ ] `Herramientas → Medir` entre borde de álabe y cara interior de artesa → **1.00 mm**.
- [ ] `Herramientas → Propiedades físicas` del tornillo: volumen ≈ **4.005 L** (4 005 000 mm³). Si difiere más de 5 %, el barrido o el espesor están mal.

Ese último chequeo es el más rápido y el que más errores atrapa.

---

## 5. Mallado — receta de Fluent Meshing (16 GB)

El dominio ya viene dimensionado para caber en 16 GB: ancho de canal 280 mm (≈ 3·R_a, más angosto que el real, igual que hizo Dellinger para ahorrar celdas — es legítimo **si se declara** en el informe).

**Flujo: Watertight Geometry.**

| Paso | Ajuste |
|---|---|
| Import Geometry | los tres STEP, unidades **mm** |
| Add Local Sizing → *body of influence* en la holgura | **0.2 mm** |
| Generate Surface Mesh | mín. 0.5 mm, máx. 8 mm; **álabes y artesa 1.5 mm**; núcleo 2.5 mm |
| Describe Geometry | *The geometry consists of only fluid regions without voids* |
| Update Boundaries | `inlet`, `outlet` → tipos correctos; `techo` → pressure-outlet |
| Add Boundary Layers | **5 capas**, *last-ratio*, transition ratio 0.272 |
| Generate Volume Mesh | **poly-hexcore**, max cell length 6 mm |

**Presupuesto estimado** (lo imprime el script):

| Región | Celdas |
|---|---|
| Prismáticas (251 k caras × 5) | 1.26 M |
| Holgura álabe–artesa | 0.54 M |
| Hexcore dentro de la artesa | 0.26 M |
| Cámaras | 0.13 M |
| **Total** | **≈ 2.2 M → ≈ 4.4 GB** |
| Techo con 16 GB | ≈ 6 M celdas |

Es una estimación de orden de magnitud; en la práctica suele salir entre 2 y 4 M. Aun así hay margen.

**Ojo con el mallado:** consume más memoria que resolver. Si Fluent Meshing se cae, ese es el motivo — no el solver.

**Núcleos.** El Ultra 7 265 es híbrido (8 P + 12 E). Fluent espera a la partición más lenta, así que los E-cores frenan al conjunto. Correr un benchmark de 50 iteraciones con 4, 6 y 8 núcleos y quedarse con el mejor. Referencia: 50 000–100 000 celdas por núcleo.

**Si no cabe**, en orden: bajar de 5 a 3 capas prismáticas → subir el tamaño del núcleo a 4 mm y el de las cajas a 12 mm → acortar el canal de descarga. **Nunca agrandar la holgura modelada:** la fuga es un mecanismo de pérdida de primer orden y alterarla cambia la física.

---

## 6. Datos exactos para Fluent

Ya calculados — no hace falta volver a medirlos con la herramienta Measure. Esto elimina la corrección por brazo de palanca que tanto trabajo dio en Flow Simulation.

```
Eje de rotación, dirección (unitario) : (0.913545, 0.000000, -0.406737)
Eje de rotación, punto de origen [m]  : (0.000000, 0.000000, 0.000000)
Extremo aguas arriba (alto)      [m]  : (-0.365418, 0.000000, 0.162695)
Extremo aguas abajo  (bajo)      [m]  : (0.000000, 0.000000, 0.000000)
Desnivel entre extremos          [m]  : 0.1627
Salto por vuelta (S·sin β)       [m]  : 0.0781
Gravedad                              : (0, 0, -9.81) m/s²
```

Usar el **mismo eje y el mismo origen** en:
- `Cell Zone Conditions → Mesh Motion` (zona rotatoria)
- `Report Definitions → Moment` (par sobre el tornillo)

Si ambos no coinciden exactamente, el par sale mal.

### Recordatorios críticos del montaje

1. **Mesh Motion (malla deslizante), NO Frame Motion (MRF).** Transitorio.
2. **La artesa está dentro de la zona rotatoria pero es fija:** su pared va como `Moving Wall → Absolute → Rotational, ω = 0`. Es el equivalente en Fluent del `rotatingWallVelocity` de Dellinger.
3. **Malla en la holgura: ≥ 5 celdas** a través de 1 mm → celda de **0.20 mm** ahí.
4. **Δt ≤ 1° de giro por paso**: a 70 rpm → 2.38 ms; a 130 rpm → 1.28 ms.
5. **Promediar sobre 4 revoluciones** tras alcanzar régimen.

### Primeros casos a correr

Punto ancla de la validación: **Q = 2.8 L/s, n = 130 rpm, β = 24°**

Correrlo en **tres mallas** y extrapolar, en lugar de una sola:

| Nivel | Celdas | Referencia de Dellinger |
|---|---|---|
| Gruesa | ≈ 0.7 M | — |
| Media | ≈ 1.4 M | 0.2482 N·m (él, a 1.4 M) |
| Fina | ≈ 2.2 M | 0.2423 N·m (él, a 2.4 M) |
| **Extrapolado (Richardson)** | h → 0 | **comparar contra 0.2360 N·m (8.8 M)** |

Como no se llega a los 5 M de Dellinger, la extrapolación de Richardson con su GCI es la forma correcta de cerrar la validación — y es metodológicamente **más fuerte** que correr una sola malla fina, porque cuantifica la incertidumbre numérica en vez de suponerla. Las fórmulas están en §6.2.1 del protocolo.

Tolerancia: el valor extrapolado debe caer dentro del GCI respecto a 0.2360 N·m.

**Cronometrar la primera corrida.** A 2 M celdas y 8 núcleos, con Δt de 2°/paso y 8 revoluciones (≈1400 pasos), calcular entre medio día y dos días por caso. Con ese dato real se recalibra la matriz completa antes de comprometerse con un plan.

---

## 7. Pasar al Modelo P

Cuando tengan los aforos, editar el bloque `P = dict(...)` al inicio de `generar_tornillo.py` y volver a ejecutarlo:

```python
P = dict(
    nombre   = "P",
    Ra       = 225.0,   # ← de la tabla de dimensionamiento, según Q medido
    Ri       = 118.0,   # ← ρ = Ri/Ra debe quedar entre 0.50 y 0.54
    S        = 450.0,   # ← S/D entre 1.00 y 1.15
    LB       = 1183.0,  # ← L = H / sin(β), con el H medido
    N        = 3,
    t        = 4.0,
    gap      = 3.0,     # ← 0.0045·√D en metros
    e_artesa = 8.0,
    ext      = 60.0,
    beta     = 25.0,
)
```

El script vuelve a imprimir todas las verificaciones y los datos de eje para Fluent. Ejecutar con:

```bash
pip install cadquery
python generar_tornillo.py
```

**Advertencia:** no dimensionar el Modelo P antes de tener Q y H medidos en campo. Ese fue el origen del problema anterior.
