import '../../domain/entities/reading_entities.dart';

abstract class ProgressRepository {
  Future<ReadingProgress?> fetchProgress(String bookId);
  Future<void> saveProgress(ReadingProgress progress);

  Future<List<Highlight>> fetchHighlights(String bookId);
  Future<Highlight> addHighlight({
    required String bookId,
    required String chapterId,
    required String selectedText,
    required int startOffset,
    required int endOffset,
    required String color,
  });
  Future<void> updateHighlight(Highlight h);
  Future<void> deleteHighlight(String id);

  Future<List<Bookmark>> fetchBookmarks(String bookId);
  Future<Bookmark> addBookmark({
    required String bookId,
    required String chapterId,
    required int scrollOffset,
    required String snippet,
  });
  Future<void> deleteBookmark(String id);

  Future<List<Annotation>> fetchAnnotations(String bookId);
  Future<Annotation> addAnnotation({
    required String bookId,
    required String chapterId,
    required String anchorText,
    required int offset,
    required String note,
  });
  Future<void> updateAnnotation(Annotation a);
  Future<void> deleteAnnotation(String id);

  Future<List<Highlight>> fetchAllHighlights();
  Future<List<Bookmark>> fetchAllBookmarks();
  Future<List<Annotation>> fetchAllAnnotations();
}
