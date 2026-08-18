import 'package:encrypt/encrypt.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:lumen_reader/core/storage/storage_service.dart';
import 'package:lumen_reader/core/sync/sync_service.dart';

void main() {
  group('SyncService encrypt/decrypt', () {
    late SyncService sync;

    setUp(() {
      // StorageService is constructed but never exercised by the encrypt /
      // decrypt code paths; FlutterSecureStorage just stores the instance
      // without touching platform channels at construction time.
      final storage = StorageService(const FlutterSecureStorage(), Logger());
      sync = SyncService(storage, Logger());
      sync.setMasterKeyForTesting(Key.fromSecureRandom(32));
    });

    test('round-trips a nested JSON payload', () {
      final payload = {
        'installId': 'abc-123',
        'progress': [
          {'bookId': 'b1', 'chapterId': '0:Hello', 'progress': 0.42},
        ],
        'highlights': <Map<String, dynamic>>[],
        'bookmarks': <Map<String, dynamic>>[],
        'annotations': <Map<String, dynamic>>[],
        'ts': '2026-08-18T10:00:00.000Z',
      };

      final encrypted = sync.encryptPayload(payload);

      // Ciphertext envelope must NOT leak the plaintext — it must be base64
      // blobs, not the original Map.toString() output that the old code used.
      expect(encrypted, isA<Map<String, dynamic>>());
      expect(encrypted['v'], 1);
      expect(encrypted['alg'], 'aes-256-cbc');
      expect(encrypted['iv'], isA<String>());
      expect(encrypted['cipher'], isA<String>());
      final cipher = encrypted['cipher'] as String;
      expect(cipher, isNot(contains('installId')));
      expect(cipher, isNot(contains('Hello')));

      final decrypted = sync.decryptPayload(encrypted);
      expect(decrypted, isNotNull);
      expect(decrypted!['installId'], 'abc-123');
      expect((decrypted['progress'] as List).length, 1);
      final first =
          (decrypted['progress'] as List).first as Map<String, dynamic>;
      expect(first['chapterId'], '0:Hello');
      expect(first['progress'], 0.42);
    });

    test('round-trips non-ASCII content (CJK + emoji)', () {
      final payload = {
        'note': '读书笔记：今天读完了《三体》第三章 🎉',
        'count': 42,
      };

      final encrypted = sync.encryptPayload(payload);
      final decrypted = sync.decryptPayload(encrypted);

      expect(decrypted, isNotNull);
      expect(decrypted!['note'], '读书笔记：今天读完了《三体》第三章 🎉');
      expect(decrypted['count'], 42);
    });

    test('returns null when ciphertext envelope is malformed', () {
      expect(sync.decryptPayload(<String, dynamic>{}), isNull);
      expect(
        sync.decryptPayload(<String, dynamic>{
          'iv': 'not-base64!!!',
          'cipher': 'also-not-base64!!!',
        }),
        isNull,
      );
    });

    test('returns null when decrypted plaintext is not a JSON object', () {
      // Forge an envelope whose plaintext is the string "42" — a valid JSON
      // value but not an object. decryptPayload must reject it.
      final key = Key.fromSecureRandom(32);
      sync.setMasterKeyForTesting(key);
      final iv = IV.fromSecureRandom(16);
      final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
      final encrypted = encrypter.encrypt('42', iv: iv);

      final result = sync.decryptPayload({
        'v': 1,
        'iv': iv.base64,
        'cipher': encrypted.base64,
      });
      expect(result, isNull);
    });
  });
}
