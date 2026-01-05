import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class UpdateInfo {
  final String version;
  final String downloadUrl;

  const UpdateInfo({required this.version, required this.downloadUrl});
}

class UpdateService {
  static const _latestReleaseUrl =
      'https://api.github.com/repos/kelvinwieth/advance/releases/latest';

  static Future<UpdateInfo?> fetchLatestRelease() async {
    final response = await http.get(
      Uri.parse(_latestReleaseUrl),
      headers: const {'User-Agent': 'advance-app'},
    );
    if (response.statusCode != 200) return null;
    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final tagName = (data['tag_name'] ?? '') as String;
    final assets = (data['assets'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>();
    final asset = assets.firstWhere(
      (item) => (item['name'] as String?)?.toLowerCase().endsWith('.exe') ?? false,
      orElse: () => const {},
    );
    final downloadUrl = asset['browser_download_url'] as String?;
    if (downloadUrl == null) return null;
    return UpdateInfo(
      version: tagName.trim().replaceFirst(RegExp('^v', caseSensitive: false), ''),
      downloadUrl: downloadUrl,
    );
  }

  static int compareVersions(String current, String latest) {
    final currentParts = _parseVersionParts(current);
    final latestParts = _parseVersionParts(latest);
    final length = currentParts.length > latestParts.length
        ? currentParts.length
        : latestParts.length;
    for (var i = 0; i < length; i++) {
      final c = i < currentParts.length ? currentParts[i] : 0;
      final l = i < latestParts.length ? latestParts[i] : 0;
      if (c != l) return c.compareTo(l);
    }
    return 0;
  }

  static List<int> _parseVersionParts(String version) {
    final normalized = version
        .trim()
        .replaceFirst(RegExp('^v', caseSensitive: false), '')
        .split('+')
        .first
        .split('-')
        .first;
    return normalized.split('.').map((part) {
      final match = RegExp(r'^\d+').firstMatch(part);
      return match == null ? 0 : int.parse(match.group(0)!);
    }).toList();
  }

  static Future<void> downloadAndInstall(String url) async {
    if (!Platform.isWindows) return;
    final tempDir = await getTemporaryDirectory();
    final installerPath = '${tempDir.path}${Platform.pathSeparator}avanco_update.exe';
    final file = File(installerPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);
    if (response.statusCode != 200) {
      throw Exception('Falha ao baixar a atualização.');
    }
    final sink = file.openWrite();
    await response.stream.pipe(sink);
    await sink.flush();
    await sink.close();
    await Process.start(
      installerPath,
      const [],
      mode: ProcessStartMode.detached,
    );
    exit(0);
  }
}
