import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../data/audio_service.dart';
import '../data/game_state.dart';
import '../data/models.dart';
import '../data/assets.dart';
import '../theme/app_theme.dart';

/// A full-screen premium background: layered gradient, an optional location
/// image with a graded scrim, slow-drifting luminous orbs, a warm top glow and
/// a soft edge vignette.
class GameBackground extends StatelessWidget {
  const GameBackground({
    super.key,
    required this.child,
    this.image,
    this.overlay = 0.55,
    this.animated = true,
  });

  final Widget child;
  final String? image;
  final double overlay;
  final bool animated;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.bgGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null) Image.asset(image!, fit: BoxFit.cover),
          if (image != null)
            // Graded scrim: darker at the bottom for readable content,
            // lighter at the top so the art still breathes.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.navyDeep.withValues(alpha: overlay * 0.7),
                    AppColors.navyDeep.withValues(alpha: overlay),
                    AppColors.navyDeep
                        .withValues(alpha: (overlay + 0.15).clamp(0.0, 1.0)),
                  ],
                ),
              ),
            ),
          // Living, drifting glow that floats over everything.
          if (animated) const IgnorePointer(child: AuroraLayer()),
          // Warm glow from the top.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.bgGlow),
            ),
          ),
          // Edge vignette for focus.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.vignette),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// A cheap, GPU-friendly animated bloom: a handful of additive radial "orbs"
/// drifting along Lissajous paths. Isolated in a RepaintBoundary so it never
/// forces the rest of the tree to repaint.
class AuroraLayer extends StatefulWidget {
  const AuroraLayer({super.key});

  @override
  State<AuroraLayer> createState() => _AuroraLayerState();
}

class _AuroraLayerState extends State<AuroraLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          size: Size.infinite,
          painter: _AuroraPainter(_c.value),
        ),
      ),
    );
  }
}

class _Orb {
  const _Orb(this.color, this.radius, this.ax, this.ay, this.sx, this.sy, this.phase);
  final Color color;
  final double radius; // fraction of shortest side
  final double ax, ay; // drift amplitude (fraction of size)
  final double sx, sy; // speed multipliers
  final double phase;
}

class _AuroraPainter extends CustomPainter {
  _AuroraPainter(this.t);
  final double t;

  static const List<_Orb> _orbs = [
    _Orb(AppColors.glow, 0.85, 0.16, 0.10, 1.0, 0.7, 0.0),
    _Orb(AppColors.purple, 0.75, 0.20, 0.14, 0.7, 1.0, 1.7),
    _Orb(AppColors.cyan, 0.65, 0.18, 0.12, 1.3, 0.9, 3.1),
    _Orb(AppColors.pink, 0.55, 0.14, 0.16, 0.9, 1.2, 4.5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final tau = math.pi * 2;
    final minSide = math.min(size.width, size.height);
    for (final o in _orbs) {
      final cx = size.width * (0.5 + o.ax * math.sin(tau * o.sx * t + o.phase));
      final cy = size.height *
          (0.42 + o.ay * math.cos(tau * o.sy * t + o.phase * 1.3));
      final r = minSide * o.radius;
      final rect = Rect.fromCircle(center: Offset(cx, cy), radius: r);
      final paint = Paint()
        ..blendMode = BlendMode.plus
        ..shader = RadialGradient(
          colors: [o.color.withValues(alpha: 0.18), o.color.withValues(alpha: 0.0)],
        ).createShader(rect);
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter old) => old.t != t;
}

/// Wraps any tappable card so it springs down on press and plays a click.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    required this.onTap,
    this.scale = 0.94,
  });

  final Widget child;
  final VoidCallback onTap;
  final double scale;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) {
        setState(() => _down = false);
        AudioService.instance.click();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Adds a slow breathing colour glow behind [child] – great for hero CTAs.
class PulseGlow extends StatefulWidget {
  const PulseGlow({
    super.key,
    required this.child,
    required this.color,
    this.radius = AppRadius.pill,
  });

  final Widget child;
  final Color color;
  final double radius;

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final v = Curves.easeInOut.transform(_c.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.25 + 0.35 * v),
                blurRadius: 22 + 20 * v,
                spreadRadius: -2,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Glassy premium card: gradient fill, bright inner sheen at the top, a subtle
/// light edge and layered shadow (+ optional coloured glow).
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.panel,
    this.radius = AppRadius.lg,
    this.borderColor,
    this.gradient,
    this.glow,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final double radius;
  final Color? borderColor;
  final Gradient? gradient;

  /// Optional accent colour for a soft outer glow.
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    // Default surface uses the glassy panel gradient; a solid [color] override
    // (other than the default) still wins for callers that need it.
    final Gradient surface = gradient ??
        (color == AppColors.panel
            ? AppColors.panelGradient
            : LinearGradient(colors: [
                Color.lerp(color, Colors.white, 0.10)!,
                Color.lerp(color, Colors.black, 0.14)!,
              ], begin: Alignment.topLeft, end: Alignment.bottomRight));

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: surface,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? AppColors.glassBorder,
          width: 1.5,
        ),
        boxShadow: [
          ...AppShadow.soft,
          if (glow != null) ...AppShadow.glow(glow!, strength: 0.45),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            // Top inner sheen.
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.16),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }
}

/// Big tactile push button with a 3D "bottom lip".
class ChunkyButton extends StatefulWidget {
  const ChunkyButton({
    super.key,
    required this.label,
    required this.onTap,
    this.gradient = AppColors.greenGradient,
    this.icon,
    this.height = 58,
    this.fontSize = 20,
    this.enabled = true,
    this.lip = const Color(0xFF176B3A),
  });

  final String label;
  final VoidCallback onTap;
  final Gradient gradient;
  final IconData? icon;
  final double height;
  final double fontSize;
  final bool enabled;
  final Color lip;

  @override
  State<ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<ChunkyButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled;
    return GestureDetector(
      onTapDown: active ? (_) => setState(() => _down = true) : null,
      onTapCancel: active ? () => setState(() => _down = false) : null,
      onTapUp: active
          ? (_) {
              setState(() => _down = false);
              AudioService.instance.click();
              widget.onTap();
            }
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        height: widget.height,
        transform: Matrix4.translationValues(0, _down ? 5 : 0, 0),
        decoration: BoxDecoration(
          gradient: active
              ? widget.gradient
              : const LinearGradient(colors: [Color(0xFF565073), Color(0xFF403A5C)]),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.ink, width: 3),
          boxShadow: [
            // Coloured 3D lip.
            BoxShadow(
              color: (active ? widget.lip : const Color(0xFF2A2740)),
              offset: Offset(0, _down ? 2 : 7),
              blurRadius: 0,
            ),
            // Soft ambient drop shadow.
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.38),
              offset: Offset(0, _down ? 4 : 11),
              blurRadius: 14,
            ),
            // Coloured glow to make the button feel alive.
            if (active)
              BoxShadow(
                color: widget.lip.withValues(alpha: 0.45),
                offset: const Offset(0, 2),
                blurRadius: 18,
                spreadRadius: -4,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: Stack(
            children: [
              // Top glossy highlight (curved sheen).
              Positioned(
                left: 8,
                right: 8,
                top: 4,
                child: Container(
                  height: widget.height * 0.42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: active ? 0.42 : 0.16),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
              ),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon,
                          color: Colors.white, size: widget.fontSize + 4),
                      const SizedBox(width: 8),
                    ],
                    StrokeText(
                      widget.label,
                      strokeWidth: 3.5,
                      style: AppText.title(widget.fontSize),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Wallet chip for coins / gems.
class CurrencyChip extends StatelessWidget {
  const CurrencyChip({
    super.key,
    required this.value,
    required this.isGem,
    this.onAdd,
  });

  final int value;
  final bool isGem;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final accent = isGem ? AppColors.cyan : AppColors.yellow;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.ink.withValues(alpha: 0.72),
            AppColors.navy.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: accent.withValues(alpha: 0.45), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.22),
            blurRadius: 12,
            spreadRadius: -3,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(isGem ? A.iceBuff : A.coin, width: 24, height: 24),
          const SizedBox(width: 6),
          Text('$value',
              style: AppText.body(15, weight: FontWeight.w800)),
          if (onAdd != null) ...[
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onAdd,
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  gradient: AppColors.greenGradient,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, size: 16, color: Colors.white),
              ),
            ),
          ] else
            const SizedBox(width: 4),
        ],
      ),
    );
  }
}

/// Top navigation bar used across screens.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    this.onBack,
    this.showWallet = true,
    this.trailing,
  });

  final String title;
  final VoidCallback? onBack;
  final bool showWallet;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final gs = GameState.instance;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        children: [
          if (onBack != null) ...[
            _RoundIcon(icon: Icons.arrow_back_rounded, onTap: onBack!),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: StrokeText(
              title,
              textAlign: TextAlign.left,
              style: AppText.title(24),
            ),
          ),
          ?trailing,
          if (showWallet) ...[
            AnimatedBuilder(
              animation: gs,
              builder: (_, _) => Row(
                children: [
                  CurrencyChip(value: gs.coins, isGem: false),
                  const SizedBox(width: 8),
                  CurrencyChip(value: gs.gems, isGem: true),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AudioService.instance.click();
        onTap();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.panelLight, AppColors.panel],
          ),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: AppColors.glassHi, width: 1.5),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}

/// Renders a spinning-top sprite with optional colour modulation.
class TopSprite extends StatelessWidget {
  const TopSprite({super.key, required this.skin, this.size = 96});
  final TopSkin skin;
  final double size;

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(skin.asset, width: size, height: size);
    if (skin.tint == null) return img;
    return ColorFiltered(
      colorFilter: ColorFilter.mode(skin.tint!, BlendMode.modulate),
      child: img,
    );
  }
}

/// Row of up to 3 stars.
class StarsRow extends StatelessWidget {
  const StarsRow({super.key, required this.count, this.size = 20, this.max = 3});
  final int count;
  final double size;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(max, (i) {
        final filled = i < count;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Icon(
            filled ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: filled ? AppColors.yellow : Colors.white24,
          ),
        );
      }),
    );
  }
}

/// A labelled stat bar (0..12).
class StatBar extends StatelessWidget {
  const StatBar({
    super.key,
    required this.label,
    required this.value,
    this.max = 12,
    this.color = AppColors.green,
    this.icon,
  });

  final String label;
  final int value;
  final int max;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
          ],
          SizedBox(
            width: 66,
            child: Text(label,
                style: AppText.body(12, color: AppColors.textMuted)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: Stack(
                children: [
                  Container(height: 12, color: AppColors.ink),
                  FractionallySizedBox(
                    widthFactor: (value / max).clamp(0.0, 1.0),
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [color, color.withValues(alpha: 0.6)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('$value',
              style: AppText.body(12, weight: FontWeight.w800)),
        ],
      ),
    );
  }
}

/// Snackbar-style toast helper.
void showToast(BuildContext context, String message, {bool good = true}) {
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: good ? AppColors.greenDark : AppColors.redDark,
        duration: const Duration(milliseconds: 1400),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md)),
        content: Text(message,
            style: AppText.body(14, weight: FontWeight.w800)),
      ),
    );
}
