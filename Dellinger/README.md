# Validación del método — Dellinger et al. (2018)

Reproducción numérica del caso experimental de referencia. El objetivo no es
diseñar nada, sino **demostrar que el montaje CFD predice correctamente el
torque de un tornillo conocido**. Sin esto, cualquier resultado del Modelo P
carece de respaldo.

← [Volver al proyecto](../README.md)

---

## Criterios de aceptación

| Métrica | Tolerancia |
|---|---|
| Torque en el eje | ≤ 10 % de error |
| Eficiencia η | ≤ 8 puntos porcentuales |
| Posición de η máxima | ± 15 % |

---

## Estado actual

> **El modelo todavía NO está validado.** Hay un defecto geométrico
> identificado que bloquea la comparación con el experimento.

### Hallazgo principal

El dominio CAD contiene **2 hélices en lugar de 3**. El análisis del STEP
encontró 24 superficies B-spline donde deberían existir 36, con fases
angulares en 73° y 193°, y la tercera posición (313°) vacía.

Se confirmó por dos vías independientes:

- **Geométrica.** Concentración de simetría rotacional: N=3 → 0.995,
  N=6 → 0.980, pero N=1/2/4 → ≈0.50.
- **Espectral.** El pico medido de la FFT del torque está en **4.244 Hz**.
  Con f_rotación = 2.170 Hz, dos álabes predicen 4.340 Hz (−2.2 %) y tres
  predicen 6.511 Hz (−34.8 %).

Con un tercio menos de superficie de empuje, el torque queda
sistemáticamente por debajo del valor experimental.

### Indicadores

| Indicador | Valor | Criterio | ¿Cumple? |
|---|---|---|---|
| Torque (últimas 4 rev, solo `tornillo`) | ≈ 0.1979 N·m | 0.2370 ± 10 % | ❌ −16.5 % |
| Variación entre revoluciones consecutivas | hasta 31 % | < 0.5 % | ❌ |
| Error de conservación de masa (agua) | −5.3 % | < 1 % | ❌ |
| Balance de la fase aire | +0.000845 kg/s | ≈ 0 | ✅ |
| Interfaces de malla | 100 % solape | sin huecos | ✅ |
| Eje de rotación | 24.00° exacto | 24° | ✅ |

**Todavía no se alcanza el régimen estacionario.** Las medias por revolución
siguen oscilando, así que ningún promedio actual es reportable.

---

## Geometría de referencia

| Parámetro | Símbolo | Valor |
|---|---|---|
| Radio exterior | R_a | 0.096 m |
| Radio interior del eje | R_i | 0.052 m |
| Paso | S | 0.192 m |
| Longitud del tornillo | L_B | 0.400 m |
| Número de álabes | N | **3** |
| Espesor del álabe | s_sp | 0.001 m |
| Ángulo de inclinación | β | 24° |

El STEP actual reproduce con exactitud todas las dimensiones
(R_i = 52 mm, artesa = 97 mm, S = 192.0 mm, β = 24.00°). El único defecto
es el número de álabes.

---

## Configuración del solver

| Parámetro | Valor |
|---|---|
| Velocidad de giro | −13.636 rad/s = **130.21 rpm** |
| Paso temporal | 0.00192299997434 s = 1.502°/paso |
| Pasos por revolución | 240 |
| Periodo de revolución | 0.46078 s |
| Avance simulado | 4.4383 s ≈ 9.63 revoluciones |
| Iteraciones máx. por paso | 20 |
| Movimiento de zona | Mesh Motion (no MRF) |
| Eje de rotación | (0.913545, 0, −0.406737) |

Los primeros 100 pasos se corrieron con dt = 0.0005 s para arrancar.

---

## Contenido de esta carpeta

```
Dellinger/
├── README.md              Este archivo
├── docs/
│   ├── PROGRESO_validacion_CFD_tornillo.md    Bitácora de depuración
│   ├── GUIA_arranque_modelo_V.md              Montaje paso a paso
│   └── TRASPASO_ASG_Dellinger.md              Extracción del paper
├── CAD/
│   ├── tornillo_V.step                        Tornillo
│   ├── artesa_V.step                          Artesa
│   ├── dominio_3cuerpos_V.step                Dominio fluido ◀ en uso
│   ├── dominio_completo_V.step
│   ├── fluido_rotatorio_V.step
│   ├── fluido_camara_entrada_V.step
│   ├── fluido_canal_descarga_V.step
│   ├── generar_tornillo.py                    Script paramétrico
│   └── SpaceClaim/
├── Workbench/
│   ├── TesteoMeshFull.wbpj                    ◀ proyecto actual
│   ├── TesteoSimulacion.wbpj
│   └── *_files/dp0/FFF/Fluent/*.out           Monitores
└── Imagenes/                                  Capturas de configuración
```

---

## Monitores de Fluent

Los `.out` tienen esta cabecera:

```
("Time Step" "<nombre>" "flow-time")
```

Texto plano de tres columnas. Para leerlos:

```python
import numpy as np

def leer_out(ruta):
    datos = np.loadtxt(ruta, skiprows=3)
    return datos[:, 0], datos[:, 1], datos[:, 2]  # paso, valor, tiempo

paso, torque, t = leer_out("report-def-0-rfile.out")

# Promedio sobre las últimas 4 revoluciones (240 pasos cada una)
print(f"Torque medio: {torque[-960:].mean():.5f} N·m")
```

Monitores definidos: `report-def-0` y `report-def-1` (torque), `mdot_inlet`,
`mdot_outlet`, `mdot_intf`, `vol_agua_entrada`, `vol_agua_descarga`,
`vol_agua_rotatoria`, `delta-time`, `iters_per_timestep`.

---

## Hoja de ruta

### Fase A — Corregir la geometría (bloqueante)

- [✓] Rehacer el CAD con patrón circular de **3 instancias** sobre 360°
- [✓] Verificar la tercera hélice en la fase **313°**
- [ ] Rehacer la operación booleana del dominio fluido
- [ ] Exportar STEP y confirmar **36 superficies B-spline**
- [ ] Volver a mallar

### Fase B — Corregir la configuración

- [ ] B1 — Quitar `artesa` de `report-def-0`; dejar solo `tornillo`
- [ ] B2 — `Average Over (Time Steps)` = **240**
- [ ] B3 — Redefinir `report-def-1` como torque **viscoso**
- [ ] B4 — Apuntar `mdot_intf` a `intf:01:entrada-...::int_rot_arriba`
- [ ] B5 — Subir `Max Iterations/Time Step` de 20 a **40**
- [ ] B6 — Revisar el esquema VOF (Explícito ⇒ Courant ≤ 0.25)
- [ ] B7 — Ejecutar `General → Check`
- [ ] B8 — `File → Write → Start Transcript` antes de correr

> **Sobre B1.** El reporte de momento actual incluye la pared `artesa`, que
> es estática. Su contribución cancela parte del torque real del rotor:
> 0.16621 N·m con artesa contra 0.18741 N·m solo con `tornillo`, una
> supresión del 11.3 %.

### Fase C — Correr hasta régimen

- [ ] dV/dt ≈ 0 con signo consistente
- [ ] Residual de continuidad < 10⁻⁵
- [ ] Error de conservación de agua < 1 %
- [ ] Activar `Data Sampling for Time Statistics` **solo ya en régimen**
- [ ] Promediar sobre **4 revoluciones**, con < 0.5 % entre consecutivas

### Fase D — Independencia de malla

- [ ] Tres mallas: ~0.7 M / 1.4 M / 2.2 M celdas, con r ≥ 1.3
- [ ] Extrapolación de Richardson + GCI (ASME V&V 20)
- [ ] Reportar el torque como **C ± GCI**

---

## Nota metodológica: la pregunta de la regresión

Surgió la propuesta de hacer una regresión lineal sobre los resultados y
proyectar el valor que se obtendría con más capacidad de cómputo. Conviene
precisar sobre qué variable.

**Sobre el tiempo de simulación no es válido.** Una serie temporal de torque
no tiende asintóticamente a un valor por extrapolación lineal: oscila
periódicamente alrededor de una media. Una regresión sobre 19 valores
consecutivos dio pendiente +0.001116/paso con **R² = 0.098** y t ≈ 1.36, sin
significancia estadística. No hay tendencia; hay ruido.

**Sobre el refinamiento de malla sí es el procedimiento correcto**, y es
precisamente la Fase D. Aplicado a la tabla de mallas de Dellinger
(2.4M/5.0M/8.8M → 0.2423/0.2370/0.2360):

```
r₂₁ = 1.207     p = 7.8 (fuera del rango asintótico)
C(h→0) = 0.2357 N·m     GCI₂₁ = 0.16 %
```

El refinamiento es **monótonamente decreciente**: refinar más la malla no
puede hacer subir el torque, converge por debajo. La diferencia con el
experimento no se cierra con más celdas, se cierra corrigiendo la geometría.

---

## Referencia principal

G. Dellinger, P.-A. Garambois, M. Dufresne, A. Terfous, J. Vazquez,
A. Ghenaim (2018). Numerical and experimental study of an Archimedean Screw
Generator. *Renewable Energy* **118**, 847–857.

Tabla de mallas del paper (torque en N·m / eficiencia):

| Celdas | Torque | η |
|---|---|---|
| 1.4 M | 0.2482 | 0.7785 |
| 2.4 M | 0.2423 | 0.7600 |
| 5.0 M | 0.2370 | 0.7434 |
| 8.8 M | 0.2360 | 0.7387 |
