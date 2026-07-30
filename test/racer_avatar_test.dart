import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strawtop_raceway/data/game_state.dart';
import 'package:strawtop_raceway/widgets/racer_avatar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    await GameState.instance.init();
    await GameState.instance.clearAvatarPhoto();
  });

  ImageProvider? providerOf(WidgetTester tester) =>
      tester.widgetList<Image>(find.byType(Image)).firstOrNull?.image;

  testWidgets('shows the default art until a photo is picked', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RacerAvatar(size: 40))),
    );
    expect(providerOf(tester), isA<AssetImage>());
  });

  testWidgets('a const instance still refreshes when the photo changes',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RacerAvatar(size: 40))),
    );
    expect(providerOf(tester), isA<AssetImage>());

    // A 1x1 transparent PNG.
    await GameState.instance.setAvatarPhoto(_onePixelPng);
    await tester.pump();

    expect(providerOf(tester), isA<MemoryImage>());
  });
}

final _onePixelPng = Uint8List.fromList(<int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
  0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4,
  0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE,
  0x42, 0x60, 0x82,
]);
