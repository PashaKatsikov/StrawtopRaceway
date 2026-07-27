import 'dart:convert';

import '../config/track_config.dart';
import '../core/lane_models.dart';
import 'pit_agent.dart';
import 'pit_vault.dart';
import 'track_attribution.dart';

/// POSTs the flat attribution + device body to the config endpoint and parses
/// the reply. A granted URL is cached for the returning-user fast path.
class ConfigRelay {
  ConfigRelay(this._agent, this._vault);

  final PitAgent _agent;
  final PitVault _vault;

  Future<GateReply> request(Map<String, dynamic> payload) async {
    if (!TrackConfig.grayCredentialsReady) {
      return GateReply.rejected('credentials_unavailable');
    }
    try {
      pitTrace(() => '[STW.RELAY] request ${jsonEncode(payload)}');
      final response = await _agent.post(
        Uri.parse(TrackConfig.endpoint),
        headers: const <String, String>{
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));
      pitTrace(
        () => '[STW.RELAY] response ${response.statusCode} ${response.body}',
      );
      if (response.statusCode != 200) {
        return GateReply.rejected('http_${response.statusCode}');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map) return GateReply.rejected('invalid_response');
      final reply = GateReply.fromJson(Map<String, dynamic>.from(decoded));
      if (reply.hasDestination) {
        await _vault.cacheUrl(reply.url!, reply.expiresAt);
      }
      return reply;
    } catch (error) {
      pitTrace(() => '[STW.RELAY] failed: $error');
      return GateReply.rejected('network_failure');
    }
  }
}
