import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/reading_entities.dart';
import '../../domain/repositories/progress_repository.dart';
import '../../infrastructure/book_repository.dart';
import '../storage/storage_service.dart';

final progressRepositoryProvider = Provider<ProgressRepository>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ProgressRepositoryImpl(storage);
});

class ProgressRepositoryImpl implements ProgressRepository {
  ProgressRepositoryImpl(this._storage);
  final StorageService _storage;
  final _uuid = const Uuid();

  @override
  Future<ReadingProgress?> fetchProgress(String bookId) async {
    return _storage.progress.get(bookId);
  }

  @override
  Future<void> saveProgress(ReadingProgress progress) async {
    await _storage.progress.put(progress.bookId, progress);
  }

  @override
  Future<List<Highlight>> fetchHighlights(String bookId) async {
    return _storage.highlights.values.where((h) => h.bookId == bookId).toList()
      ..sort((a, b) => a.startOffset.compareTo(b.startOffset));
  }

  @override
  Future<Highlight> addHighlight({
    required String bookId,
    required String chapterId,
    required String selectedText,
    required int startOffset,
    required int endOffset,
    required String color,
  }) async {
    final h = Highlight(
      id: _uuid.v4(),
      bookId: bookId,
      chapterId: chapterId,
      selectedText: selectedText,
      startOffset: startOffset,
      endOffset: endOffset,
      color: color,
      createdAt: DateTime.now(),
    );
    await _storage.highlights.put(h.id, h);
    return h;
  }

  @override
  Future<void> updateHighlight(Highlight h) =>
      _storage.highlights.put(h.id, h);

  @override
  Future<void> deleteHighlight(String id) => _storage.highlights.delete(id);

  @override
  Future<List<Bookmark>> fetchBookmarks(String bookId) async {
    return _storage.bookmarks.values
        .where((b) => b.bookId == bookId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Bookmark> addBookmark({
    required String bookId,
    required String chapterId,
    required int scrollOffset,
    required String snippet,
  }) async {
    final b = Bookmark(
      id: _uuid.v4(),
      bookId: bookId,
      chapterId: chapterId,
      scrollOffset: scrollOffset,
      snippet: snippet,
      createdAt: DateTime.now(),
    );
    await _storage.bookmarks.put(b.id, b);
    return b;
  }

  @override
  Future<void> deleteBookmark(String id) => _storage.bookmarks.delete(id);

  @override
  Future<List<Annotation>> fetchAnnotations(String bookId) async {
    return _storage.annotations.values
        .where((a) => a.bookId == bookId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Annotation> addAnnotation({
    required String bookId,
    required String chapterId,
    required String anchorText,
    required int offset,
    required String note,
  }) async {
    final a = Annotation(
      id: _uuid.v4(),
      bookId: bookId,
      chapterId: chapterId,
      anchorText: anchorText,
      offset: offset,
      note: note,
      createdAt: DateTime.now(),
    );
    await _storage.annotations.put(a.id, a);
    return a;
  }

  @override
  Future<void> updateAnnotation(Annotation a) {
    return _storage.annotations.put(a.id, a);
  }

  @override
  Future<void> deleteAnnotation(String id) => _storage.annotations.delete(id);

  @override
  Future<List<Highlight>> fetchAllHighlights() =>
      Future.value(_storage.highlights.values.toList());

  @override
  Future<List<Bookmark>> fetchAllBookmarks() =>
      Future.value(_storage.bookmarks.values.toList());

  @override
  Future<List<Annotation>> fetchAllAnnotations() =>
      Future.value(_storage.annotations.values.toList());
}
