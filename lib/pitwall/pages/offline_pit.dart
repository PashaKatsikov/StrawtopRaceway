import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import '../infra/reach_probe.dart';
import 'pit_button.dart';

/// No-internet screen. Retry re-runs the whole pipeline via [retryBuilder]
/// using THIS page's own context (never a captured parent context).
class OfflinePit extends StatefulWidget {
  const OfflinePit({
    super.key,
    required this.probe,
    required this.retryBuilder,
  });

  final ReachProbe probe;
  final WidgetBuilder retryBuilder;

  @override
  State<OfflinePit> createState() => _OfflinePitState();
}

class _OfflinePitState extends State<OfflinePit> {
  bool _checking = false;
  bool _stillOffline = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // The splash locks orientation right before routing here — re-enable both.
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  Future<void> _retry() async {
    if (_checking) return;
    HapticFeedback.lightImpact();
    setState(() {
      _checking = true;
      _stillOffline = false;
    });
    bool online = false;
    try {
      online = await widget.probe.canReachNetwork();
    } catch (_) {
      online = false;
    }
    if (!mounted) return;
    if (online) {
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute<void>(builder: widget.retryBuilder));
      return;
    }
    setState(() {
      _checking = false;
      _stillOffline = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final landscape = media.orientation == Orientation.landscape;
    final btnWidth = landscape
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
                  child: const Icon(Icons.wifi_off_rounded,
                      color: Colors.white, size: 56),
                ),
                const SizedBox(height: 26),
                StrokeText(
                  'NO INTERNET CONNECTION',
                  style: AppText.title(landscape ? 24 : 26),
                  strokeWidth: 4,
                ),
                const SizedBox(height: 12),
                Text(
                  'Check your connection and try again',
                  textAlign: TextAlign.center,
                  style: AppText.body(16, color: AppColors.textMuted),
                ),
                const SizedBox(height: 28),
                PitButton(
                  width: btnWidth,
                  label: 'Retry',
                  icon: Icons.refresh_rounded,
                  gradient: AppColors.goldGradient,
                  lip: AppColors.yellowDark,
                  busy: _checking,
                  onTap: _retry,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  child: _stillOffline
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
