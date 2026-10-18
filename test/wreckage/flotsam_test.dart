import 'package:flutter_test/flutter_test.dart';
import 'package:last_light/common/events.dart';
import 'package:last_light/common/inputs.dart';
import 'package:last_light/common/grid.dart';
import 'package:last_light/features/island/island.dart';
import 'package:last_light/features/wreckage/wreckage.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';
import 'package:vector_math/vector_math.dart';

import '../support/harness.dart';

void main() {
  late TestGame game;
  final landed = <FlotsamLanded>[];

  setUp(() {
    landed.clear();
    game = makeGame(probes: [collect(landed)])
      ..quietNight()
      ..pinBeam(on: false);
  });

  (Entity, SceneTransform) firstFlotsam() {
    game.seconds(flotsamFirst + 0.5);
    final rows = game.world.query2<Flotsam, SceneTransform>().snapshot();
    expect(rows, hasLength(1));
    return (rows.single.$1, rows.single.$3);
  }

  test('the tide brings flotsam in off a beach, out on open water', () {
    final (_, t) = firstFlotsam();
    final grid = game.world.resource<HeightGrid>();
    expect(grid.sample(t.x, t.z), lessThan(flotsamDepth));
  });

  test('left alone, flotsam sinks', () {
    final (e, _) = firstFlotsam();
    game.seconds(flotsamSeconds);
    expect(game.world.isAlive(e), isFalse);
  });

  test('harpooned flotsam is hauled up the beach and lies there as wreckage',
      () {
    final (_, f) = firstFlotsam();
    final grid = game.world.resource<HeightGrid>();
    final centre = game.world.resource<IslandAnchors>().lighthouse;
    // Walk in from the float toward the tower to the first dry sand, and
    // stand a couple of metres up it.
    final dx = centre.x - f.x, dz = centre.z - f.z;
    final len = Vector2(dx, dz).length;
    var (x, z) = (f.x, f.z);
    for (var d = 0.0; d < len; d += 0.5) {
      (x, z) = (f.x + dx / len * d, f.z + dz / len * d);
      if (grid.walkableXZ(x, z) && grid.sample(x, z) > 0.3) {
        (x, z) = (x + dx / len * 2, z + dz / len * 2);
        break;
      }
    }
    expect(distSq2(x, z, f.x, f.z), lessThan(18 * 18));
    game
      ..placeKeeper(x, z)
      ..aimAt(f.x, f.z);
    game.world.buttons<KeeperAction>().press(KeeperAction.harpoon);
    game.seconds(0.1);
    game.world.buttons<KeeperAction>().release(KeeperAction.harpoon);
    game.seconds(4);
    game.frame();
    expect(game.world.query<Flotsam>().count(), 0);
    expect(landed, hasLength(1));
    final wreck = game.world.query2<Wreck, SceneTransform>().snapshot().where(
        (w) => distSq2(w.$3.x, w.$3.z, landed.single.position.x,
                landed.single.position.z) < 0.01);
    expect(wreck, hasLength(1));
    expect(grid.walkableXZ(wreck.single.$3.x, wreck.single.$3.z), isTrue);
  });
}
