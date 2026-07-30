import 'dart:convert';

import '../flag_book.dart';
import '../stint_types.dart';
import '../trace.dart';
import 'locker.dart';
import 'wire_client.dart';

/// Posts the flat intake + device body to the beacon and parses the reply. A
/// granted target is held locally for the returning-launch fast path.
class BeaconCall {
  BeaconCall(this._wire, this._locker);

  final WireClient _wire;
  final Locker _locker;

  static const Map<String, String> _headers = <String, String>{
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  Future<BeaconReply> ask(Map<String, dynamic> body) async {
    if (!FlagBook.ready) return BeaconReply.refused('values_unavailable');
    try {
      gridNote(() => 'mrs:beacon ask ${jsonEncode(body)}');
      final response = await _wire
          .post(
            Uri.parse(FlagBook.beaconUrl),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(FlagBook.beaconTimeout);
      gridNote(
        () => 'mrs:beacon got ${response.statusCode} ${response.body}',
      );
      if (response.statusCode != 200) {
        return BeaconReply.refused('http_${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return BeaconReply.refused('unreadable_reply');
      final reply = BeaconReply.fromJson(Map<String, dynamic>.from(decoded));
      if (reply.hasTarget) {
        await _locker.holdTarget(reply.url!, reply.expiresAt);
      }
      return reply;
    } catch (error) {
      gridNote(() => 'mrs:beacon failed: $error');
      return BeaconReply.refused('transport_failure');
    }
  }
}
