/// Persisted routing decision for the pit flow.
enum LaneRoute {
  undecided,
  portal,
  native;

  String get storageValue => switch (this) {
    LaneRoute.native => 'native',
    LaneRoute.portal => 'portal',
    LaneRoute.undecided => 'undecided',
  };

  static LaneRoute parse(String? value) => switch (value) {
    'portal' || 'web' => LaneRoute.portal,
    'native' || 'game' => LaneRoute.native,
    _ => LaneRoute.undecided,
  };
}

/// Parsed response from the config endpoint.
class GateReply {
  const GateReply({
    required this.accepted,
    this.url,
    this.expiresAt,
    this.reason,
  });

  factory GateReply.fromJson(Map<String, dynamic> json) {
    final rawExpiry = json['expires'];
    return GateReply(
      accepted: json['ok'] == true,
      url: json['url'] is String ? json['url'] as String : null,
      expiresAt: rawExpiry is num
          ? rawExpiry.toInt()
          : int.tryParse(rawExpiry?.toString() ?? ''),
      reason: json['message']?.toString(),
    );
  }

  factory GateReply.rejected(String reason) =>
      GateReply(accepted: false, reason: reason);

  final bool accepted;
  final String? url;
  final int? expiresAt;
  final String? reason;

  bool get hasDestination => accepted && (url?.isNotEmpty ?? false);
}

/// Where the boot pipeline decided to send the user.
sealed class LaneStop {
  const LaneStop();
}

/// White game (organic / gate disabled).
final class NativeStop extends LaneStop {
  const NativeStop();
}

/// WebView (gray) at [url].
final class PortalStop extends LaneStop {
  const PortalStop(this.url, {this.coldLaunch = false});

  final String url;
  final bool coldLaunch;
}

/// No connectivity.
final class OfflineStop extends LaneStop {
  const OfflineStop({required this.returnToNative});

  final bool returnToNative;
}
