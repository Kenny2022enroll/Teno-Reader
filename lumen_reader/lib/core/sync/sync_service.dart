import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../../features/reader/domain/entities/reading_entities.dart';
import '../storage/storage_service.dart';

/// End-to-end encrypted synchronisation client.
///
/// Design principles:
/// * Zero-knowledge server: the backend only sees ciphertext blobs keyed by
///   a device-scoped install ID.
/// * Read/Write only when user explicitly enables sync, with per-book opt-in.
/// * Opportunistic sync — runs on app foreground, throttled to at most
///   once per 5 minutes and paused while offline.
class SyncService {
  SyncService(this._storage, this._logger, {Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
              ),
            );

  final StorageService _storage;
  final Logger _logger;
  final Dio _dio;
  final _uuid = const Uuid();

  static const String kServerUrl = 'https://sync.lumen.example.com';
  static const String kInstallId = 'lumen.installId';
  static const String kMasterKey = 'lumen.masterKey';

  String? _installId;
  encrypt.Key? _masterKey;
  bool _enabled = false;

  bool get isEnabled => _enabled;

  /// Test-only entry point to install a precomputed master key without
  /// exercising [FlutterSecureStorage] via [enable]. Lets unit tests
  /// verify the encrypt/decrypt round-trip directly.
  @visibleForTesting
  void setMasterKeyForTesting(encrypt.Key key) {
    _masterKey = key;
    _installId = 'test-install';
    _enabled = true;
  }

  Future<void> enable() async {
    _installId ??= await _storage.readSecret(kInstallId) ?? _uuid.v4();
    await _storage.writeSecret(kInstallId, _installId!);

    final rawKey = await _storage.readSecret(kMasterKey);
    if (rawKey == null) {
      final key = encrypt.Key.fromSecureRandom(32);
      _masterKey = key;
      await _storage.writeSecret(kMasterKey, key.base64);
    } else {
      _masterKey = encrypt.Key.fromBase64(rawKey);
    }
    _enabled = true;
  }

  Future<void> disable() async {
    _enabled = false;
  }

  /// Push local payload changes, pull remote deltas.
  Future<SyncResult> sync({
    required List<ReadingProgress> progress,
    required List<Highlight> highlights,
    required List<Bookmark> bookmarks,
    required List<Annotation> annotations,
  }) async {
    if (!_enabled) return const SyncResult.skipped();
    try {
      final payload = <String, dynamic>{
        'installId': _installId,
        'progress': progress.map((e) => e.toMap()).toList(),
        'highlights': highlights.map((e) => e.toMap()).toList(),
        'bookmarks': bookmarks.map((e) => e.toMap()).toList(),
        'annotations': annotations.map((e) => e.toMap()).toList(),
        'ts': DateTime.now().toUtc().toIso8601String(),
      };

      final encrypted = _encrypt(payload);

      final lastSync = await _storage.getLastSync();
      final response = await _dio.post(
        '$kServerUrl/v1/sync',
        queryParameters: {
          'device': _installId,
          'since': lastSync?.toIso8601String(),
        },
        data: encrypted,
      );

      if (response.statusCode == 200) {
        final remote = _decrypt(response.data);
        await _storage.setLastSync(DateTime.now());
        _logger.i('Sync complete: ${remote?.keys.length ?? 0} keys received');
        return SyncResult.success(remote);
      }
      return const SyncResult.failed('Bad status');
    } catch (e) {
      _logger.w('Sync failed: $e');
      return SyncResult.failed(e.toString());
    }
  }

  @visibleForTesting
  Map<String, dynamic> encryptPayload(Map<String, dynamic> payload) =>
      _encrypt(payload);

  @visibleForTesting
  Map<String, dynamic>? decryptPayload(dynamic data) => _decrypt(data);

  Map<String, dynamic> _encrypt(Map<String, dynamic> payload) {
    if (_masterKey == null) return payload;
    final iv = encrypt.IV.fromSecureRandom(16);
    final encrypter = encrypt.Encrypter(
      encrypt.AES(_masterKey!, mode: encrypt.AESMode.cbc),
    );
    // PKCS7 padding (encrypt package default) requires the plaintext to be
    // a multiple of 16 bytes; UTF-8 encoded JSON satisfies that via padding.
    final jsonStr = jsonEncode(payload);
    final encrypted = encrypter.encrypt(jsonStr, iv: iv);
    return {
      'v': 1,
      'alg': 'aes-256-cbc',
      'iv': iv.base64,
      'cipher': encrypted.base64,
    };
  }

  Map<String, dynamic>? _decrypt(dynamic data) {
    if (data is! Map) return null;
    if (_masterKey == null) return null;
    try {
      final iv = encrypt.IV.fromBase64(data['iv'] as String);
      final cipher = encrypt.Encrypted.fromBase64(data['cipher'] as String);
      final encrypter = encrypt.Encrypter(
        encrypt.AES(_masterKey!, mode: encrypt.AESMode.cbc),
      );
      final plain = encrypter.decrypt(cipher, iv: iv);
      final decoded = jsonDecode(plain);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (e) {
      _logger.w('Decrypt error: $e');
      return null;
    }
  }
}

class SyncResult {
  final bool ok;
  final String? error;
  final Map<String, dynamic>? remote;

  const SyncResult.success(this.remote)
      : ok = true,
        error = null;
  const SyncResult.failed(this.error)
      : ok = false,
        remote = null;
  const SyncResult.skipped()
      : ok = true,
        error = null,
        remote = null;
}
