import '../core/grit_cipher.dart';

/// Central configuration + obfuscated credentials for the pit (gray) flow.
///
/// All secrets live as byte arrays produced by
/// `dart run tool/encode_track_values.dart` (never plaintext). Regenerate and
/// re-verify after any change to the cipher seed.
///
/// The pit flow stays disabled (white game only) until [endpoint],
/// [appsFlyerKey] and [firebaseProjectNumber] are all non-empty.
abstract final class TrackConfig {
  static const String appTitle = 'Strawtop Raceway';
  static const String bundleId = 'com.strawtop.racewaygame';

  /// iOS App Store numeric id — used for GCD lookups and the `store_id` field.
  static const String iosStoreId = '6792536620';

  static const int pushSnoozeSeconds = 259200; // 3 days
  static const int organicRecheckSeconds = 6;

  // ── Encoded secrets (from tool/encode_track_values.dart) ─────────────────
  static const List<int> _endpoint = <int>[
    200, 119, 17, 103, 221, 57, 121, 66, 10, 44, 151, 133, 103, 68, 170, 133,
    137, 16, 198, 122, 7, 36, 221, 18, 41, 92, 54, 231, 212, 67, 95, 185, 145,
    122, 12, 89, 206, 10,
  ];
  static const List<int> _privacy = <int>[
    200, 119, 17, 103, 221, 57, 121, 66, 10, 44, 151, 133, 103, 68, 170, 133,
    137, 16, 198, 122, 7, 36, 221, 18, 41, 92, 54, 231, 199, 96, 92, 169, 153,
    126, 215, 126, 198, 11, 4, 46, 35, 50, 235, 11, 114, 36, 169,
  ];
  static const List<int> _support = <int>[
    200, 119, 17, 103, 221, 57, 121, 66, 10, 44, 151, 133, 103, 68, 170, 133,
    137, 16, 198, 122, 7, 36, 221, 18, 41, 92, 54, 231, 196, 93, 69, 175, 151,
    109, 210, 127, 206, 6, 5, 41,
  ];
  static const List<int> _gcd = <int>[
    200, 119, 17, 103, 221, 57, 121, 66, 254, 25, 173, 119, 84, 65, 107, 118,
    139, 31, 182, 123, 236, 12, 217, 222, 244, 96, 56, 37, 160, 73, 95, 174,
    140, 124, 202, 61, 161, 22, 1, 33, 33, 100, 163, 192, 152, 95, 230,
  ];
  static const List<int> _webkit = <int>[150, 59, 208, 177, 159, 37, 91, 76];
  static const List<int> _safari = <int>[145, 51, 199, 172];
  static const List<int> _safariTail = <int>[150, 59, 209, 177, 159];
  static const List<int> _appsFlyerKey = <int>[
    245, 125, 20, 138, 209, 140, 122, 88, 49, 45, 172, 117, 73, 54, 129, 101,
    131, 101, 177, 94, 38, 56,
  ];
  static const List<int> _firebaseProject = <int>[
    149, 56, 209, 168, 157, 44, 94, 75, 79, 103, 86, 183,
  ];

  static String get endpoint => revealGrit(_endpoint);
  static String get privacyUrl => revealGrit(_privacy);
  static String get supportUrl => revealGrit(_support);
  static String get gcdBase => revealGrit(_gcd);
  static String get webKitVersion => revealGrit(_webkit);
  static String get safariVersion => revealGrit(_safari);
  static String get safariTail => revealGrit(_safariTail);
  static String get appsFlyerKey => revealGrit(_appsFlyerKey);
  static String get firebaseProjectNumber => revealGrit(_firebaseProject);

  static String get storeToken => 'id$iosStoreId';

  /// Gate needs config endpoint + AppsFlyer key + Firebase project number.
  /// Never fold optional fields in here — a missing optional would silently
  /// disable the whole pit flow.
  static bool get grayCredentialsReady =>
      endpoint.isNotEmpty &&
      appsFlyerKey.isNotEmpty &&
      firebaseProjectNumber.isNotEmpty;
}
