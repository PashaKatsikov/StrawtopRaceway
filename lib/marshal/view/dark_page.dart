import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import '../link/net_watch.dart';
import 'press_button.dart';

/// No-connection screen. Retry rebuilds through [again] using THIS page's own
/// context, never a captured parent context.
class DarkPage extends StatefulWidget {
  const DarkPage({super.key, required this.watch, required this.again});

  final NetWatch watch;
  final WidgetBuilder again;

  @override
  State<DarkPage> createState() => _DarkPageState();
}

class _DarkPageState extends State<DarkPage> {
  bool _probing = false;
  bool _stillDark = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // The splash pins orientation right before routing here — allow both again.
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _again() async {
    if (_probing) return;
    HapticFeedback.lightImpact();
    setState(() {
      _probing = true;
      _stillDark = false;
    });
    var reachable = false;
    try {
      reachable = await widget.watch.canReachOut();
    } catch (_) {
      reachable = false;
    }
    if (!mounted) return;
    if (reachable) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: widget.again),
      );
      return;
    }
    setState(() {
      _probing = false;
      _stillDark = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final wide = media.orientation == Orientation.landscape;
    final buttonWidth = wide
        ? (media.size.width * 0.38).clamp(240.0, 380.0)
        : (media.size.width * 0.66).clamp(220.0, 380.0);

    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      body: GameBackground(
        overlay: 0,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    gradient: AppColors.redGradient,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.ink, width: 3),
                    boxShadow: AppShadow.glow(AppColors.red, strength: 0.5),
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 26),
                StrokeText(
                  'NO INTERNET CONNECTION',
                  style: AppText.title(wide ? 24 : 26),
                  strokeWidth: 4,
                ),
                const SizedBox(height: 12),
                Text(
                  'Check your connection and try again',
                  textAlign: TextAlign.center,
                  style: AppText.body(16, color: AppColors.textMuted),
                ),
                const SizedBox(height: 28),
                PressButton(
                  width: buttonWidth,
                  label: 'Retry',
                  icon: Icons.refresh_rounded,
                  gradient: AppColors.goldGradient,
                  lip: AppColors.yellowDark,
                  busy: _probing,
                  onTap: _again,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  child: _stillDark
                      ? Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(
                            'No connection yet',
                            style: AppText.body(14, color: AppColors.textLight),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
