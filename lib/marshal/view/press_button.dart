import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Tactile button for the marshal screens. Matches the game's `ChunkyButton`
/// look without pulling in the game's audio or save state, so these screens
/// stay independent of the game runtime.
class PressButton extends StatefulWidget {
  const PressButton({
    super.key,
    required this.width,
    required this.label,
    required this.gradient,
    required this.lip,
    required this.onTap,
    this.icon,
    this.busy = false,
    this.height = 64,
    this.fontSize = 22,
  });

  final double width;
  final String label;
  final Gradient gradient;
  final Color lip;
  final VoidCallback onTap;
  final IconData? icon;
  final bool busy;
  final double height;
  final double fontSize;

  @override
  State<PressButton> createState() => _PressButtonState();
}

class _PressButtonState extends State<PressButton> {
  bool _held = false;

  void _setHeld(bool value) {
    if (_held == value) return;
    setState(() => _held = value);
  }

  @override
  Widget build(BuildContext context) {
    final drop = _held ? 5.0 : 0.0;
    return GestureDetector(
      onTapDown: widget.busy ? null : (_) => _setHeld(true),
      onTapCancel: () => _setHeld(false),
      onTapUp: widget.busy
          ? null
          : (_) {
              _setHeld(false);
              widget.onTap();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        width: widget.width,
        height: widget.height,
        transform: Matrix4.translationValues(0, drop, 0),
        decoration: BoxDecoration(
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.ink, width: 3),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: widget.lip,
              offset: Offset(0, _held ? 2 : 7),
              blurRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.38),
              offset: Offset(0, _held ? 4 : 11),
              blurRadius: 14,
            ),
          ],
        ),
        child: Center(child: _face()),
      ),
    );
  }

  Widget _face() {
    if (widget.busy) {
      return const SizedBox.square(
        dimension: 26,
        child: CircularProgressIndicator(strokeWidth: 2.8, color: Colors.white),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (widget.icon != null) ...<Widget>[
          Icon(widget.icon, color: Colors.white, size: widget.fontSize + 4),
          const SizedBox(width: 8),
        ],
        StrokeText(
          widget.label,
          strokeWidth: 3.5,
          style: AppText.title(widget.fontSize),
        ),
      ],
    );
  }
}
