import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Self-contained tactile button for the pit-flow screens. Styled to match the
/// game's `ChunkyButton` but with no white-part audio/state dependency, so the
/// gray screens stay independent of the game runtime.
class PitButton extends StatefulWidget {
  const PitButton({
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
  State<PitButton> createState() => _PitButtonState();
}

class _PitButtonState extends State<PitButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.busy ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: widget.busy
          ? null
          : (_) {
              setState(() => _down = false);
              widget.onTap();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        curve: Curves.easeOut,
        width: widget.width,
        height: widget.height,
        transform: Matrix4.translationValues(0, _down ? 5 : 0, 0),
        decoration: BoxDecoration(
          gradient: widget.gradient,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: AppColors.ink, width: 3),
          boxShadow: [
            BoxShadow(
              color: widget.lip,
              offset: Offset(0, _down ? 2 : 7),
              blurRadius: 0,
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.38),
              offset: Offset(0, _down ? 4 : 11),
              blurRadius: 14,
            ),
          ],
        ),
        child: Center(
          child: widget.busy
              ? const SizedBox.square(
                  dimension: 26,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.8,
                    color: Colors.white,
                  ),
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
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
      ),
    );
  }
}
