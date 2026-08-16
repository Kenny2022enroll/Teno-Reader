import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';

import '../../features/reader/domain/entities/book_entity.dart';
import '../../features/reader/domain/entities/reading_entities.dart';
import '../webdav/webdav_models.dart';
import 'storage_constants.dart';

/// Service layer abstraction for local persistence.
///
/// Hive stores structured, queryable data.
/// Sensitive keys (e.g. sync tokens) are kept in [FlutterSecureStorage].
class StorageService {
  StorageService(this._secure, this._logger);
  final FlutterSecureStorage _secure;
  final Logger _logger;

  // MARK: - Books

  Box<BookEntity> get books => Hive.box<BookEntity>(kBooksBoxName);
  Box<ReadingProgress> get progress =>
      Hive.box<ReadingProgress>(kProgressBoxName);
  Box<Highlight> get highlights => Hive.box<Highlight>(kHighlightBoxName);
  Box<Bookmark> get bookmarks => Hive.box<Bookmark>(kBookmarkBoxName);
  Box<Annotation> get annotations => Hive.box<Annotation>(kAnnotationBoxName);
  Box<SettingsPayload> get settings =>
      Hive.box<SettingsPayload>(kSettingsBoxName);

  Future<void> saveBook(BookEntity book) async {
    await books.put(book.id, book);
    _logger.d('Saved book ${book.id}');
  }

  Future<void> deleteBook(String id) async {
    await books.delete(id);
    await progress.delete(id);
    final hs = highlights.values.where((h) => h.bookId == id).toList();
    for (final h in hs) {
      await highlights.delete(h.id);
    }
    final bms = bookmarks.values.where((b) => b.bookId == id).toList();
    for (final b in bms) {
      await bookmarks.delete(b.id);
    }
    final ans = annotations.values.where((a) => a.bookId == id).toList();
    for (final a in ans) {
      await annotations.delete(a.id);
    }
  }

  // MARK: - Secure

  Future<void> writeSecret(String key, String value) async {
    await _secure.write(key: key, value: value);
  }

  Future<String?> readSecret(String key) => _secure.read(key: key);

  Future<void> deleteSecret(String key) => _secure.delete(key: key);

  // MARK: - Sync watermark

  static const String kLastSyncKey = 'lumen.lastSync';

  Future<DateTime?> getLastSync() async {
    final raw = await _secure.read(key: kLastSyncKey);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<void> setLastSync(DateTime dt) async {
    await _secure.write(key: kLastSyncKey, value: dt.toIso8601String());
  }

  // MARK: - WebDAV Settings

  static const String kWebDAVSettingsKey = 'webdav.settings';

  Future<void> saveWebDAVSettings(WebDAVSettings s) async {
    final box = Hive.box(kSettingsBoxName);
    await box.put(kWebDAVSettingsKey, s);
    _logger.d('Saved WebDAV settings');
  }

  Future<WebDAVSettings?> loadWebDAVSettings() async {
    final box = Hive.box(kSettingsBoxName);
    return box.get(kWebDAVSettingsKey) as WebDAVSettings?;
  }
}
