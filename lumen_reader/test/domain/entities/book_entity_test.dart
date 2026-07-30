import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_reader/features/reader/domain/entities/book_entity.dart';

void main() {
  group('BookEntity', () {
    final addedAt = DateTime.utc(2026, 7, 30, 10, 0, 0);

    BookEntity buildEntity({
      String id = 'b1',
      String title = 'The Pragmatic Programmer',
      String author = 'Hunt & Thomas',
      String? coverPath,
      String? description,
      String filePath = '/books/pp.epub',
      String format = 'epub',
      int? totalWords,
      DateTime? lastReadAt,
      bool isPinned = false,
    }) {
      return BookEntity(
        id: id,
        title: title,
        author: author,
        coverPath: coverPath,
        description: description,
        filePath: filePath,
        format: format,
        totalWords: totalWords,
        addedAt: addedAt,
        lastReadAt: lastReadAt,
        isPinned: isPinned,
      );
    }

    test('toJson/fromJson round-trips all fields', () {
      final book = buildEntity(
        coverPath: '/covers/pp.png',
        description: 'A book about programming.',
        totalWords: 42000,
        lastReadAt: DateTime.utc(2026, 7, 29, 8, 30),
        isPinned: true,
      );

      final restored = BookEntity.fromJson(book.toJson());

      expect(restored, equals(book));
    });

    test('fromJson restores null optionals and default isPinned', () {
      final book = buildEntity();

      final restored = BookEntity.fromJson(book.toJson());

      expect(restored.coverPath, isNull);
      expect(restored.description, isNull);
      expect(restored.totalWords, isNull);
      expect(restored.lastReadAt, isNull);
      expect(restored.isPinned, isFalse);
    });

    test('copyWith overrides only the provided fields', () {
      final book = buildEntity();

      final updated = book.copyWith(
        title: 'Clean Code',
        isPinned: true,
        lastReadAt: addedAt,
      );

      expect(updated.id, book.id);
      expect(updated.author, book.author);
      expect(updated.filePath, book.filePath);
      expect(updated.title, 'Clean Code');
      expect(updated.isPinned, isTrue);
      expect(updated.lastReadAt, addedAt);
    });

    test('copyWith with no args returns an equal entity', () {
      final book = buildEntity(description: 'desc', totalWords: 10);

      expect(book.copyWith(), equals(book));
    });

    test('entities differing by id are not equal', () {
      expect(buildEntity(id: 'a'), isNot(equals(buildEntity(id: 'b'))));
    });
  });
}
