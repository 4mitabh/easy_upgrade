import 'package:easy_upgrade/src/ios_store_lookup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('IosStoreLookup', () {
    test('parses a valid iTunes response', () async {
      final client = MockClient((req) async {
        expect(req.url.queryParameters['bundleId'], 'com.example.app');
        expect(req.url.queryParameters['country'], 'US');
        return http.Response(
          '{"resultCount":1,"results":[{"version":"2.0.0",'
          '"trackViewUrl":"https://apps.apple.com/app/id123",'
          '"releaseNotes":"Bug fixes"}]}',
          200,
        );
      });
      final result = await IosStoreLookup.lookup(
        bundleId: 'com.example.app',
        client: client,
      );
      expect(result, isNotNull);
      expect(result!.version, '2.0.0');
      expect(result.trackViewUrl, 'https://apps.apple.com/app/id123');
      expect(result.releaseNotes, 'Bug fixes');
    });

    test('returns null when resultCount is 0', () async {
      final client = MockClient((_) async {
        return http.Response('{"resultCount":0,"results":[]}', 200);
      });
      final result = await IosStoreLookup.lookup(
        bundleId: 'com.example.app',
        client: client,
      );
      expect(result, isNull);
    });

    test('falls back to US region on empty non-US response', () async {
      var calls = 0;
      final client = MockClient((req) async {
        calls++;
        final country = req.url.queryParameters['country'];
        if (country == 'GB') {
          return http.Response('{"resultCount":0,"results":[]}', 200);
        }
        return http.Response(
          '{"resultCount":1,"results":[{"version":"1.0.0"}]}',
          200,
        );
      });
      final result = await IosStoreLookup.lookup(
        bundleId: 'com.example.app',
        regionCode: 'GB',
        client: client,
      );
      expect(calls, 2);
      expect(result?.version, '1.0.0');
    });

    test('returns null on non-200', () async {
      final client = MockClient((_) async => http.Response('', 500));
      final result = await IosStoreLookup.lookup(
        bundleId: 'com.example.app',
        client: client,
      );
      expect(result, isNull);
    });

    test('returns null on malformed JSON', () async {
      final client = MockClient((_) async => http.Response('not json', 200));
      final result = await IosStoreLookup.lookup(
        bundleId: 'com.example.app',
        client: client,
      );
      expect(result, isNull);
    });
  });
}
