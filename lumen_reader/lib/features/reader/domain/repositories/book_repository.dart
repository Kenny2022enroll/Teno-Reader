import '../../domain/entities/book_entity.dart';
import '../../domain/entities/reading_entities.dart';

abstract class BookRepository {
  Future<List<BookEntity>> fetchAllBooks();
  Future<BookEntity?> fetchBook(String id);
  Future<BookEntity> addBookFromFile({
    required String filePath,
    String? title,
    String? author,
  });
  Future<void> updateBook(BookEntity book);
  Future<void> removeBook(String id);
  Future<void> pinBook(String id, {required bool pinned});
  Future<void> recordRead(String id);
  Future<SettingsPayload> loadSettings();
  Future<void> saveSettings(SettingsPayload settings);
}

class BookInfo {
  final String title;
  final String? author;
  final String? description;
  final String? coverPath;
  final String format;
  final int? totalWords;

  const BookInfo({
    required this.title,
    this.author,
    this.description,
    this.coverPath,
    required this.format,
    this.totalWords,
  });
}
