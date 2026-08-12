# Protocolo de validación, modelado CAD y simulación CFD
## Turbina de tornillo de Arquímedes — Semillero SIIM, UPB Bucaramanga

> Documento de trabajo. Reemplaza la metodología de `simulacion_solid_y_ansys_v3.docx`.
> Julio 2026.

---

## 0. Resumen del diagnóstico

El docente tiene razón, y por una razón más profunda que la falta de validación. Hay tres problemas encadenados:

| # | Problema | Consecuencia |
|---|---|---|
| **A** | La turbina se simuló como **máquina hidrocinética** (corriente libre de 3.3 m/s, sin artesa, sin salto) cuando el tornillo de Arquímedes es una **máquina hidrostática de gravedad** | Toda la física del modelo es la equivocada. Por eso el docente insiste en el **salto** y no entiende el barrido de **ω** |
| **B** | El caudal de diseño (3 m³/s) es **~150 veces mayor** que el que el tornillo dibujado puede tragar (≈0.020–0.030 m³/s) | Los 180 W reportados implican η ≈ 180 % → físicamente imposible |
| **C** | No hay validación contra un caso verificado | Sin ella no hay forma de saber si el montaje numérico es correcto |

Los tres se resuelven con el mismo plan: **validar primero contra Dellinger et al. (2018)** —que ya está en la carpeta del proyecto—, **corregir la geometría**, y **rehacer el barrido cambiando el salto, no la velocidad de giro**.

---

## 1. El problema de fondo: hidrostática, no hidrocinética

### 1.1 Cómo funciona realmente un tornillo de Arquímedes

Un *Archimedes Screw Generator* (ASG) **no extrae energía cinética del agua**. Extrae **energía potencial**: el agua queda atrapada en cangilones (*buckets*) formados entre dos álabes consecutivos, la pared del núcleo y **la artesa (canaleta) que envuelve el tornillo**. El peso del agua atrapada empuja los álabes y genera par. El agua baja; el tornillo gira.

La ecuación de gobierno es, literalmente, la de una máquina de gravedad:

$$P_{hid} = \rho\, g\, Q\, H \qquad\qquad \eta = \frac{P_{mec}}{\rho g Q H} = \frac{C_{eje}\,\omega}{\rho g Q H}$$

donde **H es el salto geodésico** (diferencia de nivel de agua entre aguas arriba y aguas abajo). Esto es exactamente lo que dice Dellinger et al. (2018), sección 2, y es la definición estándar en toda la literatura de ASG.

### 1.2 Qué se simuló en cambio

En el montaje actual:

- No existe **artesa**. La "región rotatoria" es un cilindro de fluido Ø470 mm alrededor de un tornillo Ø450 mm — una holgura **de fluido**, no una pared. Sin pared envolvente **no hay cangilones**, el agua se sale por los lados y no hay columna hidrostática.
- No existe **salto**. Entrada y salida se definieron con el mismo nivel de superficie libre (z = 0.175 m arriba y abajo). Con H = 0, la potencia hidráulica disponible es **cero**.
- La energía se inyectó como **velocidad de corriente (3.3 m/s)**, es decir, como energía cinética. El modelo es el de una hélice de río, no el de un ASG.
- Se usó **MRF (Frame Motion)**. MRF promedia el marco rotante y supone que el flujo es cuasi-estacionario en ese marco. En un tornillo, los cangilones **se llenan y se vacían** a lo largo de la máquina: el flujo nunca es estacionario en el marco rotante. MRF es inaplicable aquí.

**Conclusión:** el modelo describe un objeto helicoidal arrastrado por una corriente. No describe la turbina del proyecto. Ese es el sentido técnico de "impertinente".

### 1.3 Lo que esto explica

- **Por qué el docente insiste en el salto:** porque *H* es la variable que aporta la energía. Sin ella no hay máquina.
- **Por qué no entendió el barrido de ω:** porque en el montaje hidrocinético, ω era un sustituto del *tip-speed ratio* de una turbina eólica — un concepto que no aplica a un ASG (§8 explica cuál es el papel legítimo de ω).

---

## 2. Chequeos de coherencia que reprueban el resultado actual

Estos cálculos son rápidos y conviene incluirlos en el informe: demuestran que la revisión fue propia, no solo una observación del docente.

### 2.1 Capacidad de trago del tornillo dibujado

Caudal nominal de un ASG: $Q_{nom} = f \cdot \frac{\pi}{4}(D^2 - d^2)\, S\, \frac{n}{60}$, con *f* ≈ 0.5 (fracción de llenado del anillo).

*Calibración de f contra la literatura del proyecto:* Dellinger (D=0.192, d=0.104, S=0.192, Q_nom=2.32 L/s a 70 rpm) → **f = 0.506**. Rohmer (D=0.84, d=0.42, S=0.96, Q=0.15 m³/s) → **f = 0.402**. Se adopta **f = 0.50 ± 20 %**.

Para el tornillo dibujado (D = 0.45 m, d = 0.15 m, S = 0.30 m):

| n [rpm] | Q_nom |
|---|---|
| 57.3 (= 6 rad/s) | **20.3 L/s** = 0.0203 m³/s |
| 85.1 (= n_max) | **30.1 L/s** = 0.0301 m³/s |

**El proyecto asume Q = 3 m³/s → factor 148× de exceso.** Coincide con lo que dice el propio documento de diseño del proyecto: para 3 m³/s el catálogo Landustrie pide un tornillo de **2.8–3.2 m de diámetro**, no de 0.45 m.

### 2.2 Balance de energía

Con Q = 0.0203 m³/s (lo que el tornillo realmente traga) y H = 0.5 m:

$$P_{hid} = 1000 \times 9.81 \times 0.0203 \times 0.5 = \mathbf{99\ W}$$

Con η = 0.75 → **75 W mecánicos como cota superior absoluta.**

El CFD reportó **180 W**. Eso implica **η ≈ 181 %**. Ninguna máquina puede entregar más de la potencia disponible. Este único cálculo, de tres líneas, invalida el resultado — y es exactamente el tipo de verificación de coherencia que el informe ya reclama en su §IV pero no aplicó al resultado final.

### 2.3 Velocidad de giro máxima

Regla de Muysken/Nagel, verificada contra el catálogo Landustrie del proyecto:

$$n_{max} \approx \frac{50}{D^{2/3}} \ \text{[rpm, D en m]}$$

- D = 0.45 m → 85 rpm ✔ (los 57 rpm usados están dentro del rango)
- D = 2.80 m → **24 rpm**, y el catálogo Landy indica **26 rpm** para D = 2800 mm → la regla es confiable.

### 2.4 Relaciones geométricas del tornillo dibujado

| Parámetro | Valor actual | Literatura | Estado |
|---|---|---|---|
| ρ = d/D (núcleo/exterior) | **0.333** | 0.50 (Rohmer) – 0.542 (Dellinger); óptimo de Rorres ≈ 0.54 | ✗ núcleo demasiado delgado |
| S/D (paso/diámetro) | **0.667** | 1.00 (Dellinger) – 1.14 (Rohmer) | ✗ paso demasiado corto |
| β (inclinación) | 25° | 20–32° | ✔ |
| Artesa | **ausente** | imprescindible | ✗ |
| Holgura s_sp | n/a | ≈ 3.0 mm para D=0.45 | ✗ definir |

Un núcleo demasiado delgado hace que el agua rebose por encima del núcleo antes de que el cangilón esté lleno (*over-filling*), y un paso corto reduce el volumen por vuelta. Ambos bajan la eficiencia.

---

## 3. Caso de validación: Dellinger et al. (2018)

**Referencia:** G. Dellinger, P.-A. Garambois, N. Dellinger, M. Dufresne, A. Terfous, J. Vazquez, A. Ghenaim, *"Computational fluid dynamics modeling for the design of Archimedes Screw Generator"*, Renewable Energy 118 (2018) 847–857. **Ya está en la carpeta del proyecto.**

Es el caso de validación ideal porque: (1) es CFD de un ASG con superficie libre; (2) usa **exactamente el modelo de turbulencia que ustedes usan (k-ω SST)** y VOF; (3) tiene datos experimentales del mismo banco; (4) publica **la tabla de sensibilidad de malla**, lo que permite saber de antemano qué error esperar con una malla gruesa.

### 3.1 Geometría del tornillo de referencia (Tabla 1 del paper)

| Parámetro | Símbolo | Valor |
|---|---|---|
| Radio exterior | R_a | **0.096 m** (D = 192 mm) |
| Radio interior (núcleo) | R_i | **0.052 m** (d = 104 mm) |
| Paso | S | **0.192 m** |
| Longitud roscada | L_B | **0.400 m** |
| Número de álabes (entradas) | N | **3** |
| Holgura álabe–artesa | s_sp | **0.001 m** (constante; el valor medido varía 0.0006–0.001 m, usan el máximo) |
| Inclinación (para el CFD) | β | **24°** |

Relaciones: ρ = 0.542, S/D = 1.00, vueltas = 400/192 = 2.08.

### 3.2 Condiciones de flujo (Tabla 4 del paper)

| Campaña | Q | Q_nom | n | n_nom | β |
|---|---|---|---|---|---|
| **Velocidad variable** | 2.8 L/s | — | **70 … 145 rpm** | 84.56 rpm | 24° |
| **Caudal variable** | **1.0 … 2.8 L/s** | 2.32 L/s | 70 rpm | — | 24° |

Nivel aguas abajo: siempre en el **óptimo** (Dellinger demostró que h_out influye directamente en η).

### 3.3 Objetivos numéricos a reproducir

**Punto ancla (Q = 2.8 L/s, n = 130 rpm, β = 24°)** — tabla de sensibilidad de malla del paper:

| Malla | N.º celdas | C_screw [N·m] | η |
|---|---|---|---|
| 1 | 1 400 000 | 0.2482 | 0.7785 |
| 2 | 2 400 000 | 0.2423 | 0.7600 |
| 3 | **5 000 000** | **0.2370** | **0.7434** |
| 4 | 8 800 000 | 0.2360 | 0.7387 |

> **Nota clave para la licencia Student:** entre 1.4 M y 8.8 M celdas el par solo cambia un **5 %**. Es decir: con una malla al alcance de la licencia estudiantil se puede reproducir el *benchmark* dentro de ~5–8 %. Esto convierte la limitación de licencia de excusa en un resultado documentado.

**Tendencias que también deben reproducirse (son parte de la validación):**

1. El par **disminuye** al aumentar n para Q fijo (el llenado del tornillo baja).
2. La eficiencia tiene un **máximo cercano al 80 %** (numérico y experimental coinciden dentro de ~1 %).
3. Para n/n_nom **bajo** la eficiencia cae por **rebose sobre el núcleo** (*over-filling*).
4. Para n/n_nom **alto** la eficiencia cae por **fricción**.
5. El par **aumenta** con Q/Q_nom.

### 3.4 Criterio de aceptación de la validación

| Magnitud | Tolerancia propuesta |
|---|---|
| Par C_screw en el punto ancla | **≤ 10 %** respecto a 0.2370 N·m |
| η máxima | **≤ 8 puntos porcentuales** respecto a 0.80 |
| Posición de η_max en n/n_nom | dentro de **±15 %** |
| Forma de la curva η vs n/n_nom | debe reproducir el máximo y ambas caídas |

Si se cumple → el montaje numérico queda validado y se puede pasar al caso del proyecto con credibilidad.
Si no se cumple → el problema está en el montaje, y se corrige **antes** de simular el caso real. Ese es exactamente el orden que pide el docente.

### 3.5 Caso de validación secundario (escala real, opcional)

Rohmer et al. (2016), *Renewable Energy* 94, 136–146 — también en la carpeta. Prototipo INSA Estrasburgo:

| Parámetro | Valor |
|---|---|
| Radio exterior OR | 0.42 m (D = 0.84 m) |
| Radio interior IR | 0.21 m (ρ = 0.50) |
| Paso P | 0.96 m (S/D = 1.14) |
| N | 3 |
| β | 30° (ajustable 20–32°) |
| Q de diseño | **0.15 m³/s** (rango medido 35–190 L/s) |
| Par entregado | **≈ 250 N·m** |

Útil como segundo punto porque está a una escala parecida a la del proyecto y demuestra el escalado. **Dato importante para §7:** Rohmer indica que el rango típico de aplicación de los ASG es **H = 1 a 6.5 m** con Q = 0.25 a 6.5 m³/s. El salto de diseño del proyecto (0.5–1.0 m) está **en el límite inferior o por debajo** del rango validado de la tecnología.

---

## 4. Revisión del modelo CAD actual (según las capturas)

Lo que se alcanza a verificar en las imágenes:

| Elemento | Observación | Acción |
|---|---|---|
| Núcleo Ø0.15 m × 1.00 m (Imagen 1) | El informe dice L = 1178 mm. Con β = 25°, L = H/sin β → 1.178 m ⇔ H = 0.50 m; pero L = 1.00 m ⇔ **H = 0.42 m** | Definir H primero y derivar L. **No al revés** |
| Hélice paso 0.30 m (Imagen 2) | S/D = 0.667, por debajo del rango 1.0–1.15 | Rediseñar (§5.2) |
| Perfil de álabe 0.15 m radial (Imagen 3) | R_a = 0.075 + 0.15 = 0.225 m ✔ consistente con Ø450 | OK, pero ρ = 0.333 es bajo |
| Barrido helicoidal (Imagen 4) | Los bordes exteriores se ven **apuntados/festoneados**, no a radio constante. Puede ser el render o un barrido mal alineado | **Verificar con corte perpendicular al eje**: el borde debe estar exactamente a R_a en toda la longitud |
| Artesa / canaleta | **No existe en el modelo** | Es el componente que crea los cangilones. Sin él no hay ASG |
| Cámara de entrada y descarga | No existen | Necesarias para imponer y medir h_in y h_out |

**Comprobación obligatoria del helicoide:** insertar un *Corte de sección* con un plano perpendicular al eje y medir el radio del borde del álabe en 5 posiciones a lo largo de L. Si varía, el barrido está mal (típicamente por usar "Seguir trayectoria" en vez de mantener el perfil radial). Debe ser constante = R_a.

---

## 5. Protocolo de modelado en SolidWorks

Se construyen **dos modelos**. El V es pequeño, rápido y no negociable: es el que valida el método.

### 5.1 Modelo V — tornillo de validación (geometría de Dellinger)

**Piezas:**

1. **Núcleo:** cilindro Ø104 mm × 400 mm (+ 20 mm de extensión a cada lado para los apoyos).
2. **Hélice:**
   - `Curvas → Hélice/Espiral`, definida por **Paso y revolución**: paso = 192 mm, revoluciones = 400/192 = **2.083**, diámetro = 192 mm, sentido horario, ángulo inicial 0°.
   - Croquis del perfil en un plano **que contenga el eje**: una línea radial recta de R_i = 52 mm a R_a = 96 mm.
   - `Barrido saliente` con la hélice como trayectoria, opción **"Perfil sólido"** desactivada / **"Dar espesor"** = 2 mm, y orientación **"Seguir trayectoria"** con el eje como vector de dirección fija (evita el retorcimiento del perfil).
   - `Matriz circular` alrededor del eje, **3 instancias a 120°** → las 3 entradas (N = 3).
3. **Artesa:** cilindro hueco de radio interior **R_a + s_sp = 97 mm** (s_sp = 1 mm), longitud 400 mm, coaxial. Modelarla como **superficie** o como sólido con espesor; lo que importa para CFD es la cara interior.
4. **Cámara de entrada** (aguas arriba) con vertedero, y **canal de descarga** (aguas abajo). Dellinger redujo el ancho y la profundidad del canal para ahorrar celdas — hagan lo mismo: solo lo necesario para que el nivel se establezca.
5. **Ensamblaje** con el conjunto inclinado **β = 24°**.

**Comprobaciones antes de exportar:**
- [ ] Radio del borde del álabe constante = 96.000 mm (corte de sección en 5 estaciones)
- [ ] Holgura uniforme de 1.000 mm entre borde de álabe y artesa
- [ ] Sin interferencias (`Herramientas → Detección de interferencias`)
- [ ] Sin caras coincidentes tornillo/artesa

### 5.2 Modelo P — tornillo del proyecto (rediseñado)

**No se puede modelar hasta fijar Q y H reales del sitio.** Ese es el orden correcto. Mientras tanto, aquí está la tabla de dimensionamiento (ρ = 0.5, S = D, N = 3, f = 0.5, η = 0.75):

| D [m] | d [m] | S [m] | n_max [rpm] | Q_nom [m³/s] | P @ H=0.5 m | P @ H=1 m | P @ H=2 m |
|---|---|---|---|---|---|---|---|
| 0.30 | 0.15 | 0.30 | 111.6 | 0.015 | 54 W | 109 W | 218 W |
| **0.45** | 0.23 | 0.45 | 85.1 | **0.038** | **140 W** | **280 W** | 560 W |
| 0.60 | 0.30 | 0.60 | 70.3 | 0.075 | 274 W | 548 W | 1.1 kW |
| 0.80 | 0.40 | 0.80 | 58.0 | 0.146 | 536 W | 1.07 kW | 2.1 kW |
| 1.00 | 0.50 | 1.00 | 50.0 | 0.245 | 903 W | 1.81 kW | 3.6 kW |
| 1.50 | 0.75 | 1.50 | 38.2 | 0.632 | 2.3 kW | 4.7 kW | 9.3 kW |
| 2.00 | 1.00 | 2.00 | 31.5 | 1.237 | 4.6 kW | 9.1 kW | 18.2 kW |
| 3.00 | 1.50 | 3.00 | 24.0 | 3.186 | 11.7 kW | 23.4 kW | 46.9 kW |

Cómo usarla:
1. Medir **Q** en la quebrada (aforo). Entrar por la columna Q_nom → sale **D**.
2. Medir **H** disponible. Entrar por las columnas de potencia → verificar que alcanza para la demanda.
3. Fijar **β** (22–30°; 25° es buen compromiso) → **L = H / sin β**.
4. Verificar que L sea constructivamente razonable (a 25°, H = 1 m ⇒ L = 2.37 m).

**Reglas de diseño a respetar en el Modelo P:**

| Parámetro | Regla | Fuente |
|---|---|---|
| ρ = d/D | **0.50 – 0.54** | Rorres (2000); Dellinger 0.542; Rohmer 0.50 |
| S/D | **1.0 – 1.15** | Dellinger 1.00; Rohmer 1.14 |
| N (entradas) | **3** | Ambos papers |
| β | **22° – 30°** | Rango experimental Rohmer/Dellinger |
| L | **H / sin β** | Geometría |
| Salto por vuelta | S · sin β | Determina cuántos cangilones caben en H |
| Holgura s_sp | **≈ 0.0045 · √D** [m] | Muysken/Nuernbergk → 3.0 mm para D = 0.45 m |
| n | **≤ 50 / D^(2/3)** rpm | Muysken/Nagel (verificado vs. catálogo Landy) |

### 5.3 Exportación a ANSYS

- Exportar el **ensamblaje inclinado** en **Parasolid (.x_t)** o **STEP AP214**. Parasolid conserva mejor las superficies helicoidales.
- Exportar **tornillo** y **artesa + canal** como cuerpos separados e identificados.
- **No** exportar marco estructural ni láminas laterales (ahorro de celdas justificado).
- Alinear el eje del tornillo con un eje global si es posible: simplifica enormemente la definición del eje de rotación y del reporte de par, y evita la corrección por brazo de palanca que tanto trabajo dio en Flow Simulation.

---

## 6. Montaje en ANSYS Fluent

### 6.1 Dominio fluido

Dos operaciones booleanas en SpaceClaim/Discovery:

1. `Volumen_total = Cámara_entrada ∪ Interior_artesa ∪ Canal_descarga`
2. `Fluido = Volumen_total − Tornillo`
3. **Dividir** el fluido en dos cuerpos: **(a) zona rotatoria** = fluido dentro de la artesa; **(b) zonas fijas** = cámara de entrada y canal de descarga. Compartir topología (`Share Topology`) o crear interfaces de malla.

> Comprobación de la resta booleana: el volumen total reportado por Fluent debe ser **menor** que la suma de los cuerpos. Este es exactamente el error que ya detectaron una vez — vale la pena volver a verificarlo.

### 6.2 Malla

| Región | Tamaño objetivo |
|---|---|
| Global | D/20 |
| Superficie del tornillo | D/60, con *inflation* 5 capas |
| **Holgura álabe–artesa** | **≥ 5 celdas a través de la holgura** |
| Cámara de entrada / descarga | grueso, D/10 |

Celda necesaria en la holgura: **s_sp / 5**

| D [m] | s_sp | Celda en holgura |
|---|---|---|
| 0.192 (validación) | 1.97 mm* | 0.39 mm |
| 0.450 | 3.02 mm | 0.60 mm |
| 0.840 | 4.12 mm | 0.82 mm |

\* Dellinger usó 1.00 mm medido, más apretado que la regla.

**y⁺ objetivo: 50 – 300** (funciones de pared, igual que Dellinger). Verificar con `Reports → Surface Integrals → Wall Yplus` después de la primera corrida y ajustar.

**Estrategia con licencia Student:** apuntar a 0.9–1.0 M celdas. Según la Tabla 3 de Dellinger eso da ~5–8 % de error en el par, lo cual es aceptable **si se reporta**. Recortes legítimos: reducir ancho/profundidad del canal (Dellinger lo hizo explícitamente), acortar las cámaras de entrada/salida, malla gruesa fuera de la artesa. Hacer un **estudio de sensibilidad de malla con 3 niveles** (p. ej. 0.4 / 0.7 / 1.0 M) y reportar la extrapolación.

### 6.3 Configuración física

| Aspecto | Configuración | Por qué |
|---|---|---|
| Solver | **Pressure-based, TRANSITORIO** | El llenado/vaciado de cangilones es intrínsecamente no estacionario |
| Multifásico | **VOF**, 2 fases (aire primaria, agua secundaria), formulación **Implicit** con esquema de interfaz **Sharp/Compressive**, o Explicit con Courant ≤ 0.25 | Superficie libre |
| **Movimiento del rotor** | **Mesh Motion (malla deslizante)**, NO MRF | Ver §6.4 |
| Turbulencia | **k-ω SST** | Igual que la referencia |
| Gravedad | activada, componente correcta según la orientación | Es el motor de la máquina |
| Entrada | **Mass-flow-inlet** o velocity-inlet de agua con caudal Q impuesto | Q es el parámetro de control |
| Salida | **Pressure-outlet** con *Open Channel* y **nivel de superficie libre h_out impuesto** | **Así se impone el salto** |
| Techo del dominio | pressure-outlet a presión atmosférica (aire) | Deja respirar la superficie libre |
| Pared del tornillo | no-slip, **solidaria a la zona rotatoria** | Gira |
| **Pared de la artesa** | no-slip, **Moving Wall → Absolute → Rotational, ω = 0** | La artesa está DENTRO de la zona rotatoria pero es FIJA. Esto es exactamente lo que hace Dellinger con `rotatingWallVelocity` |
| Acoplamiento | PISO o Coupled con pseudo-transitorio desactivado | Transitorio |
| Paso de tiempo | **≤ 1° de giro por paso** | Ver tabla abajo |

**Paso de tiempo:**

| n [rpm] | Δt (1°/paso) | 5 vueltas | N.º de pasos |
|---|---|---|---|
| 70 | 2.38 ms | 4.3 s | ~1800 |
| 130 | 1.28 ms | 2.3 s | ~1800 |
| 57.3 | 2.91 ms | 5.2 s | ~1800 |
| 85 | 1.96 ms | 3.5 s | ~1800 |

### 6.4 Por qué malla deslizante y no MRF

MRF ("Frame Motion") resuelve el flujo **estacionario en un marco que rota**. Es válido cuando, visto desde el rotor, el flujo no cambia con el tiempo — turbomáquinas cerradas, bombas, ventiladores.

En un tornillo de Arquímedes eso **no ocurre**: cada cangilón se llena en la entrada, viaja lleno y se vacía en la descarga. El campo cambia continuamente incluso en el marco rotante, y además la posición de la superficie libre depende del ángulo instantáneo de los álabes. Dellinger lo resuelve con **AMI (Arbitrary Mesh Interface) = malla deslizante**, no con MRF. En Fluent el equivalente es `Cell Zone Conditions → Mesh Motion`.

Esto también explica por qué las corridas anteriores daban resultados extraños: MRF + interfaz sellada + sin artesa + sin salto es una combinación en la que ningún resultado podía ser correcto.

### 6.5 Reportes a definir

1. **Par sobre el eje:** `Report Definition → Moment` sobre **todas** las paredes del tornillo, con centro y eje del tornillo. Guardar como archivo `.out`.
2. **Par de presión y par viscoso por separado.** Dellinger los separa: C_screw = C_p − C_v. Es un diagnóstico excelente (si C_v domina, hay problema de malla o de y⁺).
3. **Nivel aguas arriba h_in:** iso-superficie de fracción de agua α = 0.5, medir la altura en la misma estación en todas las corridas.
4. **Balance de masa** entrada−salida → debe tender a 0.
5. **Flujo másico a través de la interfaz de malla** → debe ser ≠ 0 (el chequeo que ya salvó la simulación una vez).

### 6.6 Criterios de convergencia (los de Dellinger)

- Residuos normalizados de presión y velocidad < **10⁻⁵** en cada paso de tiempo.
- Diferencia entre dos valores sucesivos de C_screw y h_in **promediados sobre una revolución** < **0.5 %**.
- Balance de masa → 0.
- **Promediar los resultados sobre 4 revoluciones** una vez alcanzado el régimen.

### 6.7 Post-proceso: cálculo de la eficiencia

$$H = h_{in} - h_{out} \qquad\qquad \eta = \frac{C_{screw}\,\omega}{\rho\,g\,Q\,H}$$

**Ojo:** h_out se **impone** (condición de salida), h_in es un **resultado** del cálculo. Por tanto H es parcialmente un resultado. Dellinger reporta que el CFD tiende a **subestimar h_in** (por sobreestimación de la fuga en la holgura), lo que **sobreestima η en hasta ~15 %** a velocidades altas. Conviene citarlo como incertidumbre conocida.

---

## 7. El barrido de salto (lo que pidió el docente)

### 7.1 Las dos formas de "cambiar el salto" — y cuál responde la pregunta

**(a) Barrido de niveles con la máquina fija.** Cambiar h_out manteniendo el tornillo. Esto cambia la sumergencia: si se sube h_out se ahogan los cangilones inferiores; si se baja, el agua cae libremente al salir y ese salto se desperdicia. Es una **sensibilidad operativa** válida (Dellinger demuestra que h_out afecta directamente la eficiencia), pero **no responde** "¿a partir de qué salto deja de servir el tornillo?".

**(b) Barrido de salto de sitio con rediseño de la máquina.** Para cada H, el tornillo que le corresponde tiene **L = H / sin β**, es decir, **más o menos cangilones**. Ésta es la pregunta del docente y **ésta es la que hay que correr como estudio principal.**

### 7.2 Por qué el tornillo deja de funcionar con salto bajo

Tres mecanismos, todos cuantificables:

1. **Se acaban los cangilones.** El salto que aporta cada vuelta es **S · sin β**. Para el diseño actual (S = 0.30 m, β = 25°): **0.127 m por vuelta**. Con H = 0.5 m solo caben **3.9 vueltas**. Con H = 0.15 m cabe **una sola** — y con un solo cangilón no hay sello hidráulico.
2. **Las pérdidas fijas se comen el salto.** La entrada (aceleración y llenado) y la descarga cuestan aproximadamente **una vuelta de salto**, independientemente de H. Si H equivale a 4 vueltas, eso es el **25 %** del recurso; si equivale a 24 vueltas, es el **4 %**.
3. **El par resistente no escala con H.** Rodamientos, sellos y el par de arranque del generador son ~constantes, mientras que el par motor cae proporcionalmente al número de cangilones llenos. Por debajo de cierto H, **C_motor < C_resistente y el tornillo simplemente no arranca.** Éste es literalmente el escenario que planteó el docente.

### 7.3 Estimación previa (para saber qué esperar)

Modelo simple: η ≈ η_ideal · (1 − ΔH_fijo/H), con η_ideal = 0.80 y ΔH_fijo = S·sin β.

**Con el paso actual S = 0.30 m, β = 25°:**

| H [m] | L [m] | Vueltas / cangilones | ΔH_fijo/H | η estimada |
|---|---|---|---|---|
| 0.15 | 0.35 | 1.2 | 0.85 | **0.12** ← inviable |
| 0.25 | 0.59 | 2.0 | 0.51 | **0.39** ← marginal |
| 0.35 | 0.83 | 2.8 | 0.36 | 0.51 |
| **0.50** | **1.18** | **3.9** | **0.25** | **0.60** ← el punto del proyecto |
| 0.75 | 1.77 | 5.9 | 0.17 | 0.66 |
| 1.00 | 2.37 | 7.9 | 0.13 | 0.70 |
| 1.50 | 3.55 | 11.8 | 0.08 | 0.73 |
| 2.00 | 4.73 | 15.8 | 0.06 | 0.75 |
| 3.00 | 7.10 | 23.7 | 0.04 | 0.77 |

**Lectura:** con H = 0.5 m el tornillo **funciona pero degradado** (η ≈ 0.60 en vez de 0.80). El colapso ocurre alrededor de **H ≈ 0.15–0.25 m**. Y ojo: Rohmer sitúa el rango típico de aplicación de los ASG en **H = 1 – 6.5 m**, o sea que el salto de diseño del proyecto ya está por debajo del rango validado de la tecnología.

**Palanca de diseño — reducir el paso.** Con S = 0.15 m (más cangilones por metro de salto):

| H [m] | Vueltas | η estimada | vs. S = 0.30 |
|---|---|---|---|
| 0.25 | 3.9 | 0.60 | +0.21 |
| 0.35 | 5.5 | 0.66 | +0.15 |
| 0.50 | 7.9 | **0.70** | **+0.10** |
| 1.00 | 15.8 | 0.75 | +0.05 |

El precio: Q_nom baja proporcionalmente a S, así que hay que compensar con más diámetro. **Este trade-off (paso vs. diámetro a salto bajo) es un resultado de ingeniería mucho más valioso que la curva T–ω, y es justo lo que el CFD puede cuantificar bien.**

### 7.4 Matriz de corridas propuesta

**Fase 1 — Validación (obligatoria, geometría de Dellinger, ~7 corridas)**

| # | Q [L/s] | n [rpm] | n/n_nom | Objetivo |
|---|---|---|---|---|
| V1 | 2.8 | 70 | 0.83 | flanco de *over-filling* |
| V2 | 2.8 | 85 | 1.00 | nominal |
| V3 | 2.8 | 105 | 1.24 | cerca del óptimo |
| **V4** | **2.8** | **130** | **1.54** | **punto ancla: C = 0.2370 N·m, η = 0.7434** |
| V5 | 2.8 | 145 | 1.71 | flanco de fricción |
| V6 | 1.0 | 70 | — | Q/Q_nom = 0.43 |
| V7 | 2.0 | 70 | — | Q/Q_nom = 0.86 |

Más 3 mallas en V4 para la sensibilidad de malla.

**Fase 2 — Estudio de salto (el estudio principal, geometría del proyecto, ~6 corridas)**

| # | H [m] | L [m] | Q | n | Objetivo |
|---|---|---|---|---|---|
| P1 | 0.25 | 0.59 | Q_nom | n_nom | ¿arranca? |
| P2 | 0.35 | 0.83 | Q_nom | n_nom | zona de colapso |
| P3 | 0.50 | 1.18 | Q_nom | n_nom | **punto de diseño** |
| P4 | 0.75 | 1.77 | Q_nom | n_nom | |
| P5 | 1.00 | 2.37 | Q_nom | n_nom | |
| P6 | 1.50 | 3.55 | Q_nom | n_nom | asíntota |

**Producto:** curva **η vs. H** y **P vs. H**, con el umbral de viabilidad identificado. Ésta es la figura que el docente quiere ver.

**Fase 3 — Optimización (opcional, 4 corridas)**
Variar S/D (0.5, 0.75, 1.0, 1.25) a H = 0.5 m fijo, para cuantificar la palanca de §7.3.

**Fase 4 — Punto de operación (4 corridas)**
Barrido de n/n_nom (0.8, 1.0, 1.2, 1.5) en el diseño final, **presentado como en §8**.

> Si las corridas largas (P5, P6) no caben en la licencia: simular 3 pasos centrales con **condiciones periódicas** para obtener la pérdida por cangilón, y construir el resto analíticamente. Vale la pena mencionarlo como plan B en el informe.

---

## 8. La pregunta sobre ω: qué responder al docente

**Él tiene razón en objetar, y ustedes tienen una respuesta legítima. Ambas cosas.**

**Por qué objetó:** en el montaje hidrocinético, ω se barría como se barre el *tip-speed ratio* de una turbina eólica, buscando un máximo de C_p. Ese marco conceptual no existe en una máquina de gravedad, así que el barrido no significaba nada físico. Además, sin salto en el modelo, la curva T–ω era la de un objeto arrastrado por una corriente.

**Cuál es el papel real de ω en un ASG:** para un caudal Q y una geometría dados existe una **velocidad nominal**

$$n_{nom} = \frac{60\,Q}{N\,V_{cangilón}}$$

que es la velocidad a la que el tornillo traga exactamente Q con los cangilones en su llenado óptimo. Entonces:

| Régimen | Qué pasa | Efecto en η |
|---|---|---|
| **n < n_nom** | *Over-filling*: llega más agua de la que el tornillo evacúa; rebosa **por encima del núcleo** sin hacer trabajo | η cae |
| **n ≈ n_nom … 1.2 n_nom** | Llenado óptimo | **η máxima ≈ 0.80** |
| **n > n_nom** | *Under-filling*: cangilones parcialmente llenos, y la fricción crece con la velocidad | η cae |

Es decir: **ω no es una variable libre, es la variable que fija el nivel de llenado para un Q dado.** Barrerla es legítimo, pero:

1. Debe presentarse **normalizada como n/n_nom**, no en rad/s absolutos.
2. Debe hacerse **a Q constante**, dejando claro que lo que se está barriendo es en realidad el llenado.
3. El rango debe ser acotado y físico: Dellinger barre **n/n_nom = 0.83 a 1.71**.
4. La variable de salida relevante es **η**, no el par.

Dicho de otro modo: **ω determina el punto de operación; H determina si hay máquina.** Por eso el estudio principal es el de H (§7) y el de ω es un estudio secundario de punto de operación, expresado en n/n_nom.

---

## 9. Qué queda pendiente antes de simular

Por orden de prioridad. Los dos primeros bloquean todo lo demás.

1. **Aforo de la quebrada (Q real).** Método del flotador o molinete, en época seca y en época húmeda. Todo el dimensionamiento sale de aquí. El dato de IDEAM que hay en la carpeta es de la estación Mérida sobre el **río Fonce** (16–58 m³/s) — es un río, no la quebrada objetivo, y no sirve para dimensionar esta máquina.
2. **Levantamiento del salto disponible (H real).** Nivel topográfico o manguera de nivel. Determina si el proyecto es viable con esta tecnología.
3. **Rediseñar la geometría** con §5.2 una vez se tengan Q y H.
4. **Construir el Modelo V** (validación) — se puede hacer **ya**, sin esperar los datos de campo.
5. **Correr la Fase 1** y cerrar la validación.
6. Recién entonces, Fases 2–4.

---

## 10. Cómo presentarlo al docente

Sugerencia de estructura para la reunión o el informe corregido:

1. **"Revisamos el modelo y encontramos un error conceptual, no solo de montaje."** El tornillo se había modelado como máquina hidrocinética; es hidrostática. Mostrar §1.
2. **"Lo detectamos con un balance de energía."** Los 180 W implicaban η = 181 %. Mostrar §2.2. Esto demuestra criterio propio.
3. **"El caudal de diseño y la geometría eran incompatibles por un factor de 150."** Mostrar §2.1 y contrastarlo con el catálogo Landustrie que el propio proyecto ya citaba.
4. **"Adoptamos un caso de validación publicado."** Dellinger 2018, con los objetivos numéricos de §3.3 y los criterios de aceptación de §3.4.
5. **"El estudio principal ahora es el barrido de salto."** Mostrar la tabla de §7.3 como predicción previa y explicar que el CFD la va a confirmar o corregir. Mencionar que Rohmer sitúa el rango típico de la tecnología en H = 1–6.5 m, o sea que el sitio está en el límite: **cuantificar dónde deja de ser viable es el aporte del trabajo.**
6. **"Sobre ω:"** explicar §8 — que se barre n/n_nom porque fija el llenado, y que es un estudio secundario de punto de operación.

El trabajo hecho no se pierde: la depuración de la interfaz sellada, la corrección del par por brazo de palanca y la justificación de la migración a Fluent son metodológicamente sólidos y valen como sección de "desarrollo del método".

---

## Referencias

1. G. Dellinger et al., *"Computational fluid dynamics modeling for the design of Archimedes Screw Generator"*, Renewable Energy 118 (2018) 847–857.
2. J. Rohmer, D. Knittel, G. Sturtzer, D. Flieller, J. Renaud, *"Modeling and experimental results of an Archimedes screw turbine"*, Renewable Energy 94 (2016) 136–146.
3. C. Rorres, *"The turn of the screw: Optimal design of an Archimedes screw"*, J. Hydraulic Engineering 126(1) (2000) 72–80.
4. F. R. Menter, *"Two-equation eddy-viscosity turbulence models for engineering applications"*, AIAA Journal 32(8) (1994) 1598–1605.
5. C. W. Hirt, B. D. Nichols, *"Volume of fluid (VOF) method for the dynamics of free boundaries"*, J. Computational Physics 39(1) (1981) 201–225.
6. Landustrie, *Tornillos de Arquímedes* (catálogo técnico) — ya referenciado en el proyecto.
7. ANSYS Inc., *Ansys Fluent Theory Guide*, Release 2026 R1.
