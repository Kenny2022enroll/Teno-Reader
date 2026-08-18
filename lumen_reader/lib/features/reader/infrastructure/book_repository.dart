import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

import '../domain/entities/book_entity.dart';
import '../domain/entities/reading_entities.dart';
import '../domain/repositories/book_repository.dart';
import '../../../core/storage/storage_service.dart';
import 'epub_parser.dart';
import 'pdf_parser.dart';

final bookRepositoryProvider = Provider<BookRepository>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return BookRepositoryImpl(storage);
});

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService(const FlutterSecureStorage(), Logger());
});

class BookRepositoryImpl implements BookRepository {
  BookRepositoryImpl(this._storage);
  final StorageService _storage;
  final _uuid = const Uuid();

  @override
  Future<List<BookEntity>> fetchAllBooks() async {
    final books = _storage.books.values.toList()
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        final ar = a.lastReadAt?.millisecondsSinceEpoch ?? 0;
        final br = b.lastReadAt?.millisecondsSinceEpoch ?? 0;
        return br.compareTo(ar);
      });
    return books;
  }

  @override
  Future<BookEntity?> fetchBook(String id) async => _storage.books.get(id);

  @override
  Future<BookEntity> addBookFromFile({
    required String filePath,
    String? title,
    String? author,
  }) async {
    // De-dupe: if a book with the same on-disk path is already on the
    // shelf, return the existing record rather than creating a duplicate.
    final canonical = _canonicalizePath(filePath);
    for (final existing in _storage.books.values) {
      if (_canonicalizePath(existing.filePath) == canonical) {
        return existing;
      }
    }

    final info = await _extractMetadata(filePath);
    final book = BookEntity(
      id: _uuid.v4(),
      title: title ?? info.title,
      author: author ?? info.author ?? 'Unknown Author',
      coverPath: info.coverPath,
      description: info.description,
      filePath: filePath,
      format: info.format,
      totalWords: info.totalWords,
      addedAt: DateTime.now(),
    );
    await _storage.saveBook(book);
    return book;
  }

  /// Lower-case + trailing-slash-stripped comparison so the same file path
  /// imported twice (e.g. once with a trailing slash, once without, or
  /// different case on case-insensitive filesystems) is treated as the
  /// same book.
  String _canonicalizePath(String path) {
    var p = path.trim();
    if (p.endsWith('/') || p.endsWith('\\')) {
      p = p.substring(0, p.length - 1);
    }
    return p.toLowerCase();
  }

  Future<BookInfo> _extractMetadata(String path) async {
    final lower = path.toLowerCase();
    if (lower.endsWith('.epub')) {
      return EpubParser().extract(path);
    }
    if (lower.endsWith('.pdf')) {
      return PdfParser().extract(path);
    }
    return BookInfo(
      title: path.split('/').last,
      author: null,
      format: lower.endsWith('.pdf') ? 'pdf' : 'txt',
    );
  }

  @override
  Future<void> updateBook(BookEntity book) => _storage.saveBook(book);

  @override
  Future<void> removeBook(String id) => _storage.deleteBook(id);

  @override
  Future<void> pinBook(String id, {required bool pinned}) async {
    final book = _storage.books.get(id);
    if (book == null) return;
    await _storage.saveBook(book.copyWith(isPinned: pinned));
  }

  @override
  Future<void> recordRead(String id) async {
    final book = _storage.books.get(id);
    if (book == null) return;
    await _storage.saveBook(book.copyWith(lastReadAt: DateTime.now()));
  }

  @override
  Future<SettingsPayload> loadSettings() async {
    final s = _storage.settings.get(0);
    if (s != null) return s;
    const d = SettingsPayload();
    await _storage.settings.put(0, d);
    return d;
  }

  @override
  Future<void> saveSettings(SettingsPayload settings) =>
      _storage.settings.put(0, settings);
}
