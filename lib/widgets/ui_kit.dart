import 'package:flutter/material.dart';
import '../data/audio_service.dart';
import '../data/game_state.dart';
import '../data/models.dart';
import '../data/assets.dart';
import '../theme/app_theme.dart';

/// A full screen background: gradient + optional blurred image + dark overlay.
class GameBackground extends StatelessWidget {
  const GameBackground({
    super.key,
    required this.child,
    this.image,
    this.overlay = 0.55,
  });

  final Widget child;
  final String? image;
  final double overlay;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.bgGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (image != null)
            Image.asset(image!, fit: BoxFit.cover),
          if (image != null)
            Container(color: AppColors.navyDeep.withValues(alpha: overlay)),
          child,
        ],
      ),
    );
  }
}

/// Chunky cartoon panel with border + drop shadow.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = AppColors.panel,
    this.radius = AppRadius.lg,
    this.borderColor,
    this.gradient,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final double radius;
  final Color? borderColor;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? color : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.16),
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
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
        duration: const Duration(milliseconds: 70),
        height: widget.height,
        transform: Matrix4.translationValues(0, _down ? 4 : 0, 0),
        decoration: BoxDecoration(
          gradient: active
              ? widget.gradient
              : const LinearGradient(colors: [Color(0xFF5A6486), Color(0xFF454E70)]),
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.ink, width: 3),
          boxShadow: [
            // Coloured 3D lip.
            BoxShadow(
              color: (active ? widget.lip : const Color(0xFF2A3050)),
              offset: Offset(0, _down ? 2 : 6),
              blurRadius: 0,
            ),
            // Soft ambient drop shadow.
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              offset: Offset(0, _down ? 4 : 9),
              blurRadius: 10,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Top glossy highlight.
            Positioned(
              left: 10,
              right: 10,
              top: 5,
              child: Container(
                height: widget.height * 0.28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: active ? 0.28 : 0.12),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.5),
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
          color: AppColors.panelLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 3)),
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
