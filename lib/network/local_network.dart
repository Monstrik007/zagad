import 'dart:io';

/// Выбирает IP для LAN-игры (Wi‑Fi / Ethernet), без Docker/VPN.
class LocalNetwork {
  static Future<String?> getBestLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );

      String? fallback;

      for (final iface in interfaces) {
        final name = iface.name.toLowerCase();
        if (_shouldSkipInterface(name)) continue;

        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final ip = addr.address;
          if (!_isPrivateLan(ip)) continue;

          if (_isPreferredInterface(name)) return ip;
          fallback ??= ip;
        }
      }

      return fallback;
    } catch (_) {
      return null;
    }
  }

  static Future<List<String>> getLocalIpv4Addresses() async {
    final result = <String>['127.0.0.1'];
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: true,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4) {
            result.add(addr.address);
          }
        }
      }
    } catch (_) {}
    return result.toSet().toList();
  }

  /// Адреса для попытки TCP-подключения к хосту.
  static Future<List<String>> connectionTargets(String hostIp) async {
    final ordered = <String>[];
    void add(String ip) {
      if (ip.isNotEmpty && !ordered.contains(ip)) ordered.add(ip);
    }

    add(hostIp.trim());

    final local = await getLocalIpv4Addresses();
    // Тест на одном ПК: хост слушает на LAN-IP, гость подключается через loopback.
    if (local.contains(hostIp)) {
      add('127.0.0.1');
    }

    return ordered;
  }

  static bool _shouldSkipInterface(String name) {
    return name == 'lo' ||
        name.startsWith('lo') ||
        name.startsWith('docker') ||
        name.startsWith('br-') ||
        name.startsWith('veth') ||
        name.contains('virbr') ||
        name.startsWith('tun') ||
        name.startsWith('tap') ||
        name.startsWith('utun') ||
        name.startsWith('awdl') ||
        name.startsWith('bridge') ||
        name.startsWith('gif') ||
        name.startsWith('stf') ||
        name.contains('vethernet');
  }

  static bool _isPreferredInterface(String name) {
    return _isMacLanInterface(name) ||
        name.startsWith('wlan') ||
        name.startsWith('wl') ||
        name.startsWith('wifi') ||
        name.startsWith('eth') ||
        name.startsWith('enp') ||
        name.startsWith('eno') ||
        name.startsWith('enx');
  }

  /// Wi‑Fi / Ethernet на macOS: en0, en1, …
  static bool _isMacLanInterface(String name) {
    if (!name.startsWith('en')) return false;
    if (name.startsWith('eno') ||
        name.startsWith('enp') ||
        name.startsWith('enx')) {
      return false;
    }
    final suffix = name.substring(2);
    if (suffix.isEmpty) return true;
    return int.tryParse(suffix) != null;
  }

  static bool isPrivateLan(String ip) => _isPrivateLan(ip);

  static bool _isPrivateLan(String ip) {
    if (ip.startsWith('192.168.')) return true;
    if (ip.startsWith('10.')) return true;
    final parts = ip.split('.');
    if (parts.length == 4 && parts[0] == '172') {
      final second = int.tryParse(parts[1]) ?? 0;
      if (second >= 16 && second <= 31) return true;
    }
    return false;
  }
}
