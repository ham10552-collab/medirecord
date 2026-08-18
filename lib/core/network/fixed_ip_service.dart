import 'dart:convert';
import 'dart:io';
import '../utils/app_storage.dart';

class FixedIpService {
  static const storageKey = 'machine_fixed_ip';

  static Future<String> detectLocalIp() async {
    try {
      final interfaces = await NetworkInterface.list();
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.type == InternetAddressType.IPv4 && !addr.isLoopback) {
            return addr.address;
          }
        }
      }
    } catch (_) {}
    return '';
  }

  static Future<String> getFixedIp() async {
    final saved = (await AppStorage.read(storageKey) ?? '').trim();
    if (saved.isNotEmpty) return saved;
    final detected = await detectLocalIp();
    if (detected.isNotEmpty) await AppStorage.write(storageKey, detected);
    return detected;
  }

  static Future<void> saveFixedIp(String ip) async {
    await AppStorage.write(storageKey, ip.trim());
  }

  static Future<List<String>> detectDns() async {
    try {
      final adapter = await _adapterName();
      if (adapter.isEmpty) return [];
      var dns = await _dnsServers(adapter);
      if (dns.isEmpty) dns = ['8.8.8.8', '1.1.1.1'];
      return dns;
    } catch (_) {
      return ['8.8.8.8', '1.1.1.1'];
    }
  }

  static Future<String> applyStaticIp(String ip) async {
    try {
      final adapter = await _adapterName();
      if (adapter.isEmpty) return 'Could not find an active network adapter';
      final gateway = await _gateway(adapter);
      var dns = await _dnsServers(adapter);
      if (dns.isEmpty) dns = ['8.8.8.8', '1.1.1.1'];
      final parts = <String>[
        'netsh interface ip set address name="$adapter" '
            'static $ip 255.255.255.0${gateway.isEmpty ? '' : ' $gateway'}',
        'netsh interface ip set dns name="$adapter" static ${dns.first}',
      ];
      if (dns.length > 1) {
        parts.add('netsh interface ip add dns name="$adapter" ${dns[1]} index=2');
      }
      final cmd = parts.join('; ');
      final encoded = base64Encode(_utf16Le(cmd));
      await Process.run(
        'powershell',
        [
          '-NoProfile',
          '-Command',
          'Start-Process powershell -Verb RunAs -ArgumentList '
              "'-NoProfile','-EncodedCommand','$encoded' -Wait",
        ],
      );
      await Future<void>.delayed(const Duration(seconds: 4));
      final current = await _adapterIp(adapter);
      if (current == ip) return 'Static IP $ip applied successfully (DNS saved too)';
      return 'The command was started (check the admin window). '
          'Current IP: ${current.isEmpty ? 'unknown' : current}';
    } catch (e) {
      return 'Could not apply static IP: $e';
    }
  }

  static Future<String> _adapterName() async {
    try {
      final r = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        "(Get-NetAdapter | Where-Object { \$_.Status -eq 'Up' -and \$_.Name -notmatch 'vEthernet|Loopback|Bluetooth' } | Select-Object -First 1).Name",
      ]);
      if (r.exitCode == 0) return (r.stdout as String).trim();
    } catch (_) {}
    return '';
  }

  static Future<String> _gateway(String adapter) async {
    try {
      final r = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        "(Get-NetIPConfiguration -InterfaceAlias '$adapter').IPv4DefaultGateway.NextHop",
      ]);
      if (r.exitCode == 0) return (r.stdout as String).trim();
    } catch (_) {}
    return '';
  }

  static Future<List<String>> _dnsServers(String adapter) async {
    try {
      final r = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        "(Get-DnsClientServerAddress -InterfaceAlias '$adapter' -AddressFamily IPv4).ServerAddresses | Where-Object { \$_ -ne '::1' }",
      ]);
      if (r.exitCode == 0) {
        return (r.stdout as String)
            .trim()
            .split('\n')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<String> _adapterIp(String adapter) async {
    try {
      final r = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        "(Get-NetIPAddress -InterfaceAlias '$adapter' -AddressFamily IPv4).IPAddress",
      ]);
      if (r.exitCode == 0) return (r.stdout as String).trim().split('\n').first.trim();
    } catch (_) {}
    return '';
  }

  static List<int> _utf16Le(String s) {
    final bytes = <int>[];
    for (final unit in s.codeUnits) {
      bytes.add(unit & 0xFF);
      bytes.add((unit >> 8) & 0xFF);
    }
    return bytes;
  }
}
