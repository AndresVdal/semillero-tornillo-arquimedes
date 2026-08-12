"""
Generador parametrico de tornillo de Arquimedes + artesa + dominio fluido
Semillero SIIM - UPB Bucaramanga
Unidades: milimetros

v2 - anade dominio completo (camara de entrada + canal de descarga) dimensionado
     para 16 GB de RAM, y estimador de celdas/memoria.
"""
import math, os
import cadquery as cq

# =====================================================================
#  PARAMETROS  --  MODELO V (validacion, geometria de Dellinger 2018)
# =====================================================================
P = dict(
    nombre   = "V",
    Ra       = 96.0,    # radio exterior de la helice       [mm]
    Ri       = 52.0,    # radio interior / nucleo           [mm]
    S        = 192.0,   # paso                              [mm]
    LB       = 400.0,   # longitud roscada                  [mm]
    N        = 3,       # numero de entradas (alabes)
    t        = 2.0,     # espesor axial del alabe           [mm]
    gap      = 1.0,     # holgura alabe-artesa              [mm]
    e_artesa = 6.0,     # espesor de pared de la artesa     [mm]
    ext      = 25.0,    # prolongacion del nucleo (apoyos)  [mm]
    beta     = 24.0,    # inclinacion respecto a horizontal [grados]
    # --- dominio fluido (economizado para 16 GB) ---
    an_canal = 280.0,   # ancho del canal (Y)               [mm]
    L_entr   = 350.0,   # largo camara de entrada           [mm]
    L_desc   = 450.0,   # largo canal de descarga           [mm]
    h_aire   = 60.0,    # altura de aire sobre el nivel max [mm]
    h_fondo  = 70.0,    # fondo bajo la solera de la artesa [mm]
)

# --- presupuesto de mallado (para el estimador) ----------------------
MALLA = dict(
    s_alabe   = 1.5,    # tamano de cara en alabes y artesa [mm]
    s_nucleo  = 2.5,    # tamano de cara en el nucleo       [mm]
    s_cajas   = 8.0,    # tamano de celda en las cajas      [mm]
    n_prism   = 5,      # capas prismaticas
    n_gap     = 5,      # celdas radiales en la holgura
    ram_por_M = 2.0,    # GB de RAM por millon de celdas (VOF+SST, doble prec.)
    ram_total = 16.0,   # RAM de la maquina                 [GB]
    ram_so    = 4.0,    # RAM reservada al sistema operativo[GB]
)

# ---------------------------------------------------------------------
def sector_anular(Ri, Ra, dtheta_deg):
    """Corona circular truncada: seccion transversal del alabe en z=0."""
    a = math.radians(dtheta_deg)
    p0 = (Ri, 0.0)
    p1 = (Ra, 0.0)
    p2 = (Ra * math.cos(a), Ra * math.sin(a))
    p3 = (Ri * math.cos(a), Ri * math.sin(a))
    return (cq.Workplane("XY")
            .moveTo(*p0).lineTo(*p1)
            .radiusArc(p2, Ra)
            .lineTo(*p3)
            .radiusArc(p0, -Ri)
            .close())

def alabe(P, n_seg=6):
    """Helicoide solido por extrusion con torsion, en tramos para robustez."""
    dtheta = 360.0 * P["t"] / P["S"]
    L_seg  = P["LB"] / n_seg
    tw_seg = 360.0 * L_seg / P["S"]
    partes = []
    for i in range(n_seg):
        z0   = i * L_seg
        fase = 360.0 * z0 / P["S"]
        partes.append(sector_anular(P["Ri"], P["Ra"], dtheta)
                      .twistExtrude(L_seg, tw_seg)
                      .rotate((0, 0, 0), (0, 0, 1), fase)
                      .translate((0, 0, z0)))
    res = partes[0]
    for s in partes[1:]:
        res = res.union(s)
    return res

def inclinar(obj, P):
    """Eje: de +Z local a inclinado beta; extremo alto (aguas arriba) hacia -X."""
    return obj.rotate((0, 0, 0), (0, 1, 0), -(90.0 - P["beta"]))

def construir(P):
    Ra, Ri, ext, LB, gap = P["Ra"], P["Ri"], P["ext"], P["LB"], P["gap"]
    r_int = Ra + gap
    b     = math.radians(P["beta"])

    # --- tornillo -----------------------------------------------------
    tornillo = (cq.Workplane("XY").workplane(offset=-ext)
                .circle(Ri).extrude(LB + 2 * ext))
    base = alabe(P)
    for k in range(P["N"]):
        tornillo = tornillo.union(base.rotate((0, 0, 0), (0, 0, 1), k * 360.0 / P["N"]))

    # --- artesa -------------------------------------------------------
    artesa = (cq.Workplane("XY").circle(r_int + P["e_artesa"]).circle(r_int)
              .extrude(LB))

    # --- zona rotatoria: fluido dentro de la artesa --------------------
    rotatoria = cq.Workplane("XY").circle(r_int).extrude(LB).cut(tornillo)

    # --- semiespacios de corte (en marco local, luego se inclinan) -----
    BIG = 6000.0
    corte_arriba = (cq.Workplane("XY").workplane(offset=-BIG)
                    .rect(BIG, BIG).extrude(BIG + LB))        # z_local < LB
    corte_abajo  = (cq.Workplane("XY").rect(BIG, BIG).extrude(BIG))  # z_local > 0

    # --- geometria inclinada ------------------------------------------
    tor_i = inclinar(tornillo, P)
    art_i = inclinar(artesa, P)
    rot_i = inclinar(rotatoria, P)
    ca_i  = inclinar(corte_arriba, P)
    cb_i  = inclinar(corte_abajo, P)

    # --- puntos clave --------------------------------------------------
    x_hi, z_hi = -LB * math.cos(b), LB * math.sin(b)
    dz = r_int * math.cos(b)          # semialtura de las caras de artesa
    dx = r_int * math.sin(b)
    an = P["an_canal"] / 2.0

    # --- camara de entrada (aguas arriba, -X) --------------------------
    z0 = z_hi - dz - P["h_fondo"]
    z1 = z_hi + dz + P["h_aire"]
    entrada = (cq.Workplane("XY")
               .center((x_hi + dx - P["L_entr"] / 2) - P["L_entr"] / 2 + P["L_entr"] / 2, 0)
               .box(P["L_entr"] + 2 * dx, 2 * an, z1 - z0, centered=(True, True, False))
               .translate((x_hi + dx - (P["L_entr"] + 2 * dx) / 2
                           - (x_hi + dx - P["L_entr"] / 2) + (x_hi + dx - P["L_entr"] / 2), 0, z0)))
    # reposicionar limpio
    entrada = (cq.Workplane("XY")
               .box(P["L_entr"], 2 * an, z1 - z0, centered=(False, True, False))
               .translate((x_hi + dx - P["L_entr"], 0, z0)))
    entrada = entrada.cut(ca_i).cut(tor_i)

    # --- canal de descarga (aguas abajo, +X) ---------------------------
    z2 = -dz - P["h_fondo"]
    z3 = dz + P["h_aire"]
    descarga = (cq.Workplane("XY")
                .box(P["L_desc"], 2 * an, z3 - z2, centered=(False, True, False))
                .translate((-dx, 0, z2)))
    descarga = descarga.cut(cb_i).cut(tor_i)

    return tor_i, art_i, rot_i, entrada, descarga

# =====================================================================
def estimar_malla(P, M):
    """Estimacion de orden de magnitud del numero de celdas y la RAM."""
    Ra, Ri, LB, gap = P["Ra"], P["Ri"], P["LB"], P["gap"]
    r_int = Ra + gap
    nv = LB / P["S"]

    # area de los alabes (helicoide, ambas caras)
    pend = math.sqrt(1 + (P["S"] / (2 * math.pi * Ra)) ** 2)
    A_al = 2 * math.pi * (Ra**2 - Ri**2) * nv * P["N"] * pend
    A_nu = 2 * math.pi * Ri * (LB + 2 * P["ext"])
    A_ar = 2 * math.pi * r_int * LB

    c_al = A_al / M["s_alabe"]**2
    c_nu = A_nu / M["s_nucleo"]**2
    c_ar = A_ar / M["s_alabe"]**2
    caras = c_al + c_nu + c_ar
    prismas = caras * M["n_prism"]

    # celdas en la holgura (anisotropas: gap/n_gap radial x s_alabe tangencial)
    V_gap = math.pi * (r_int**2 - Ra**2) * LB
    v_gap = (gap / M["n_gap"]) * M["s_alabe"] ** 2
    c_gap = V_gap / v_gap

    # nucleo poliedrico/hexcore del resto
    V_rot = math.pi * r_int**2 * LB
    V_lib = max(V_rot - V_gap, 0) * 0.6
    c_lib = V_lib / (M["s_alabe"] * 2) ** 3

    an = P["an_canal"]
    V_cajas = an * (P["L_entr"] + P["L_desc"]) * 300.0
    c_caj = V_cajas / M["s_cajas"] ** 3

    total = prismas + c_gap + c_lib + c_caj
    ram = total / 1e6 * M["ram_por_M"]
    disp = M["ram_total"] - M["ram_so"]
    return dict(caras=caras, prismas=prismas, gap=c_gap, libre=c_lib,
                cajas=c_caj, total=total, ram=ram, disp=disp,
                cabe=ram <= disp, techo=disp / M["ram_por_M"] * 1e6)

# =====================================================================
if __name__ == "__main__":
    out = "/mnt/user-data/outputs/modelo_V"
    os.makedirs(out, exist_ok=True)
    n = P["nombre"]

    tor, art, rot, ent, des = construir(P)

    for obj, nom in ((tor, f"tornillo_{n}"), (art, f"artesa_{n}"),
                     (rot, f"fluido_rotatorio_{n}"),
                     (ent, f"fluido_camara_entrada_{n}"),
                     (des, f"fluido_canal_descarga_{n}")):
        cq.exporters.export(obj.val(), f"{out}/{nom}.step")
    cq.exporters.export(tor.val(), f"{out}/tornillo_{n}.stl",
                        tolerance=0.02, angularTolerance=0.1)

    dom = rot.union(ent).union(des)
    cq.exporters.export(dom.val(), f"{out}/dominio_completo_{n}.step")

    # ------------------- verificacion -------------------------------
    import numpy as np
    print("=" * 64)
    print("VERIFICACION GEOMETRICA")
    print("=" * 64)
    sol = tor.val()
    verts, _ = sol.tessellate(0.01)
    v = np.array([[p.x, p.y, p.z] for p in verts])
    b = math.radians(P["beta"])
    u = np.array([math.cos(b), 0.0, -math.sin(b)])
    s = v @ u                                   # coordenada axial
    rad = np.linalg.norm(v - np.outer(s, u), axis=1)
    print(f"Radio exterior maximo : {rad.max():.4f} mm   (Ra = {P['Ra']:.1f})")
    print("Radio por estacion axial (medido sobre el modelo ya inclinado):")
    for sa in np.linspace(-380, -40, 5):
        m = np.abs(s - sa) < 8.0
        if m.sum() > 10:
            print(f"   s = {abs(sa):6.1f} mm  ->  r_max = {rad[m].max():8.4f} mm")

    V = {"tornillo": sol.Volume(), "rotatoria": rot.val().Volume(),
         "entrada": ent.val().Volume(), "descarga": des.val().Volume()}
    print()
    for k, x in V.items():
        print(f"Volumen {k:<12}: {x/1e6:9.3f} L")
    print(f"Volumen fluido TOTAL : {(V['rotatoria']+V['entrada']+V['descarga'])/1e6:9.3f} L")

    V_paso = V["rotatoria"] / 1e6 / (P["LB"] / P["S"])
    print(f"\nVolumen libre por paso: {V_paso:8.4f} L")
    print(f"Q_nom a  70 rpm (f=0.5): {0.5*V_paso*70/60:6.3f} L/s"
          f"   (Dellinger: 2.32 L/s)")

    # ------------------- presupuesto de malla ------------------------
    E = estimar_malla(P, MALLA)
    print("\n" + "=" * 64)
    print("PRESUPUESTO DE MALLA Y MEMORIA  (16 GB, poly-hexcore)")
    print("=" * 64)
    print(f"Caras de superficie          : {E['caras']/1e3:8.0f} k")
    print(f"Celdas prismaticas           : {E['prismas']/1e6:8.2f} M")
    print(f"Celdas en la holgura         : {E['gap']/1e6:8.2f} M")
    print(f"Celdas hexcore (artesa)      : {E['libre']/1e6:8.2f} M")
    print(f"Celdas en las cajas          : {E['cajas']/1e6:8.2f} M")
    print(f"{'TOTAL ESTIMADO':<29}: {E['total']/1e6:8.2f} M celdas")
    print(f"RAM estimada                 : {E['ram']:8.2f} GB"
          f"   (disponible {E['disp']:.0f} GB)")
    print(f"Techo de celdas con 16 GB    : {E['techo']/1e6:8.2f} M")
    print(f"Veredicto                    : {'CABE' if E['cabe'] else 'NO CABE -> ver ajustes'}")
    if not E["cabe"]:
        f = (E["techo"] / E["total"]) ** (1 / 3)
        print(f"\n  Ajuste sugerido: multiplicar los tamanos de cara por {1/f:.2f}")
        print(f"     s_alabe {MALLA['s_alabe']:.1f} -> {MALLA['s_alabe']/f:.1f} mm")
        print(f"     s_cajas {MALLA['s_cajas']:.1f} -> {MALLA['s_cajas']/f:.1f} mm")
        print(f"     o reducir capas prismaticas de {MALLA['n_prism']} a 3")

    # ------------------- datos para Fluent ---------------------------
    p_low, p_high = (0., 0., 0.), (-P["LB"]*math.cos(b), 0., P["LB"]*math.sin(b))
    print("\n" + "=" * 64)
    print("DATOS PARA ANSYS FLUENT  (gravedad = -Z)")
    print("=" * 64)
    print(f"Eje de rotacion, direccion : ({u[0]:.6f}, {u[1]:.6f}, {u[2]:.6f})")
    print(f"Eje de rotacion, origen [m]: (0.000000, 0.000000, 0.000000)")
    print(f"Extremo aguas arriba    [m]: ({p_high[0]/1000:.6f}, 0.000000, {p_high[2]/1000:.6f})")
    print(f"Extremo aguas abajo     [m]: (0.000000, 0.000000, 0.000000)")
    print(f"Salto por vuelta        [m]: {P['S']*math.sin(b)/1000:.4f}")
    print(f"Desnivel entre extremos [m]: {P['LB']*math.sin(b)/1000:.4f}")

    print("\nArchivos en", out)
    for f in sorted(os.listdir(out)):
        print(f"   {f:<34} {os.path.getsize(os.path.join(out,f))/1024:7.0f} kB")
