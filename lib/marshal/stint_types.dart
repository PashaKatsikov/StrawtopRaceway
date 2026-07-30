/// The persisted lane a device belongs to.
enum StintLane {
  unset,
  board,
  garage;

  String get stored => switch (this) {
    StintLane.garage => 'garage',
    StintLane.board => 'board',
    StintLane.unset => 'unset',
  };

  /// Accepts the values written by earlier builds so an update never resets a
  /// device that already has a lane.
  static StintLane read(String? value) => switch (value) {
    'board' || 'portal' || 'web' => StintLane.board,
    'garage' || 'native' || 'game' => StintLane.garage,
    _ => StintLane.unset,
  };
}

/// Parsed reply from the beacon. Field names mirror the server contract and
/// must not be renamed.
class BeaconReply {
  const BeaconReply({
    required this.accepted,
    this.url,
    this.expiresAt,
    this.reason,
  });

  factory BeaconReply.fromJson(Map<String, dynamic> json) {
    final expiry = json['expires'];
    return BeaconReply(
      accepted: json['ok'] == true,
      url: json['url'] is String ? json['url'] as String : null,
      expiresAt: expiry is num
          ? expiry.toInt()
          : int.tryParse(expiry?.toString() ?? ''),
      reason: json['message']?.toString(),
    );
  }

  factory BeaconReply.refused(String reason) =>
      BeaconReply(accepted: false, reason: reason);

  final bool accepted;
  final String? url;
  final int? expiresAt;
  final String? reason;

  bool get hasTarget => accepted && (url?.isNotEmpty ?? false);
}

/// Where the boot pipeline decided to send this launch.
sealed class StintExit {
  const StintExit();
}

/// The game (organic install, or the layer is inert).
final class GarageExit extends StintExit {
  const GarageExit();
}

/// The board view at [url].
final class BoardExit extends StintExit {
  const BoardExit(this.url, {this.fromCold = false});

  final String url;
  final bool fromCold;
}

/// Nothing reachable.
final class DarkExit extends StintExit {
  const DarkExit();
}
