import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:lumen_reader/core/storage/hive_adapters.dart';
import 'package:lumen_reader/features/reader/domain/entities/book_entity.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('lumen_hive_test_');
    Hive.init(tempDir.path);
    // Hive.deleteFromDisk() between tests only wipes boxes + files, not the
    // adapter registry — registering twice throws "Adapter for typeId is
    // already registered". Guard against the duplicate registration.
    if (!Hive.isAdapterRegistered(BookAdapter().typeId)) {
      Hive.registerAdapter(BookAdapter());
    }
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<Box<BookEntity>> openBox() =>
      Hive.openBox<BookEntity>('test_books.db');

  group('BookAdapter round-trip', () {
    test('preserves null totalWords', () async {
      final box = await openBox();
      final book = BookEntity(
        id: 'b1',
        title: 'Refactoring',
        author: 'Martin Fowler',
        filePath: '/books/ref.epub',
        format: 'epub',
        addedAt: DateTime.utc(2026, 8, 18, 10, 0),
        // totalWords deliberately null
      );

      await box.put('b1', book);
      // Close + reopen to force a real disk read round-trip.
      await box.close();
      final reopened = await openBox();

      final restored = reopened.get('b1');
      expect(restored, isNotNull);
      expect(restored!.totalWords, isNull,
          reason: 'Adapter must round-trip null, not coerce to 0');
      expect(restored.title, 'Refactoring');
      expect(restored.isPinned, isFalse);
    });

    test('preserves a non-null totalWords value', () async {
      final box = await openBox();
      final book = BookEntity(
        id: 'b2',
        title: 'Clean Code',
        author: 'Robert C. Martin',
        filePath: '/books/cc.epub',
        format: 'epub',
        totalWords: 67890,
        addedAt: DateTime.utc(2026, 8, 18, 10, 0),
        lastReadAt: DateTime.utc(2026, 8, 19, 9, 30),
        isPinned: true,
      );

      await box.put('b2', book);
      await box.close();
      final reopened = await openBox();

      final restored = reopened.get('b2');
      expect(restored, isNotNull);
      expect(restored!.totalWords, 67890);
      expect(restored.lastReadAt, DateTime.utc(2026, 8, 19, 9, 30));
      expect(restored.isPinned, isTrue);
    });
  });
}
