# Modelo P — Turbina del proyecto

Diseño del tornillo que realmente se va a construir, dimensionado para el
caudal y el salto del sitio.

← [Volver al proyecto](../README.md)

---

## Estado: bloqueado

> **No se puede modelar hasta fijar Q y H reales del sitio.** Ese es el orden
> correcto. Dimensionar antes de medir es exactamente el error que dio origen
> al problema del caudal 148× sobredimensionado.

### Lo que falta, en orden

1. **Aforo de la quebrada (Q real).** Método del flotador o molinete, en
   época seca y en época húmeda. Todo el dimensionamiento sale de aquí.

   > El dato del IDEAM que hay en la carpeta es de la estación Mérida sobre
   > el **río Fonce** (16–58 m³/s). Es un río, no la quebrada objetivo, y no
   > sirve para dimensionar esta máquina.

2. **Levantamiento del salto disponible (H real).** Nivel topográfico o
   manguera de nivel. Determina si el proyecto es viable con esta tecnología.

3. **Dimensionar** con las reglas de abajo.

4. **Simular** con el método ya validado en [`../Dellinger/`](../Dellinger/README.md).

---

## Procedimiento de dimensionamiento

1. Medir **Q** → entrar por la columna `Q_nom` → sale **D**.
2. Medir **H** → entrar por las columnas de potencia → verificar que alcanza
   para la demanda.
3. Fijar **β** entre 22° y 30° (25° es buen compromiso) → **L = H / sin β**.
4. Verificar que L sea constructivamente razonable. A 25°, H = 1 m implica
   L = 2.37 m.

### Tabla de dimensionamiento

Con ρ = 0.5, S = D, N = 3, f = 0.5, η = 0.75:

| D [m] | d [m] | S [m] | n_max [rpm] | Q_nom [m³/s] | P @ H=0.5 m | P @ H=1 m | P @ H=2 m |
|---|---|---|---|---|---|---|---|
| 0.30 | 0.15 | 0.30 | 111.6 | 0.015 | 54 W | 109 W | 218 W |
| 0.45 | 0.23 | 0.45 | 85.1 | 0.038 | 140 W | 280 W | 560 W |
| 0.60 | 0.30 | 0.60 | 70.3 | 0.075 | 274 W | 548 W | 1.1 kW |
| 0.80 | 0.40 | 0.80 | 58.0 | 0.146 | 536 W | 1.07 kW | 2.1 kW |
| 1.00 | 0.50 | 1.00 | 50.0 | 0.245 | 903 W | 1.81 kW | 3.6 kW |
| 1.50 | 0.75 | 1.50 | 38.2 | 0.632 | 2.3 kW | 4.7 kW | 9.3 kW |
| 2.00 | 1.00 | 2.00 | 31.5 | 1.237 | 4.6 kW | 9.1 kW | 18.2 kW |
| 3.00 | 1.50 | 3.00 | 24.0 | 3.186 | 11.7 kW | 23.4 kW | 46.9 kW |

### Reglas de diseño

| Parámetro | Regla | Fuente |
|---|---|---|
| ρ = d/D | **0.50 – 0.54** | Rorres (2000); Dellinger 0.542; Rohmer 0.50 |
| S/D | **1.0 – 1.15** | Dellinger 1.00; Rohmer 1.14 |
| N (entradas) | **3** | Ambos papers |
| β | **22° – 30°** | Rango experimental |
| L | **H / sin β** | Geometría |
| Salto por vuelta | S·sin β | Cuántos cangilones caben en H |
| Holgura s_sp | **≈ 0.0045·√D** m | Muysken/Nuernbergk |
| n | **≤ 50 / D^(2/3)** rpm | Muysken/Nagel |

---

## El estudio principal: barrido de salto

**¿A partir de qué salto deja de ser viable un tornillo de Arquímedes?**

No se trata de subir y bajar el nivel de agua con la máquina fija —eso es
una sensibilidad operativa válida pero distinta—. Se trata de que **para
cada salto le corresponde un tornillo distinto**, con L = H / sin β, es
decir, con más o menos cangilones.

### Tres mecanismos de colapso a salto bajo

1. **Se acaban los cangilones.** Cada vuelta aporta S·sin β de salto. Con
   S = 0.30 m y β = 25° son 0.127 m por vuelta. Con H = 0.15 m cabe una sola
   vuelta, y con un solo cangilón no hay sello hidráulico.
2. **Las pérdidas fijas se comen el salto.** La entrada y la descarga cuestan
   aproximadamente una vuelta, sin importar H. Si H equivale a 4 vueltas eso
   es el 25 % del recurso; si equivale a 24 vueltas, el 4 %.
3. **El par resistente no escala con H.** Rodamientos, sellos y el par de
   arranque del generador son casi constantes, mientras el par motor cae con
   el número de cangilones llenos. Por debajo de cierto salto el tornillo
   **no arranca**.

### Estimación previa

Modelo simple: η ≈ η_ideal · (1 − ΔH_fijo/H), con η_ideal = 0.80 y
ΔH_fijo = S·sin β. Con S = 0.30 m y β = 25°:

| H [m] | L [m] | Cangilones | η estimada | |
|---|---|---|---|---|
| 0.15 | 0.35 | 1.2 | **0.12** | inviable |
| 0.25 | 0.59 | 2.0 | **0.39** | marginal |
| 0.35 | 0.83 | 2.8 | 0.51 | |
| **0.50** | **1.18** | **3.9** | **0.60** | punto del proyecto |
| 0.75 | 1.77 | 5.9 | 0.66 | |
| 1.00 | 2.37 | 7.9 | 0.70 | |
| 1.50 | 3.55 | 11.8 | 0.73 | |
| 2.00 | 4.73 | 15.8 | 0.75 | |
| 3.00 | 7.10 | 23.7 | 0.77 | |

Con H = 0.5 m el tornillo **funciona pero degradado** (η ≈ 0.60 en vez de
0.80). El colapso ocurre alrededor de **H ≈ 0.15–0.25 m**.

Rohmer sitúa el rango típico de aplicación de los ASG en **H = 1 a 6.5 m**,
así que el salto de diseño del proyecto ya está por debajo del rango
validado de la tecnología. **Cuantificar dónde deja de ser viable es el
aporte del trabajo.**

### Palanca de diseño: reducir el paso

Un paso más corto mete más cangilones por metro de salto. Con S = 0.15 m:

| H [m] | Vueltas | η estimada | vs. S = 0.30 |
|---|---|---|---|
| 0.25 | 3.9 | 0.60 | +0.21 |
| 0.35 | 5.5 | 0.66 | +0.15 |
| 0.50 | 7.9 | **0.70** | **+0.10** |
| 1.00 | 15.8 | 0.75 | +0.05 |

El precio: Q_nom baja proporcionalmente a S, así que hay que compensar con
más diámetro. **Este compromiso entre paso y diámetro a salto bajo es un
resultado de ingeniería más valioso que la curva torque–velocidad**, y es
justo lo que el CFD puede cuantificar bien.

---

## Coste computacional por corrida

Estimación para 2 M celdas, VOF transitorio con malla deslizante:

| Concepto | Valor |
|---|---|
| Δt (2° de giro por paso) | 4.8 ms a 70 rpm |
| Revoluciones necesarias | 4 para establecer + 4 para promediar = **8** |
| Pasos de tiempo | ≈ 1 400 |
| Iteraciones por paso | 15 – 25 |
| **Tiempo por caso** | **medio día a 2 días** |

Conviene **cronometrar la primera corrida** y recalibrar la matriz con ese
dato antes de comprometerse con un plan.

---

## Estructura de esta carpeta

```
Proyecto/
├── README.md      Este archivo
├── Sitio/         Aforo, levantamiento topográfico, fotos del sitio
├── CAD/           Geometría del Modelo P (sufijo _P)
└── Workbench/     Proyectos Ansys del barrido de salto
```
