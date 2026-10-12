import 'package:flutter_scene/build_hooks.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
// flutter_scene:init:start
    // Every model the game loads, by source path (loadScene).
    buildScenes(
      buildInput: input,
      buildOutput: output,
      inputFilePaths: const [
        'assets/models/characters/keeper.glb',
        'assets/models/enemies/basher.glb',
        'assets/models/enemies/burrower.glb',
        'assets/models/enemies/glassback.glb',
        'assets/models/enemies/moth_crab.glb',
        'assets/models/enemies/sand_mound.glb',
        'assets/models/enemies/scuttler.glb',
        'assets/models/enemies/snuffer.glb',
        'assets/models/enemies/tarback.glb',
        'assets/models/enemies/tide_mother.glb',
        'assets/models/environment/barrel.glb',
        'assets/models/environment/buoy.glb',
        'assets/models/environment/cottage.glb',
        'assets/models/environment/crate.glb',
        'assets/models/environment/dock.glb',
        'assets/models/environment/driftwood_a.glb',
        'assets/models/environment/driftwood_b.glb',
        'assets/models/environment/fence_section.glb',
        'assets/models/environment/fishing_net.glb',
        'assets/models/environment/grass_tuft.glb',
        'assets/models/environment/island.glb',
        'assets/models/environment/lighthouse.glb',
        'assets/models/environment/rocks_a.glb',
        'assets/models/environment/rocks_b.glb',
        'assets/models/environment/rocks_c.glb',
        'assets/models/fx/beam_cone.glb',
        'assets/models/fx/burn_puddle.glb',
        'assets/models/fx/flame_card.glb',
        'assets/models/fx/lamp_cone.glb',
        'assets/models/fx/tar_splat.glb',
        'assets/models/placeables/bell.glb',
        'assets/models/placeables/lamp_post.glb',
        'assets/models/placeables/mirror.glb',
        'assets/models/placeables/prism.glb',
        'assets/models/weapons/chain_link.glb',
        'assets/models/weapons/harpoon_bolt.glb',
        'assets/models/weapons/harpoon_gun.glb',
        'assets/models/weapons/oil_lamp.glb',
      ],
    );
    // Compile .fmat materials under assets/, loadable by source path with
    // loadFmatMaterial (and hot-reloadable). A no-op when there are none.
    await buildMaterials(buildInput: input, buildOutput: output);
// flutter_scene:init:end
  });
}
