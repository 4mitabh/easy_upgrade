import 'dart:convert';

import 'package:http/http.dart' as http;

class IosLookupResult {
  final String version;
  final String? trackViewUrl;
  final String? releaseNotes;

  const IosLookupResult({
    required this.version,
    this.trackViewUrl,
    this.releaseNotes,
  });
}

class IosStoreLookup {
  static const String _endpoint = 'https://itunes.apple.com/lookup';
  static const Duration _timeout = Duration(seconds: 10);

  /// Calls the iTunes Search API for the given bundle id + region.
  /// Returns `null` when the app isn't found, the call fails, or the
  /// response is malformed. Falls back once to `US` if [regionCode] returns
  /// no results.
  static Future<IosLookupResult?> lookup({
    required String bundleId,
    String regionCode = 'US',
    http.Client? client,
  }) async {
    final ownClient = client == null;
    final c = client ?? http.Client();
    try {
      final result = await _lookupOnce(c, bundleId, regionCode);
      if (result != null) return result;
      if (regionCode.toUpperCase() != 'US') {
        return await _lookupOnce(c, bundleId, 'US');
      }
      return null;
    } catch (_) {
      return null;
    } finally {
      if (ownClient) c.close();
    }
  }

  static Future<IosLookupResult?> _lookupOnce(
    http.Client client,
    String bundleId,
    String regionCode,
  ) async {
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'bundleId': bundleId,
      'country': regionCode,
    });
    final resp = await client.get(uri).timeout(_timeout);
    if (resp.statusCode != 200) return null;
    final decoded = jsonDecode(resp.body);
    if (decoded is! Map<String, dynamic>) return null;
    final count = decoded['resultCount'];
    final results = decoded['results'];
    if (count is! int || count < 1 || results is! List || results.isEmpty) {
      return null;
    }
    final entry = results.first;
    if (entry is! Map<String, dynamic>) return null;
    final version = entry['version'];
    if (version is! String) return null;
    return IosLookupResult(
      version: version,
      trackViewUrl: entry['trackViewUrl'] is String
          ? entry['trackViewUrl'] as String
          : null,
      releaseNotes: entry['releaseNotes'] is String
          ? entry['releaseNotes'] as String
          : null,
    );
  }
}
