import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'local_network.dart';
import 'network_constants.dart';
import 'protocol.dart';

typedef ClientMessageHandler = void Function(NetworkMessage message);

class GameClient {
  Socket? _socket;
  StreamSubscription<String>? _subscription;
  ClientMessageHandler? onMessage;
  void Function()? onDisconnected;

  String? lastConnectError;

  bool get isConnected => _socket != null;

  Future<bool> connect(String hostIp, {int port = gamePort}) async {
    lastConnectError = null;
    final targets = await LocalNetwork.connectionTargets(hostIp);

    for (final target in targets) {
      if (await _tryConnect(target, port)) return true;
    }
    return false;
  }

  Future<bool> _tryConnect(String host, int port) async {
    try {
      _cleanup();
      _socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      _subscription = _socket!
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
        (line) {
          if (line.trim().isEmpty) return;
          try {
            final json = jsonDecode(line) as Map<String, dynamic>;
            onMessage?.call(NetworkMessage.fromJson(json));
          } catch (_) {}
        },
        onDone: () {
          onDisconnected?.call();
          _cleanup();
        },
        onError: (_) {
          onDisconnected?.call();
          _cleanup();
        },
      );
      return true;
    } on SocketException catch (e) {
      lastConnectError = '${e.message} ($host:$port)';
      _cleanup();
      return false;
    } on TimeoutException {
      lastConnectError = 'Таймаут ($host:$port)';
      _cleanup();
      return false;
    } catch (e) {
      lastConnectError = '$e ($host:$port)';
      _cleanup();
      return false;
    }
  }

  void send(NetworkMessage message) {
    if (_socket == null) return;
    try {
      _socket!.write('${message.encode()}\n');
    } catch (_) {}
  }

  Future<void> disconnect() async {
    onDisconnected = null;
    await _subscription?.cancel();
    await _socket?.close();
    _cleanup();
  }

  void _cleanup() {
    _subscription = null;
    _socket = null;
  }
}
