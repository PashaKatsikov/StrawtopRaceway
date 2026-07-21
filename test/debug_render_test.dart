import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strawtop_raceway/data/assets.dart';
import 'package:strawtop_raceway/data/image_bank.dart';
import 'package:strawtop_raceway/data/models.dart';
import 'package:strawtop_raceway/game/race_engine.dart';
import 'package:strawtop_raceway/game/race_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('render race frame to png', (tester) async {
    await tester.runAsync(() async {
      await ImageBank.instance.loadAll([
        A.directRoad, A.finish, A.pencil, A.eraser, A.springboard,
        A.coin, A.star, A.powerUp, A.shieldBuff, A.beckonsBuff, A.iceBuff,
        A.effects, A.topDefault, A.kitchenBg,
      ]);
    });

    const level = GameLevel(
      id: 'kitchen_0',
      locationId: 'kitchen',
      index: 0,
      name: 'Warm-Up',
      distance: 2600,
      difficulty: 1,
      coinReward: 60,
      obstacleRate: 0.014,
      pickupRate: 0.02,
    );
    final engine = RaceEngine(
      level: level,
      eventBonus: false,
      background: A.kitchenBg,
    );
    engine.start();
    engine.status = RaceStatus.running;
    // Force some entities near edges to inspect bounds visually.
    engine.size = const Size(412, 915);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = RacePainter(engine);
    painter.paint(canvas, const Size(412, 915));
    final picture = recorder.endRecording();
    final img = await picture.toImage(412, 915);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final file = File('debug_render.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List());
  });
}
