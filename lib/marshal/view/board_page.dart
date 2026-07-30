import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../link/locker.dart';
import '../link/net_watch.dart';
import '../link/ping_desk.dart';
import '../link/wire_client.dart';
import 'dark_page.dart';

/// Full-screen board view. Owns cold-launch viewport settling, rotation
/// reflow, offline routing, the native-feel frame script and hand-off of
/// non-web schemes to the OS.
class BoardPage extends StatefulWidget {
  const BoardPage({
    super.key,
    required this.url,
    required this.locker,
    required this.watch,
    required this.desk,
    required this.wire,
    this.fromCold = false,
  });

  final String url;
  final Locker locker;
  final NetWatch watch;
  final PingDesk desk;
  final WireClient wire;
  final bool fromCold;

  @override
  State<BoardPage> createState() => _BoardPageState();
}

class _BoardPageState extends State<BoardPage> with WidgetsBindingObserver {
  /// Schemes the view renders itself; anything else is the OS's business.
  static const Set<String> _ownSchemes = <String>{
    'http',
    'https',
    'about',
    'data',
    'blob',
  };

  static const Duration _coldFramePause = Duration(milliseconds: 330);
  static const Duration _rotationSettle = Duration(milliseconds: 415);
  static const Duration _warmSettle = Duration(milliseconds: 1150);
  static const Duration _coldSettle = Duration(milliseconds: 275);
  static const List<int> _nudgeSteps = <int>[55, 185, 395, 640, 910];
  static const int _loopRetryCap = 2;

  late final WebViewController _deck;
  StreamSubscription<List<ConnectivityResult>>? _linkSub;
  Timer? _settleTimer;
  Size? _lastCanvas;
  String? _topUrl;
  bool _frameSet = false;
  bool _coldRefetched = false;
  bool _coldShown = false;
  bool _darkRouted = false;
  int _loopRetries = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _hideChrome();
    SystemChrome.setPreferredOrientations(const <DeviceOrientation>[
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    _deck = _buildDeck();

    widget.desk.onTarget = (raw) {
      final uri = Uri.tryParse(raw);
      if (mounted && uri != null && uri.hasScheme) _deck.loadRequest(uri);
    };
    _linkSub = widget.watch.shifts.listen((states) {
      if (states.every((state) => state == ConnectivityResult.none)) _toDark();
    });

    if (widget.fromCold) {
      _prepColdFrame();
    } else {
      _frameSet = true;
      _deck.loadRequest(Uri.parse(widget.url));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _drainQueued());
  }

  WebViewController _buildDeck() {
    final params = Platform.isIOS
        ? WebKitWebViewControllerCreationParams(
            allowsInlineMediaPlayback: true,
            mediaTypesRequiringUserAction: const <PlaybackMediaTypes>{},
          )
        : const PlatformWebViewControllerCreationParams();
    final deck = WebViewController.fromPlatformCreationParams(
      params,
      onPermissionRequest: (request) => request.grant(),
    )
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setUserAgent(widget.wire.identity)
      ..enableZoom(false)
      ..setNavigationDelegate(_delegate());
    final platform = deck.platform;
    if (platform is WebKitWebViewController) {
      platform.setAllowsBackForwardNavigationGestures(true);
    }
    return deck;
  }

  void _hideChrome() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Let immersive mode settle in the phone's ACTUAL orientation before the
  /// view mounts (no forced rotation). Residual stretch is corrected by the
  /// post-load lock plus one reload, in whatever orientation we are in.
  Future<void> _prepColdFrame() async {
    _hideChrome();
    await Future<void>.delayed(_coldFramePause);
    if (!mounted) return;
    setState(() => _frameSet = true);
    await _deck.loadRequest(Uri.parse(widget.url));
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    setState(() {});
    final canvas = View.of(context).physicalSize;
    final previous = _lastCanvas;
    _lastCanvas = canvas;
    final turned = previous != null &&
        (previous.width < previous.height) != (canvas.width < canvas.height);
    if (!turned) return;
    _hideChrome();
    _settleTimer?.cancel();
    _nudgeLayout();
  }

  /// Re-assert the fixed-scale viewport on EVERY step: without it WKWebView
  /// keeps the pre-rotation scale and elements that bloated in landscape stay
  /// bloated on the way back to portrait.
  void _nudgeLayout() {
    for (final step in _nudgeSteps) {
      Timer(Duration(milliseconds: step), () {
        if (!mounted) return;
        _deck.runJavaScript(_pokeScript).catchError((_) {});
      });
    }
    _settleTimer = Timer(_rotationSettle, () {
      if (mounted) _applyFrame();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _hideChrome();
      _drainQueued();
    }
  }

  Future<void> _drainQueued() async {
    final queued = await widget.locker.takeQueued();
    final uri = queued == null ? null : Uri.tryParse(queued);
    if (mounted && uri != null && uri.hasScheme) {
      await _deck.loadRequest(uri);
    }
  }

  NavigationDelegate _delegate() {
    return NavigationDelegate(
      onPageStarted: (url) => _topUrl = url,
      onPageFinished: (_) {
        _loopRetries = 0;
        _applyFrame();

        // Cold launch, first pass: the view is still behind the black cover
        // (see build). WKWebView painted that frame at the site's own viewport
        // scale, so reload right away — the second paint uses the locked 1:1
        // viewport we just installed. No delay: this frame is never seen.
        if (widget.fromCold && !_coldRefetched) {
          _coldRefetched = true;
          _deck.reload().catchError((_) {});
          return;
        }

        // Cold launch second pass, or any warm load. The warm path keeps the
        // longer settle window; the cold path only needs the locked viewport
        // to reflow once before the cover lifts.
        Future<void>.delayed(
          widget.fromCold ? _coldSettle : _warmSettle,
          () async {
            if (!mounted) return;
            await _deck.runJavaScript(_settleScript).catchError((_) {});
            _applyFrame();
            if (!mounted) return;
            setState(() {
              if (widget.fromCold) _coldShown = true;
            });
          },
        );
      },
      onWebResourceError: (error) {
        if (error.errorCode == -999) return; // cancelled by a newer request
        final text = error.description.toLowerCase();
        final loop = error.errorCode == -1007 ||
            text.contains('too_many_redirects') ||
            text.contains('too many redirects');
        final top = _topUrl;
        if (loop && top != null && _loopRetries < _loopRetryCap) {
          _loopRetries++;
          _deck.loadRequest(Uri.parse(top));
          return;
        }
        // WKWebView reports null for the main navigation often enough that a
        // null must count as main frame, or a real failure is swallowed and
        // the view just sits there looking frozen.
        if (!(error.isForMainFrame ?? true)) return;
        _darkAfterProbe();
      },
      onNavigationRequest: (request) {
        final uri = Uri.tryParse(request.url);
        if (uri == null) return NavigationDecision.prevent;
        if (_ownSchemes.contains(uri.scheme)) {
          if (request.isMainFrame) _topUrl = request.url;
          return NavigationDecision.navigate;
        }
        launchUrl(uri, mode: LaunchMode.externalApplication);
        return NavigationDecision.prevent;
      },
    );
  }

  Future<void> _darkAfterProbe() async {
    if (_darkRouted) return;
    var reachable = true;
    try {
      reachable = await widget.watch.canReachOut();
    } catch (_) {
      reachable = false;
    }
    if (!reachable) _toDark();
  }

  Future<void> _toDark() async {
    if (_darkRouted || !mounted) return;
    _darkRouted = true;
    var here = widget.url;
    try {
      here = await _deck.currentUrl() ?? widget.url;
    } catch (_) {
      here = widget.url;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => DarkPage(
          watch: widget.watch,
          again: (_) => BoardPage(
            url: here,
            locker: widget.locker,
            watch: widget.watch,
            desk: widget.desk,
            wire: widget.wire,
          ),
        ),
      ),
    );
  }

  /// Installs the frame script on first call; every later call re-syncs the
  /// safe-area variables and re-locks the scale through the same entry point.
  void _applyFrame() {
    _deck.runJavaScript(_frameScript).catchError((_) {});
  }

  String get _frameScript => _frameSource.replaceFirst(
    '/*TYPE_SCALE*/',
    Platform.isIOS
        ? 'input,textarea,select,[contenteditable="true"]'
              '{font-size:max(16px,1em)!important;}'
        : '',
  );

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _settleTimer?.cancel();
    _linkSub?.cancel();
    widget.desk.onTarget = null;
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.of(context).viewPadding;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _deck.canGoBack()) await _deck.goBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        resizeToAvoidBottomInset: false,
        body: !_frameSet
            ? const ColoredBox(color: Colors.black)
            : Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  Padding(
                    padding: EdgeInsets.only(
                      top: inset.top,
                      bottom: inset.bottom,
                      left: inset.left,
                      right: inset.right,
                    ),
                    child: WebViewWidget(controller: _deck),
                  ),
                  // Cold-launch cover: hides the first (wrong-scale) paint and
                  // the reload frame in between. It lifts only once the locked
                  // viewport has reflowed, so the reveal is already at 1:1.
                  if (widget.fromCold && !_coldShown)
                    const ColoredBox(color: Colors.black),
                ],
              ),
      ),
    );
  }
}

const String _pokeScript =
    'window.__rwGrid && window.__rwGrid.lock();'
    'window.dispatchEvent(new Event("orientationchange"));'
    'window.dispatchEvent(new Event("resize"));'
    'window.visualViewport && '
    'window.visualViewport.dispatchEvent(new Event("resize"));';

const String _settleScript =
    'window.__rwGrid && window.__rwGrid.lock();'
    'window.dispatchEvent(new Event("resize"));'
    'window.visualViewport && '
    'window.visualViewport.dispatchEvent(new Event("resize"));';

/// One bundle for the whole native feel: safe-area neutralising, fixed scale,
/// tap polish, keyboard reveal, typing scale guard and inline playback. It
/// exposes `sync` (re-apply the CSS + viewport-fit) and `lock` (force 1:1) so
/// the native side can re-drive it after a rotation without re-installing any
/// listener.
const String _frameSource = r'''
(() => {
  const w = window;
  const d = document;
  if (w.__rwGrid) { w.__rwGrid.sync(); w.__rwGrid.lock(); return; }

  const VARS_ID = 'rw-frame-vars';
  const POLISH_ID = 'rw-frame-polish';
  const LOCKED = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, '
    + 'minimum-scale=1.0, user-scalable=no, viewport-fit=contain';
  const OPEN = 'width=device-width, initial-scale=1, viewport-fit=contain';

  const varRules = ':root{'
    + '--safe-area-inset-top:0px!important;'
    + '--safe-area-inset-right:0px!important;'
    + '--safe-area-inset-bottom:0px!important;'
    + '--safe-area-inset-left:0px!important;'
    + '--sat:0px!important;--sar:0px!important;'
    + '--sab:0px!important;--sal:0px!important;'
    + '--safe-top:0px!important;--safe-right:0px!important;'
    + '--safe-bottom:0px!important;--safe-left:0px!important;}'
    + 'html{-webkit-text-size-adjust:100%!important;'
    + 'text-size-adjust:100%!important;}'
    + 'html,body{overscroll-behavior:none!important;'
    + 'overscroll-behavior-y:none!important;}';

  const polishRules = '*{-webkit-tap-highlight-color:transparent!important;}'
    + '*:not(input):not(textarea):not([contenteditable="true"])'
    + '{-webkit-touch-callout:none!important;}'
    + '/*TYPE_SCALE*/';

  const anchor = () => d.head || d.documentElement;

  const paint = (id, css) => {
    const host = anchor();
    if (!host) return;
    let node = d.getElementById(id);
    if (!node) {
      node = d.createElement('style');
      node.id = id;
      host.appendChild(node);
    }
    if (node.textContent !== css) node.textContent = css;
  };

  const scaleTag = () => {
    const host = anchor();
    if (!host) return null;
    let tag = d.querySelector('meta[name="viewport"]');
    if (!tag) {
      tag = d.createElement('meta');
      tag.setAttribute('name', 'viewport');
      host.appendChild(tag);
    }
    return tag;
  };

  const lock = () => {
    const tag = scaleTag();
    if (tag) tag.setAttribute('content', LOCKED);
  };

  const typing = () => {
    const box = w.visualViewport;
    return !!box && box.height < w.innerHeight * 0.72;
  };

  const sync = () => {
    if (typing()) return;
    const tag = scaleTag();
    if (tag) {
      const kept = (tag.content || '')
        .replace(/,?\s*viewport-fit\s*=\s*\w+/ig, '').trim();
      tag.content = kept ? kept + ', viewport-fit=contain' : OPEN;
    }
    paint(VARS_ID, varRules);
  };

  const nudge = () => {
    w.setTimeout(lock, 190);
    w.setTimeout(sync, 210);
    w.setTimeout(sync, 705);
  };

  ['pushState', 'replaceState'].forEach((name) => {
    const native = history[name];
    if (typeof native !== 'function') return;
    history[name] = function () {
      const out = native.apply(this, arguments);
      nudge();
      return out;
    };
  });
  w.addEventListener('popstate', nudge);

  const halt = (event) => { event.preventDefault(); };
  ['gesturestart', 'gesturechange', 'gestureend'].forEach((kind) => {
    d.addEventListener(kind, halt, { passive: false });
  });
  d.addEventListener('touchmove', (event) => {
    if (event.scale !== undefined && event.scale !== 1) event.preventDefault();
  }, { passive: false });
  let lastTouch = 0;
  d.addEventListener('touchend', (event) => {
    const now = Date.now();
    if (now - lastTouch <= 285) event.preventDefault();
    lastTouch = now;
  }, { passive: false });

  const typable = (node) => !!node
    && typeof node.matches === 'function'
    && node.matches('input, textarea, select, [contenteditable="true"]');
  d.addEventListener('focusin', (event) => {
    if (!typable(event.target)) return;
    w.setTimeout(() => {
      const live = d.activeElement;
      if (typable(live)) {
        live.scrollIntoView({ behavior: 'auto', block: 'nearest' });
      }
    }, 300);
  }, true);

  const wakeClip = (clip) => {
    if (!(clip instanceof HTMLVideoElement)) return;
    clip.setAttribute('playsinline', '');
    clip.setAttribute('webkit-playsinline', '');
    clip.playsInline = true;
    clip.autoplay = true;
    const started = clip.play();
    if (started && started.catch) started.catch(() => {});
  };
  const sweep = (node) => {
    if (node instanceof HTMLVideoElement) wakeClip(node);
    if (typeof node.querySelectorAll === 'function') {
      node.querySelectorAll('video').forEach(wakeClip);
    }
  };
  sweep(d);
  new MutationObserver((records) => {
    for (const record of records) record.addedNodes.forEach(sweep);
  }).observe(d.documentElement, { childList: true, subtree: true });

  w.__rwGrid = { sync: sync, lock: lock };
  paint(POLISH_ID, polishRules);
  sync();
  lock();
  w.setInterval(sync, 3400);
})();
''';
