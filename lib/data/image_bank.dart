import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

/// Decodes and caches raw [ui.Image] objects so the game engine can draw
/// them directly onto a canvas (needed for sprite-sheet slicing).
class ImageBank {
  ImageBank._();
  static final ImageBank instance = ImageBank._();

  final Map<String, ui.Image> _cache = {};

  ui.Image? get(String asset) => _cache[asset];

  Future<ui.Image> load(String asset) async {
    final cached = _cache[asset];
    if (cached != null) return cached;
    final data = await rootBundle.load(asset);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    _cache[asset] = frame.image;
    return frame.image;
  }

  Future<void> loadAll(Iterable<String> assets) async {
    for (final a in assets) {
      try {
        await load(a);
      } catch (_) {
        // A missing asset should never crash the loader.
      }
    }
  }
}

/// Named source rectangles carved out of `effects.webp` (a 1024x1024 sheet).
/// Used for the dust trail, jump puffs and crash bursts.
class FxSheet {
  static const double sheet = 1024;

  static const Rect puffBig = Rect.fromLTWH(24, 24, 380, 220);
  static const Rect puffMed = Rect.fromLTWH(430, 90, 220, 150);
  static const Rect puffSmall = Rect.fromLTWH(650, 120, 150, 110);
  static const Rect puffTiny = Rect.fromLTWH(820, 150, 150, 90);
  static const Rect burst = Rect.fromLTWH(40, 300, 320, 200);
  static const Rect ring = Rect.fromLTWH(360, 300, 300, 190);
  static const Rect dustTrail = Rect.fromLTWH(40, 690, 300, 100);
}
