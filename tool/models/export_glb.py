"""Exports a character .blend to .glb for the game.

Run headless:
  blender -b keeper.blend --python tool/models/export_glb.py -- out.glb

Exports only the Rig_Medium hierarchy (no reference images or scene
helpers) with every NLA track as a clip. If the blend's palette image is
missing, follow with tool/models/glb_add_palette.py to embed it."""

import bpy, sys
out = sys.argv[sys.argv.index("--") + 1]
rig = bpy.data.objects["Rig_Medium"]
for o in bpy.data.objects:
    o.select_set(False)
def select(o):
    o.select_set(True)
    for c in o.children:
        select(c)
select(rig)
bpy.context.view_layer.objects.active = rig
bpy.ops.export_scene.gltf(
    filepath=out,
    export_format='GLB',
    use_selection=True,
    export_animations=True,
    export_animation_mode='NLA_TRACKS',
    export_force_sampling=True,
    export_yup=True,
    export_apply=False,
    export_cameras=False,
    export_lights=False,
)
print("EXPORTED", out)
