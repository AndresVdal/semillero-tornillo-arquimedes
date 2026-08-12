# Turbina de tornillo de Arquímedes

**Semillero SIIM — Universidad Pontificia Bolivariana, Bucaramanga**

![Estado](https://img.shields.io/badge/estado-en_desarrollo-orange)
![Solver](https://img.shields.io/badge/CFD-Ansys_Fluent_25.2_R2-blue)
![CAD](https://img.shields.io/badge/CAD-SolidWorks_2023-green)

---

## Descripción

Este proyecto diseña y valida numéricamente una **turbina de tornillo de
Arquímedes** para micro-generación hidroeléctrica en una quebrada de bajo
salto.

El tornillo de Arquímedes se usó durante siglos para elevar agua. Operado a
la inversa —dejando que el agua caiga a través de él— funciona como turbina.
Es una **máquina hidrostática de gravedad**: no extrae energía cinética del
flujo, sino energía potencial. El agua queda atrapada en cangilones formados
entre dos álabes consecutivos, el núcleo y la artesa que envuelve al
tornillo, y el peso de esa agua genera el par en el eje. Esta distinción es
el eje conceptual de todo el trabajo.

La tecnología resulta atractiva para el contexto rural colombiano por tres
razones: opera con saltos muy pequeños donde una Pelton o una Francis no son
viables, tolera agua con sedimentos y material vegetal sin obstruirse, y su
baja velocidad de giro permite el paso de peces. Es además constructivamente
sencilla y reparable en sitio.

El trabajo se organiza en dos frentes. El primero es la **validación del
método numérico** contra el caso experimental publicado por Dellinger et al.
(2018): si el modelo reproduce el torque de un tornillo conocido dentro del
10 %, el método es confiable para diseñar uno nuevo. El segundo es el
**diseño del tornillo del proyecto**, que requiere medir en campo el caudal
y el salto reales del sitio antes de fijar cualquier dimensión.

El estudio principal responde a una pregunta concreta: **¿a partir de qué
salto deja de ser viable un tornillo de Arquímedes?** Cada salto exige un
tornillo distinto, con más o menos cangilones según L = H / sin β. Por debajo
de cierto valor las pérdidas fijas de entrada y descarga se comen el recurso,
se pierde el sello hidráulico y el par resistente supera al motor. La
literatura sitúa el rango típico de esta tecnología entre 1 y 6.5 m de salto;
cuantificar dónde exactamente deja de servir por debajo de ese rango es el
aporte de este trabajo.

---

## Estructura del repositorio

```
Semillero/
│
├── README.md                  Este archivo — visión del proyecto completo
├── .gitignore                 Excluye binarios pesados de Ansys
├── autopush.ps1               Subida automática a GitHub
│
├── docs/                      Metodología transversal
│   ├── Protocolo_validacion_modelado_CFD_tornillo.md
│   └── historico/             Versiones anteriores del protocolo
│
├── Dellinger/                 ▶ FRENTE 1: validación del método
│   ├── README.md              Estado, resultados y hoja de ruta
│   ├── docs/                  Bitácora, guía de arranque, traspaso
│   ├── CAD/                   Geometría del Modelo V (STEP)
│   ├── Workbench/             Proyectos Ansys y monitores .out
│   └── Imagenes/              Capturas de configuración y resultados
│
└── Proyecto/                  ▶ FRENTE 2: turbina del sitio (Modelo P)
    ├── README.md
    ├── Sitio/                 Aforo y levantamiento topográfico
    ├── CAD/
    └── Workbench/
```

**La separación clave es Dellinger / Proyecto.** Todo lo que lleva sufijo
`_V` pertenece al Modelo V de validación y vive bajo `Dellinger/`. El Modelo
P, el tornillo que realmente se va a construir, vive bajo `Proyecto/` y a
hoy está vacío a la espera de los datos de campo.

### Qué se versiona

Solo texto y geometría de intercambio. Los `.h5`, `.dat`, `.cas` y `.msh`
están excluidos: pesan cientos de MB y GitHub rechaza archivos de más de
100 MB. Los monitores `.out` pesan unos 50 KB, así que se versionan en cada
ciclo sin problema y permiten reconstruir la historia de convergencia
completa.

---

## Estado

| Frente | Etapa | Estado |
|---|---|---|
| Validación | Reproducir Dellinger et al. (2018) | En curso — geometría en corrección |
| Proyecto | Aforo de la quebrada (Q real) | **Pendiente — bloqueante** |
| Proyecto | Levantamiento del salto (H real) | **Pendiente — bloqueante** |
| Proyecto | Dimensionamiento del Modelo P | Bloqueado |
| Proyecto | Barrido de salto | Bloqueado |

Los dos datos de campo son el cuello de botella real. **La validación puede
avanzar sin ellos; el diseño no.**

Detalle técnico del frente de validación en
[`Dellinger/README.md`](Dellinger/README.md).

---

## El punto de partida: qué se corrigió

El proyecto arrancó con un modelo conceptualmente equivocado. Queda
documentado porque la corrección es parte del aporte.

| # | Problema | Consecuencia |
|---|---|---|
| **A** | Se simuló como máquina **hidrocinética** (corriente de 3.3 m/s, sin artesa, sin salto) | Toda la física del modelo era la equivocada |
| **B** | Caudal de diseño de 3 m³/s contra una capacidad real de 0.020–0.030 m³/s | Factor de **148×** de exceso |
| **C** | Se reportaron 180 W con solo 99 W disponibles | Eficiencia del **181 %** — físicamente imposible |
| **D** | Sin caso de validación | Imposible saber si el montaje numérico era correcto |

El error B se detectó con la fórmula de capacidad de trago y se contrastó
con el catálogo Landustrie que el propio proyecto ya citaba: para 3 m³/s se
necesita un tornillo de 2.8 a 3.2 m de diámetro, no de 0.45 m.

El error C se detectó con un balance de energía de tres líneas:
`P_hid = ρgQH = 1000 × 9.81 × 0.0203 × 0.5 = 99 W`.

---

## Reglas de diseño del Modelo P

A aplicar una vez se tengan Q y H del sitio:

| Parámetro | Regla | Fuente |
|---|---|---|
| ρ = d/D | 0.50 – 0.54 | Rorres (2000) |
| S/D | 1.0 – 1.15 | Dellinger, Rohmer |
| N (entradas) | 3 | Ambos |
| β (inclinación) | 22° – 30° | Rango experimental |
| L (longitud) | H / sin β | Geometría |
| Holgura | ≈ 0.0045·√D m | Muysken/Nuernbergk |
| n_max | ≤ 50 / D^(2/3) rpm | Muysken/Nagel |

Orden de magnitud esperable:

| D [m] | Q_nom [m³/s] | P @ H=0.5 m | P @ H=1 m |
|---|---|---|---|
| 0.30 | 0.015 | 54 W | 109 W |
| 0.45 | 0.038 | 140 W | 280 W |
| 0.60 | 0.075 | 274 W | 548 W |
| 1.00 | 0.245 | 903 W | 1.81 kW |

---

## Metodología

- **CFD multifásico VOF** en Ansys Fluent con **malla deslizante**. No MRF:
  en un tornillo los cangilones se llenan y se vacían a lo largo de la
  máquina, así que el flujo nunca es estacionario en el marco rotante.
- **Validación experimental previa** antes de diseñar nada.
- **Independencia de malla** con extrapolación de Richardson y GCI según
  ASME V&V 20. Los resultados se reportan como valor ± incertidumbre.

---

## Referencias

1. G. Dellinger et al. (2018). Computational fluid dynamics modeling for the
   design of Archimedes Screw Generator. *Renewable Energy* **118**, 847–857.
2. J. Rohmer et al. (2016). Modeling and experimental results of an
   Archimedes screw turbine. *Renewable Energy* **94**, 136–146.
3. C. Rorres (2000). The turn of the screw: Optimal design of an Archimedes
   screw. *J. Hydraulic Engineering* **126**(1), 72–80.
4. C. W. Hirt, B. D. Nichols (1981). Volume of fluid (VOF) method for the
   dynamics of free boundaries. *J. Computational Physics* **39**(1), 201–225.
5. F. R. Menter (1994). Two-equation eddy-viscosity turbulence models for
   engineering applications. *AIAA Journal* **32**(8), 1598–1605.
6. ASME V&V 20-2009. Standard for Verification and Validation in CFD and
   Heat Transfer.
7. Landustrie. *Tornillos de Arquímedes* (catálogo técnico).

---

Repositorio privado de trabajo académico. Los datos experimentales de
referencia pertenecen a sus autores originales y se citan únicamente con
fines de validación.
