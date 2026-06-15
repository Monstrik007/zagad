import 'dart:convert';
import 'dart:io';

import 'network_constants.dart';

/// Отправка UDP-discovery на глобальный и подсетевой broadcast.
void sendDiscoveryBroadcast(
  RawDatagramSocket socket,
  List<int> payload, {
  List<InternetAddress>? extraTargets,
}) {
  try {
    socket.send(
      payload,
      InternetAddress('255.255.255.255'),
      discoveryPort,
    );
  } catch (_) {}

  for (final target in extraTargets ?? const <InternetAddress>[]) {
    try {
      socket.send(payload, target, discoveryPort);
    } catch (_) {}
  }
}

Future<List<InternetAddress>> directedBroadcastTargets() async {
  final targets = <InternetAddress>[];
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (addr.isLoopback) continue;
        final parts = addr.address.split('.');
        if (parts.length != 4) continue;
        final directed = '${parts[0]}.${parts[1]}.${parts[2]}.255';
        final target = InternetAddress.tryParse(directed);
        if (target != null &&
            !targets.any((t) => t.address == target.address)) {
          targets.add(target);
        }
      }
    }
  } catch (_) {}
  return targets;
}

List<int> discoveryPayload({
  required String roomCode,
  required String hostIp,
  required String hostName,
}) {
  return utf8.encode(
    jsonEncode({
      'type': 'discovery',
      'roomCode': roomCode,
      'hostIp': hostIp,
      'port': gamePort,
      'hostName': hostName,
      'ts': DateTime.now().millisecondsSinceEpoch,
    }),
  );
}

List<int> discoverRequestPayload() {
  return utf8.encode(
    jsonEncode({
      'type': 'discoverRequest',
      'ts': DateTime.now().millisecondsSinceEpoch,
    }),
  );
}
