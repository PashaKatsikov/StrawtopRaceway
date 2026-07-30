import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strawtop_raceway/data/catalog.dart';
import 'package:strawtop_raceway/data/game_state.dart';
import 'package:strawtop_raceway/game/race_engine.dart';

/// The board is the whole game: the racer and every spawned entity must stay
/// inside the wooden lane between the rope rails, never out over the scenery.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues(<String, Object>{});

  const sizes = <Size>[
    Size(852, 393), // phone landscape
    Size(393, 852), // phone portrait
    Size(1180, 820), // tablet landscape
    Size(667, 375), // small phone landscape
  ];

  setUpAll(() async {
    await GameState.instance.init();
  });

  for (final size in sizes) {
    test('play field stays inside the board at $size', () {
      final level = Catalog.levels.first;
      final engine = RaceEngine(
        level: level,
        eventBonus: false,
        background: Catalog.locationById(level.locationId).background,
      );
      engine.size = size;
      engine.start();
      engine.readyCountdown = 0;
      for (int i = 0; i < 40; i++) {
        engine.update(1 / 60);
      }

      expect(engine.trackLeft, greaterThanOrEqualTo(0));
      expect(engine.trackLeft + engine.trackWidth,
          lessThanOrEqualTo(size.width + 0.01));
      expect(engine.innerWidth, greaterThan(0));

      // Sweep the steering hard against both rails while the race runs.
      for (int i = 0; i < 1500; i++) {
        engine.setTargetX(i.isEven ? -5000 : 5000);
        engine.update(1 / 60);
        if (engine.status != RaceStatus.running) break;

        // The racer sprite is drawn 20% wider than its collision circle.
        final half = engine.topRadius * 1.2;
        expect(engine.topX - half, greaterThanOrEqualTo(engine.innerLeft),
            reason: 'racer crossed the left rail');
        expect(engine.topX + half, lessThanOrEqualTo(engine.innerRight),
            reason: 'racer crossed the right rail');

        for (final e in engine.entities) {
          expect(e.x - e.size / 2, greaterThanOrEqualTo(engine.innerLeft),
              reason: '${e.type} spawned over the left rail');
          expect(e.x + e.size / 2, lessThanOrEqualTo(engine.innerRight),
              reason: '${e.type} spawned over the right rail');
        }
      }
    });
  }
}
