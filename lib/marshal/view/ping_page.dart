import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';
import '../../widgets/ui_kit.dart';
import '../flag_book.dart';
import '../link/locker.dart';
import '../link/ping_desk.dart';
import 'press_button.dart';

/// Notification promo shown once before the board view on the first attributed
/// launch. Declining only silences the prompt for a while — never forever.
class PingPage extends StatefulWidget {
  const PingPage({
    super.key,
    required this.locker,
    required this.desk,
    required this.next,
  });

  final Locker locker;
  final PingDesk desk;
  final WidgetBuilder next;

  @override
  State<PingPage> createState() => _PingPageState();
}

class _PingPageState extends State<PingPage> {
  bool _busy = false;

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

  Future<void> _agree() async {
    if (_busy) return;
    setState(() => _busy = true);
    final granted = await widget.desk.askConsent();
    if (!granted) await _quiet();
    _forward();
  }

  Future<void> _pass() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _quiet();
    _forward();
  }

  Future<void> _quiet() {
    final until = DateTime.now().millisecondsSinceEpoch ~/ 1000 +
        FlagBook.pingQuietSeconds;
    return widget.locker.quietPing(until);
  }

  void _forward() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: widget.next),
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final wide = media.orientation == Orientation.landscape;
    final buttonWidth = wide
        ? (media.size.width * 0.42).clamp(300.0, 520.0)
        : (media.size.width * 0.80).clamp(280.0, 440.0);

    return Scaffold(
      backgroundColor: AppColors.navyDeep,
      body: GameBackground(
        overlay: 0,
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 28,
              vertical: wide ? 12 : 28,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: wide ? 92 : 116,
                  height: wide ? 92 : 116,
                  decoration: BoxDecoration(
                    gradient: AppColors.goldGradient,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.ink, width: 3),
                    boxShadow: AppShadow.glow(AppColors.yellow, strength: 0.55),
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    color: Colors.white,
                    size: wide ? 48 : 60,
                  ),
                ),
                SizedBox(height: wide ? 16 : 24),
                StrokeText(
                  'ALLOW NOTIFICATIONS ABOUT\nBONUSES AND PROMOS',
                  style: AppText.title(wide ? 22 : 25),
                  strokeWidth: 4,
                ),
                const SizedBox(height: 12),
                Text(
                  'Stay tuned for special offers and rewards',
                  textAlign: TextAlign.center,
                  style: AppText.body(16, color: AppColors.textMuted),
                ),
                SizedBox(height: wide ? 20 : 30),
                PressButton(
                  width: buttonWidth,
                  label: 'Accept',
                  icon: Icons.check_rounded,
                  gradient: AppColors.greenGradient,
                  lip: AppColors.greenDark,
                  height: wide ? 62 : 70,
                  fontSize: wide ? 22 : 24,
                  busy: _busy,
                  onTap: _agree,
                ),
                SizedBox(height: wide ? 12 : 16),
                PressButton(
                  width: buttonWidth * 0.9,
                  label: 'Skip',
                  gradient: AppColors.sunsetGradient,
                  lip: AppColors.redDark,
                  height: wide ? 56 : 62,
                  fontSize: wide ? 20 : 22,
                  onTap: _busy ? () {} : _pass,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
