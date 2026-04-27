"""
split_character.py - Fragmenta un personaje GLB en partes articuladas + UnderSuit.

USO:
1. Blender > File > Import > glTF 2.0 > <tu_modelo>.glb
2. Pestaña "Scripting" > Open Text > navegar a este archivo
3. PRIMERA CORRIDA (Alt+P): la consola imprime los bounds del modelo.
   Toggle System Console: Window > Toggle System Console (en Windows).
4. Ajustar las constantes CONFIG segun esos bounds.
5. File > Revert (vuelve al GLB original sin cambios), corres de nuevo.
6. Output: character_split.glb al lado del .blend (o donde apunte OUTPUT_PATH).
"""

import bpy
import bmesh
import mathutils

# ===================== CONFIG - CALIBRADO PARA capibara_player.glb =================
# El GLB de Meshy viene normalizado a Z [-1, 1] (centro en 0).
HIP_Z      =  0.00   # pelvis <-> piernas
KNEE_Z     = -0.50   # muslo <-> pantorrilla
ANKLE_Z    = -0.85   # pantorrilla <-> pie
SHOULDER_Z =  0.65   # torso <-> brazos
ELBOW_Z    =  0.25   # brazo <-> antebrazo
WRIST_Z    = -0.15   # antebrazo <-> mano
NECK_Z     =  0.75   # torso <-> cabeza
ARM_X_MIN  =  0.30   # |x| > este -> brazo (no torso)
# LEG_X_MIN = 0.0 → toda la geometria bajo HIP_Z se asigna a una pierna
# u otra segun el signo de X. Esto evita que la "parte interior" de la
# pierna quede atascada en el Torso (causa de "exterior estatico" al caminar).
LEG_X_MIN  =  0.0

# UnderSuit ELIMINADO (creaba "fantasma duplicado" del cuerpo). Las articulaciones
# ahora se cubren con joint spheres negras + thickness en cada parte (Solidify).
JOINT_COLOR     = (0.02, 0.02, 0.02, 1.0)   # negro mate del traje tactico
JOINT_ROUGHNESS = 0.9
SOLIDIFY_DEPTH  = 0.015   # grosor que se le da a cada parte para cerrar interiores
# Ruta absoluta al output.
OUTPUT_PATH = r"C:\Users\DROMA\Documents\GitRepos\world-farm\assets\models\characters\capibara_player_split.glb"
# =================================================================================

INF = 9999.0


def print_bounds(obj):
    bbox = [obj.matrix_world @ mathutils.Vector(c) for c in obj.bound_box]
    print("  Z (vertical): [%.3f, %.3f]" % (min(v.z for v in bbox), max(v.z for v in bbox)))
    print("  X (lateral) : [%.3f, %.3f]" % (min(v.x for v in bbox), max(v.x for v in bbox)))
    print("  Y (profund.): [%.3f, %.3f]" % (min(v.y for v in bbox), max(v.y for v in bbox)))


def select_faces_in_region(obj, z_min, z_max, x_sign, x_min_abs):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode='EDIT')
    bpy.ops.mesh.select_all(action='DESELECT')
    bm = bmesh.from_edit_mesh(obj.data)
    found = False
    for f in bm.faces:
        c = f.calc_center_median()
        in_z = z_min <= c.z < z_max
        if x_sign == 0:
            in_x = abs(c.x) <= x_min_abs
        elif x_sign > 0:
            in_x = c.x > x_min_abs
        else:
            in_x = c.x < -x_min_abs
        if in_z and in_x:
            f.select = True
            found = True
    bmesh.update_edit_mesh(obj.data)
    return found


def extract_region(source, name, z_min, z_max, x_sign=0, x_min_abs=0.0):
    if not select_faces_in_region(source, z_min, z_max, x_sign, x_min_abs):
        bpy.ops.object.mode_set(mode='OBJECT')
        return None
    bpy.ops.mesh.separate(type='SELECTED')
    bpy.ops.object.mode_set(mode='OBJECT')
    new_obj = next(o for o in bpy.context.selected_objects if o != source and o.type == 'MESH')
    new_obj.name = name
    bpy.ops.object.select_all(action='DESELECT')
    source.select_set(True)
    bpy.context.view_layer.objects.active = source
    return new_obj


def set_origin_to_joint_top(obj):
    if obj is None:
        return
    bbox = [obj.matrix_world @ mathutils.Vector(c) for c in obj.bound_box]
    cx = sum(v.x for v in bbox) / 8
    cy = sum(v.y for v in bbox) / 8
    top_z = max(v.z for v in bbox)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.context.scene.cursor.location = mathutils.Vector((cx, cy, top_z))
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')


def make_black_material(name):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    if bsdf:
        bsdf.inputs["Base Color"].default_value = JOINT_COLOR
        bsdf.inputs["Roughness"].default_value = JOINT_ROUGHNESS
        if "Metallic" in bsdf.inputs:
            bsdf.inputs["Metallic"].default_value = 0.05
    return mat


def add_solidify_to_part(obj, depth):
    """Le agrega thickness a la parte para cerrar los interiores que quedan
    abiertos despues del split. Sin esto, cuando un miembro rota se ve
    'a traves' de la parte (interior hollow)."""
    if obj is None:
        return
    mod = obj.modifiers.new(name="Solidify", type='SOLIDIFY')
    mod.thickness = depth
    mod.offset = -1.0  # crece hacia adentro, no afuera (no engorda visualmente)
    mod.use_even_offset = True
    # Aplicar el modifier (lo bakea al mesh)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.modifier_apply(modifier=mod.name)


def apply_solid_material(obj, mat):
    """Reemplaza TODOS los slots de material con uno solo y fuerza
    cada poligono a usar slot 0. Sin esto, las caras que originalmente
    estaban asignadas a slots 1,2,3 (multi-material de Meshy) quedan
    sin material y renderizan en BLANCO."""
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.material_index = 0


def add_joint_filler(parent_obj, child_obj, radius, mat, name_prefix="Joint"):
    """Esfera negra en el origen del child_obj (la articulacion), parented al
    parent_obj. Cubre el hueco visible en la juntura cuando los miembros rotan."""
    if child_obj is None or parent_obj is None:
        return None
    world_pos = child_obj.matrix_world.translation.copy()
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=radius, location=world_pos, segments=16, ring_count=8
    )
    sphere = bpy.context.active_object
    sphere.name = "%s_%s" % (name_prefix, child_obj.name)
    apply_solid_material(sphere, mat)
    sphere.parent = parent_obj
    return sphere


def main():
    mesh = next((o for o in bpy.context.scene.objects if o.type == 'MESH'), None)
    if mesh is None:
        print("X No hay mesh en la escena. File > Import > glTF 2.0 primero.")
        return

    print("=" * 60)
    print("BOUNDS del modelo (usa estos para calibrar CONFIG):")
    print_bounds(mesh)
    print("=" * 60)

    # 1. Extraer partes del original (mas articulado que antes: 13 partes)
    bpy.ops.object.select_all(action='DESELECT')
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh

    head      = extract_region(mesh, "Head",      NECK_Z,   INF,      0,  INF)
    arm_l     = extract_region(mesh, "ArmL",      ELBOW_Z,  NECK_Z,  -1,  ARM_X_MIN)
    arm_r     = extract_region(mesh, "ArmR",      ELBOW_Z,  NECK_Z,  +1,  ARM_X_MIN)
    forearm_l = extract_region(mesh, "ForearmL", WRIST_Z,   ELBOW_Z, -1,  ARM_X_MIN)
    forearm_r = extract_region(mesh, "ForearmR", WRIST_Z,   ELBOW_Z, +1,  ARM_X_MIN)
    hand_l    = extract_region(mesh, "HandL",   -INF,       WRIST_Z, -1,  ARM_X_MIN)
    hand_r    = extract_region(mesh, "HandR",   -INF,       WRIST_Z, +1,  ARM_X_MIN)
    thigh_l   = extract_region(mesh, "ThighL",   KNEE_Z,    HIP_Z,   -1,  LEG_X_MIN)
    thigh_r   = extract_region(mesh, "ThighR",   KNEE_Z,    HIP_Z,   +1,  LEG_X_MIN)
    shin_l    = extract_region(mesh, "ShinL",    ANKLE_Z,   KNEE_Z,  -1,  LEG_X_MIN)
    shin_r    = extract_region(mesh, "ShinR",    ANKLE_Z,   KNEE_Z,  +1,  LEG_X_MIN)
    foot_l    = extract_region(mesh, "FootL",   -INF,       ANKLE_Z, -1,  LEG_X_MIN)
    foot_r    = extract_region(mesh, "FootR",   -INF,       ANKLE_Z, +1,  LEG_X_MIN)

    mesh.name = "Torso"

    parts = [head, arm_l, arm_r, forearm_l, forearm_r, hand_l, hand_r,
             thigh_l, thigh_r, shin_l, shin_r, foot_l, foot_r]

    # 2. Pivotes (origen) en la articulacion superior de cada parte
    for p in parts:
        set_origin_to_joint_top(p)

    # 3. Solidify: cierra los interiores huecos de cada parte (incluido Torso)
    # asi cuando un miembro rota no se ve "a traves" del corte.
    for p in parts + [mesh]:
        add_solidify_to_part(p, SOLIDIFY_DEPTH)

    # 4. Jerarquia: TODO bajo Torso (mesh) para que el body sway arrastre
    # cabeza/brazos/piernas. Forearms hijos de Arms. Hands hijos de Forearms.
    # Shins hijos de Thighs. Feet hijos de Shins.
    for p in [head, arm_l, arm_r, thigh_l, thigh_r]:
        if p:
            p.parent = mesh
    if forearm_l and arm_l: forearm_l.parent = arm_l
    if forearm_r and arm_r: forearm_r.parent = arm_r
    if hand_l and forearm_l: hand_l.parent = forearm_l
    if hand_r and forearm_r: hand_r.parent = forearm_r
    if shin_l and thigh_l:  shin_l.parent = thigh_l
    if shin_r and thigh_r:  shin_r.parent = thigh_r
    if foot_l and shin_l:   foot_l.parent = shin_l
    if foot_r and shin_r:   foot_r.parent = shin_r

    # 5. Joint spheres negras en CADA articulacion (cuello, hombros, codos,
    # munecas, caderas, rodillas, tobillos). Cubren los huecos cuando los
    # miembros rotan.
    joint_mat = make_black_material("JointBlack")
    R_NECK     = 0.10
    R_SHOULDER = 0.12
    R_ELBOW    = 0.08
    R_WRIST    = 0.06
    R_HIP      = 0.12
    R_KNEE     = 0.08
    R_ANKLE    = 0.06

    add_joint_filler(mesh,      head,      R_NECK,     joint_mat, "Neck")
    add_joint_filler(mesh,      arm_l,     R_SHOULDER, joint_mat, "Shoulder")
    add_joint_filler(mesh,      arm_r,     R_SHOULDER, joint_mat, "Shoulder")
    add_joint_filler(arm_l,     forearm_l, R_ELBOW,    joint_mat, "Elbow")
    add_joint_filler(arm_r,     forearm_r, R_ELBOW,    joint_mat, "Elbow")
    add_joint_filler(forearm_l, hand_l,    R_WRIST,    joint_mat, "Wrist")
    add_joint_filler(forearm_r, hand_r,    R_WRIST,    joint_mat, "Wrist")
    add_joint_filler(mesh,      thigh_l,   R_HIP,      joint_mat, "Hip")
    add_joint_filler(mesh,      thigh_r,   R_HIP,      joint_mat, "Hip")
    add_joint_filler(thigh_l,   shin_l,    R_KNEE,     joint_mat, "Knee")
    add_joint_filler(thigh_r,   shin_r,    R_KNEE,     joint_mat, "Knee")
    add_joint_filler(shin_l,    foot_l,    R_ANKLE,    joint_mat, "Ankle")
    add_joint_filler(shin_r,    foot_r,    R_ANKLE,    joint_mat, "Ankle")

    # 6. Exportar
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(
        filepath=OUTPUT_PATH,
        export_format='GLB',
        use_selection=True,
        export_apply=True,
    )

    print()
    print("OK Exportado: %s" % OUTPUT_PATH)
    print("Partes: %s" % [o.name for o in bpy.context.scene.objects if o.type == 'MESH'])


main()
