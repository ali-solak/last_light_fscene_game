import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_light/common/settings.dart';
import 'package:last_light/ui/screens/settings_sheet.dart';
import 'package:scene_dash_v2/scene_dash_v2.dart';

void main() {
  for (final (name, size) in const [
    ('a landscape phone', Size(780, 360)),
    ('a desktop window', Size(1280, 800)),
  ]) {
    testWidgets('settings fit $name without overflow', (tester) async {
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final game = (await tester.runAsync(
        () => WorldGame.boot(features: [(g) => g.world.insert(Settings())]),
      ))!;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GameScope(game: game, child: const SettingsSheet()),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(SettingsSheet), findsOneWidget);
    });
  }
}
