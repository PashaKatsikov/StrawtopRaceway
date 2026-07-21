import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../data/assets.dart';
import '../data/image_bank.dart';
import '../theme/app_theme.dart';
import 'race_engine.dart';

class RacePainter extends CustomPainter {
  RacePainter(this.engine) : super(repaint: engine);

  final RaceEngine engine;
  final ImageBank bank = ImageBank.instance;

  // Source regions sampled from direct_road.webp (a framed board sprite).
  // We deliberately avoid the rope corners so vertical tiling is seamless.
  static const double _woodL = 0.150;
  static const double _woodR = 0.850;
  static const double _woodT = 0.275;
  static const double _woodB = 0.385;
  static const double _railLL = 0.055;
  static const double _railLR = 0.140;
  static const double _railRL = 0.860;
  static const double _railRR = 0.945;
  static const double _railT = 0.300;
  static const double _railB = 0.580;

  @override
  void paint(Canvas canvas, Size size) {
    engine.size = size;
    _paintBackground(canvas, size);
    _paintRoad(canvas, size);
    _paintChevrons(canvas, size);
    _paintStartFinish(canvas, size);
    _paintPuffs(canvas);
    _paintEntities(canvas);
    _paintTop(canvas, size);
    if (engine.hitFlash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = Colors.red.withValues(alpha: engine.hitFlash * 0.35),
      );
    }
  }

  void _paintBackground(Canvas canvas, Size size) {
    final bg = bank.get(engine.background);
    final paint = Paint()..filterQuality = FilterQuality.low;
    if (bg != null) {
      // Cover-fit the location background so it fills the gutters.
      final scale =
          math.max(size.width / bg.width, size.height / bg.height);
      final dw = bg.width * scale;
      final dh = bg.height * scale;
      final dx = (size.width - dw) / 2;
      final dy = (size.height - dh) / 2;
      canvas.drawImageRect(
        bg,
        Rect.fromLTWH(0, 0, bg.width.toDouble(), bg.height.toDouble()),
        Rect.fromLTWH(dx, dy, dw, dh),
        paint,
      );
      // Gentle darkening so gameplay elements read clearly.
      canvas.drawRect(Offset.zero & size,
          Paint()..color = AppColors.navyDeep.withValues(alpha: 0.28));
    } else {
      canvas.drawRect(Offset.zero & size,
          Paint()..color = AppColors.navyDeep);
    }
  }

  void _paintRoad(Canvas canvas, Size size) {
    final road = bank.get(A.directRoad);
    final scroll = engine.distance;

    // Soft shadow of the board onto the table.
    final boardRect = Rect.fromLTWH(
        engine.trackLeft - 6, 0, engine.trackWidth + 12, size.height);
    canvas.drawRect(
      boardRect,
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );

    if (road == null) {
      canvas.drawRect(
          Rect.fromLTWH(engine.innerLeft, 0, engine.innerWidth, size.height),
          Paint()..color = const Color(0xFF8A5A2B));
      return;
    }
    final W = road.width.toDouble();
    final H = road.height.toDouble();

    // Wood lane (seamless, flip alternate tiles so plank seams line up).
    final woodSrc = Rect.fromLTRB(_woodL * W, _woodT * H, _woodR * W, _woodB * H);
    _tileVertical(
      canvas, road, woodSrc,
      engine.innerLeft, engine.innerWidth, scroll,
      size.height,
    );

    // Side rails.
    final railLSrc =
        Rect.fromLTRB(_railLL * W, _railT * H, _railLR * W, _railB * H);
    final railRSrc =
        Rect.fromLTRB(_railRL * W, _railT * H, _railRR * W, _railB * H);
    _tileVertical(canvas, road, railLSrc, engine.trackLeft, engine.railW,
        scroll, size.height);
    _tileVertical(canvas, road, railRSrc, engine.innerRight, engine.railW,
        scroll, size.height);
  }

  void _tileVertical(Canvas c, ui.Image img, Rect src, double x, double w,
      double scrollOffset, double screenH) {
    final tileH = w * (src.height / src.width);
    final paint = Paint()..filterQuality = FilterQuality.low;
    final startY = -tileH + (scrollOffset % tileH);
    int idx = 0;
    for (double y = startY; y < screenH; y += tileH) {
      final dst = Rect.fromLTWH(x, y, w, tileH);
      if (idx.isOdd) {
        c.save();
        c.translate(0, y + tileH / 2);
        c.scale(1, -1);
        c.translate(0, -(y + tileH / 2));
        c.drawImageRect(img, src, dst, paint);
        c.restore();
      } else {
        c.drawImageRect(img, src, dst, paint);
      }
      idx++;
    }
  }

  void _paintChevrons(Canvas canvas, Size size) {
    // Calm, sparse lane markers – one shape per marker (no doubled/overlapping
    // copies) and a wide gap between them so they read as gentle guidance
    // rather than a flickering strobe while scrolling fast. Each marker also
    // fades in near the top edge and out near the bottom, so they glide in and
    // out smoothly instead of popping on/off.
    const spacing = 560.0;
    final w = engine.innerWidth * 0.22;
    final cx = engine.innerLeft + engine.innerWidth / 2;
    final fade = size.height * 0.22;
    final offset = engine.distance % spacing;
    for (double y = size.height - offset + spacing; y > -80; y -= spacing) {
      // Triangular fade: 0 at the very edges, peak in the middle band.
      double a = 1.0;
      if (y < fade) a = (y / fade).clamp(0.0, 1.0);
      if (y > size.height - fade) {
        a = ((size.height - y) / fade).clamp(0.0, 1.0);
      }
      if (a <= 0.02) continue;
      final path = Path()
        ..moveTo(cx - w / 2, y)
        ..lineTo(cx, y - 20)
        ..lineTo(cx + w / 2, y)
        ..lineTo(cx + w / 2, y + 12)
        ..lineTo(cx, y - 8)
        ..lineTo(cx - w / 2, y + 12)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.22 * a)
          ..style = PaintingStyle.fill,
      );
    }
  }

  void _paintStartFinish(Canvas canvas, Size size) {
    final topScreenY = size.height * engine.topYFactor;
    final startY = topScreenY + engine.distance;
    final finishY = topScreenY - (engine.level.distance - engine.distance);
    if (startY > -80 && startY < size.height + 80) {
      _checkerBand(canvas, startY, accent: AppColors.green);
      _bandLabel(canvas, startY, 'START', AppColors.green);
    }
    if (finishY > -170 && finishY < size.height + 170) {
      _checkerBand(canvas, finishY, accent: AppColors.red);
      _finishBadge(canvas, finishY);
      _bandLabel(canvas, finishY, 'FINISH', AppColors.red);
    }
  }

  /// Small decorative sign; native aspect ratio is always preserved (never
  /// force-stretched to the road width) so the art never looks distorted.
  void _finishBadge(Canvas canvas, double centerY) {
    final img = bank.get(A.finish);
    if (img == null) return;
    const maxW = 220.0;
    const maxH = 130.0;
    double w = maxW;
    double h = w * img.height / img.width;
    if (h > maxH) {
      h = maxH;
      w = h * img.width / img.height;
    }
    final cx = engine.trackLeft + engine.trackWidth / 2;
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
      Rect.fromCenter(center: Offset(cx, centerY - 96), width: w, height: h),
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  /// A tidy little pill with the START/FINISH caption, floating just above
  /// the checkered band so it never overlaps or stretches across it.
  void _bandLabel(Canvas canvas, double centerY, String text, Color color) {
    final cx = engine.trackLeft + engine.trackWidth / 2;
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontFamily: 'Baloo',
          fontWeight: FontWeight.w900,
          fontSize: 18,
          letterSpacing: 2,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final center = Offset(cx, centerY - 36);
    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: tp.width + 32, height: 30),
      const Radius.circular(15),
    );
    canvas.drawRRect(pill, Paint()..color = color);
    canvas.drawRRect(
      pill,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = Colors.black.withValues(alpha: 0.45),
    );
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  /// Checkered starting/finish line spanning exactly the wooden lane (between
  /// the rails), so the ribbon matches the visible road width – not wider.
  void _checkerBand(Canvas canvas, double centerY, {required Color accent}) {
    final left = engine.innerLeft;
    final w = engine.innerWidth;
    const h = 34.0;
    final rect = Rect.fromLTWH(left, centerY - h / 2, w, h);

    canvas.drawRect(
      Rect.fromLTWH(left, centerY - h / 2 - 5, w, 5),
      Paint()..color = accent,
    );
    canvas.drawRect(
      Rect.fromLTWH(left, centerY + h / 2, w, 5),
      Paint()..color = accent,
    );

    const cols = 12;
    final cell = w / cols;
    const rows = 2;
    for (int r = 0; r < rows; r++) {
      for (int col = 0; col < cols; col++) {
        final black = (r + col).isEven;
        canvas.drawRect(
          Rect.fromLTWH(left + col * cell, centerY - h / 2 + r * (h / rows),
              cell, h / rows),
          Paint()..color = black ? Colors.black : Colors.white,
        );
      }
    }
    canvas.drawRect(
        rect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.black.withValues(alpha: 0.4));
  }

  void _paintPuffs(Canvas canvas) {
    final fx = bank.get(A.effects);
    if (fx == null) return;
    final src = FxSheet.puffMed;
    for (final p in engine.puffs) {
      final s = 40.0 * p.scale;
      final paint = Paint()
        ..color =
            Colors.white.withValues(alpha: (p.life * 0.5).clamp(0.0, 0.5))
        ..filterQuality = FilterQuality.low;
      canvas.drawImageRect(
        fx,
        src,
        Rect.fromCenter(center: Offset(p.x, p.y), width: s, height: s * 0.7),
        paint,
      );
    }
  }

  void _paintEntities(Canvas canvas) {
    for (final e in engine.entities) {
      final asset = _assetFor(e);
      final img = bank.get(asset);
      // Shadow.
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(e.x, e.y + e.size * 0.32),
            width: e.size * 0.7,
            height: e.size * 0.28),
        Paint()..color = Colors.black.withValues(alpha: 0.25),
      );
      if (img == null) {
        canvas.drawCircle(
            Offset(e.x, e.y), e.size / 2, Paint()..color = Colors.orange);
        continue;
      }
      final w = e.size;
      final h = w * img.height / img.width;
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromCenter(center: Offset(e.x, e.y), width: w, height: h),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
  }

  String _assetFor(Entity e) {
    switch (e.type) {
      case EntityType.pencil:
        return A.pencil;
      case EntityType.eraser:
        return A.eraser;
      case EntityType.spring:
        return A.springboard;
      case EntityType.coin:
        return A.coin;
      case EntityType.star:
        return A.star;
      case EntityType.powerup:
        switch (e.power) {
          case PowerKind.shield:
            return A.shieldBuff;
          case PowerKind.magnet:
            return A.beckonsBuff;
          default:
            return A.powerUp;
        }
    }
  }

  void _paintTop(Canvas canvas, Size size) {
    final cx = engine.topX;
    final cy = size.height * engine.topYFactor;
    final r = engine.topRadius;

    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, cy + r * 0.7), width: r * 1.8, height: r * 0.7),
      Paint()..color = Colors.black.withValues(alpha: 0.35),
    );

    if (engine.boostActive) {
      final flame = Paint()..color = AppColors.yellow.withValues(alpha: 0.8);
      for (int i = 0; i < 3; i++) {
        final fx2 = cx + (i - 1) * 14;
        canvas.drawCircle(Offset(fx2, cy + r + 8 + i * 4), 8 - i * 2.0, flame);
      }
    }

    if (engine.shieldActive) {
      canvas.drawCircle(
        Offset(cx, cy),
        r + 12,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = AppColors.blue.withValues(alpha: 0.85),
      );
    }

    final img = bank.get(engine.skin.asset);
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(engine.spinTurns * math.pi * 2 % (math.pi * 2));
    final paint = Paint()..filterQuality = FilterQuality.medium;
    if (engine.skin.tint != null) {
      paint.colorFilter =
          ui.ColorFilter.mode(engine.skin.tint!, ui.BlendMode.modulate);
    }
    if (img != null) {
      final w = r * 2.4;
      final h = w * img.height / img.width;
      canvas.drawImageRect(
        img,
        Rect.fromLTWH(0, 0, img.width.toDouble(), img.height.toDouble()),
        Rect.fromCenter(center: Offset.zero, width: w, height: h),
        paint,
      );
    } else {
      canvas.drawCircle(Offset.zero, r, Paint()..color = engine.skin.color);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant RacePainter oldDelegate) => false;
}
