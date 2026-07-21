import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/ui_kit.dart';

/// Displays a legal / support page. Loads the live URL when online and falls
/// back to bundled HTML (black text on white) so it is ALWAYS available,
/// even with no internet connection.
class WebViewPage extends StatefulWidget {
  const WebViewPage({
    super.key,
    required this.title,
    required this.url,
    required this.fallbackHtml,
  });

  final String title;
  final String url;
  final String fallbackHtml;

  @override
  State<WebViewPage> createState() => _WebViewPageState();
}

class _WebViewPageState extends State<WebViewPage> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _showedFallback = false;
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
            _timeout?.cancel();
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            // No connection / bad host -> show bundled copy.
            if (error.isForMainFrame ?? true) _loadFallback();
          },
        ),
      );
    _startLoad();
  }

  void _startLoad() {
    // If the live page hasn't loaded quickly (likely offline), show fallback.
    _timeout = Timer(const Duration(seconds: 6), () {
      if (_loading) _loadFallback();
    });
    _controller.loadRequest(Uri.parse(widget.url));
  }

  void _loadFallback() {
    if (_showedFallback) return;
    _showedFallback = true;
    _timeout?.cancel();
    _controller.loadHtmlString(widget.fallbackHtml);
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: GameBackground(
        overlay: 1,
        child: SafeArea(
          child: Column(
            children: [
              TopBar(
                  title: widget.title,
                  showWallet: false,
                  onBack: () => Navigator.pop(context)),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Stack(
                    children: [
                      WebViewWidget(controller: _controller),
                      if (_loading)
                        const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.blue),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bundled fallbacks (black text on white background).
class LegalContent {
  static const String privacyUrl =
      'https://strawtopraceway.com/privacy-policy.html';
  static const String supportUrl =
      'https://strawtopraceway.com/support.html';

  static const String _style =
      '<meta name="viewport" content="width=device-width, initial-scale=1">'
      '<style>body{background:#ffffff;color:#000000;font-family:sans-serif;'
      'padding:16px;line-height:1.5;} h1,h2{color:#000000;} a{color:#1b6fb3;}</style>';

  static const String privacyHtml = '''
<!DOCTYPE html><html><head>$_style</head><body>
<h1>Privacy Policy</h1>
<p><b>Effective Date:</b> June 2026</p>
<p>Developer ("we", "us", or "our") operates the <b>Strawtop Raceway</b> mobile
application ("Service"). This Privacy Policy explains how information is
collected, used, and protected when you use the Service.</p>
<h2>Information We Collect</h2>
<p>The Service may collect limited technical information necessary for operation
and improvement of the application, including: device type and model, operating
system version, anonymous usage statistics, diagnostic and crash information,
and IP address (when required for security and analytics purposes).</p>
<p>We do not intentionally collect sensitive personal information such as
financial account details, government-issued identification numbers, or
biometric data.</p>
<h2>How We Use Information</h2>
<p>To provide and maintain the Service, improve app functionality, monitor
performance and stability, detect and resolve technical issues, and comply with
legal obligations.</p>
<h2>Data Storage and Security</h2>
<p>We take reasonable measures to protect information from unauthorized access,
alteration, disclosure, or destruction. However, no method of electronic
transmission or storage is completely secure.</p>
<h2>Data Deletion</h2>
<p>Users have the right to request deletion of their personal data. To request
deletion, contact us at support@strawtopraceway.com. If the application stores
data only on the user's device, users may permanently delete all stored data by
uninstalling the application and clearing local storage.</p>
<h2>Children's Privacy</h2>
<p>The Service is not intended for children under the age of 18, and we do not
knowingly collect personal information from children.</p>
<h2>Contact Us</h2>
<p><b>Developer:</b> Strawtop Raceway<br><b>Email:</b> support@strawtopraceway.com</p>
</body></html>''';

  static const String supportHtml = '''
<!DOCTYPE html><html><head>$_style</head><body>
<h1>Support</h1>
<p>Need help with <b>Strawtop Raceway</b>? We are here for you.</p>
<h2>Contact</h2>
<p>Please reach out with any question, bug report or feedback:</p>
<p><b>Email:</b> support@strawtopraceway.com</p>
<h2>Common Questions</h2>
<p><b>My progress is saved?</b> Yes — all progress is stored locally on your
device and works fully offline.</p>
<p><b>How do I unlock new worlds?</b> Earn stars by completing races to open the
School Desk and Playground worlds.</p>
<p><b>How do I get more coins?</b> Win races, complete daily challenges, and
claim achievements.</p>
</body></html>''';
}
