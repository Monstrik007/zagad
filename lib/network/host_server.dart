import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'discovery.dart';
import 'local_network.dart';
import 'network_constants.dart';
import 'protocol.dart';

typedef MessageHandler = void Function(
  NetworkMessage message,
  String clientId,
);

class HostServer {
  ServerSocket? _server;
  final Map<String, Socket> _clients = {};
  final Map<String, String> _playerIdToClient = {};
  final _lineBuffers = <String, StringBuffer>{};
  final _subscriptions = <StreamSubscription<List<int>>>[];

  MessageHandler? onMessage;
  void Function(String clientId)? onClientDisconnected;

  bool get isRunning => _server != null;

  Future<String?> start() async {
    try {
      _server = await ServerSocket.bind(
        InternetAddress.anyIPv4,
        gamePort,
        shared: true,
      );
      _server!.listen(_handleConnection);
      return await LocalNetwork.getBestLocalIp();
    } catch (_) {
      return null;
    }
  }

  void _handleConnection(Socket client) {
    final clientId = '${client.remoteAddress.address}:${client.remotePort}';
    _clients[clientId] = client;
    _lineBuffers[clientId] = StringBuffer();

    final sub = client.listen(
      (data) {
        _lineBuffers[clientId]!.write(utf8.decode(data));
        final buffer = _lineBuffers[clientId]!.toString();
        final lines = buffer.split('\n');
        _lineBuffers[clientId]!.clear();
        if (lines.length > 1) {
          _lineBuffers[clientId]!.write(lines.last);
        }
        for (var i = 0; i < lines.length - 1; i++) {
          final line = lines[i].trim();
          if (line.isEmpty) continue;
          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            onMessage?.call(NetworkMessage.fromJson(json), clientId);
          } catch (_) {}
        }
      },
      onDone: () => _removeClient(clientId),
      onError: (_) => _removeClient(clientId),
    );
    _subscriptions.add(sub);
  }

  void _removeClient(String clientId) {
    _clients.remove(clientId);
    _lineBuffers.remove(clientId);
    _playerIdToClient.removeWhere((_, v) => v == clientId);
    onClientDisconnected?.call(clientId);
  }

  void linkPlayer(String playerId, String clientId) {
    final staleIds = _playerIdToClient.entries
        .where((e) => e.value == clientId && e.key != playerId)
        .map((e) => e.key)
        .toList();
    for (final id in staleIds) {
      _playerIdToClient.remove(id);
    }
    _playerIdToClient[playerId] = clientId;
  }

  List<String> playerIdsForClient(String clientId) {
    return _playerIdToClient.entries
        .where((e) => e.value == clientId)
        .map((e) => e.key)
        .toList();
  }

  void broadcast(NetworkMessage message, {String? exceptPlayerId}) {
    final data = '${message.encode()}\n';
    for (final entry in _playerIdToClient.entries) {
      if (exceptPlayerId != null && entry.key == exceptPlayerId) continue;
      _writeToClient(entry.value, data);
    }
    for (final entry in _clients.entries) {
      if (!_playerIdToClient.containsValue(entry.key)) {
        _writeToClient(entry.key, data);
      }
    }
  }

  void sendToPlayer(String playerId, NetworkMessage message) {
    final clientId = _playerIdToClient[playerId];
    if (clientId == null) return;
    _writeToClient(clientId, '${message.encode()}\n');
  }

  void sendToClient(String clientId, NetworkMessage message) {
    _writeToClient(clientId, '${message.encode()}\n');
  }

  Future<void> disconnectPlayer(
    String playerId, {
    NetworkMessage? farewell,
  }) async {
    final clientId = _playerIdToClient[playerId];
    if (clientId == null) return;
    if (farewell != null) {
      _writeToClient(clientId, '${farewell.encode()}\n');
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    try {
      await _clients[clientId]?.close();
    } catch (_) {}
    _removeClient(clientId);
  }

  void _writeToClient(String clientId, String data) {
    try {
      _clients[clientId]?.write(data);
    } catch (_) {}
  }

  Future<void> stop({NetworkMessage? farewell}) async {
    if (farewell != null) {
      final data = '${farewell.encode()}\n';
      for (final clientId in _clients.keys.toList()) {
        _writeToClient(clientId, data);
      }
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
    for (final client in _clients.values) {
      await client.close();
    }
    _clients.clear();
    _playerIdToClient.clear();
    _lineBuffers.clear();
    await _server?.close();
    _server = null;
  }
}

class DiscoveryBroadcaster {
  RawDatagramSocket? _socket;
  Timer? _timer;
  List<InternetAddress> _targets = [];
  List<int>? _announcePayload;

  Future<void> start({
    required String roomCode,
    required String hostIp,
    required String hostName,
  }) async {
    _announcePayload = discoveryPayload(
      roomCode: roomCode,
      hostIp: hostIp,
      hostName: hostName,
    );
    _targets = await directedBroadcastTargets();

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
        reusePort: true,
      );
    } catch (_) {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    }
    _socket!.broadcastEnabled = true;

    void burst() {
      final socket = _socket;
      final payload = _announcePayload;
      if (socket == null || payload == null) return;
      sendDiscoveryBroadcast(socket, payload, extraTargets: _targets);
    }

    _socket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = _socket?.receive();
      if (dg == null) return;
      try {
        final data = jsonDecode(utf8.decode(dg.data)) as Map<String, dynamic>;
        if (data['type'] == 'discoverRequest') {
          burst();
        }
      } catch (_) {}
    });

    burst();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => burst());
  }

  /// Дополнительные объявления (например, при входе игрока в комнату).
  void announceNow({int bursts = 3}) {
    final socket = _socket;
    final payload = _announcePayload;
    if (socket == null || payload == null) return;
    for (var i = 0; i < bursts; i++) {
      sendDiscoveryBroadcast(socket, payload, extraTargets: _targets);
    }
  }

  Future<void> stop({
    String? roomCode,
    String? hostIp,
  }) async {
    _timer?.cancel();
    _timer = null;
    _announcePayload = null;

    if (_socket != null && roomCode != null && hostIp != null) {
      final goodbye = jsonEncode({
        'type': 'roomClosed',
        'roomCode': roomCode,
        'hostIp': hostIp,
      });
      final target = InternetAddress('255.255.255.255');
      for (var i = 0; i < 4; i++) {
        _socket?.send(utf8.encode(goodbye), target, discoveryPort);
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
    }

    _socket?.close();
    _socket = null;
  }
}

class DiscoveryListener {
  RawDatagramSocket? _socket;
  Timer? _probeTimer;
  List<InternetAddress> _probeTargets = [];
  void Function(Map<String, dynamic> room)? onRoomFound;
  void Function(Map<String, dynamic> room)? onRoomClosed;

  Future<void> start() async {
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        discoveryPort,
        reuseAddress: true,
        reusePort: true,
      );
      _socket!.broadcastEnabled = true;
    } catch (_) {
      try {
        _socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          discoveryPort,
          reuseAddress: true,
        );
        _socket!.broadcastEnabled = true;
      } catch (_) {
        return;
      }
    }

    _probeTargets = await directedBroadcastTargets();
    _sendDiscoverRequest();
    _probeTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _sendDiscoverRequest(),
    );

    _socket!.listen((event) {
      if (event != RawSocketEvent.read) return;
      final dg = _socket!.receive();
      if (dg == null) return;
      try {
        final data = jsonDecode(utf8.decode(dg.data)) as Map<String, dynamic>;
        if (data['type'] == 'discovery') {
          onRoomFound?.call(data);
        } else if (data['type'] == 'roomClosed') {
          onRoomClosed?.call(data);
        }
      } catch (_) {}
    });
  }

  void _sendDiscoverRequest() {
    final socket = _socket;
    if (socket == null) return;
    sendDiscoveryBroadcast(
      socket,
      discoverRequestPayload(),
      extraTargets: _probeTargets,
    );
  }

  void stop() {
    _probeTimer?.cancel();
    _probeTimer = null;
    _probeTargets = [];
    _socket?.close();
    _socket = null;
  }
}
