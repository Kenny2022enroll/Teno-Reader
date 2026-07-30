import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'core/storage/hive_adapters.dart';
import 'core/storage/storage_constants.dart';
import 'core/storage/storage_service.dart';
import 'features/reader/domain/entities/book_entity.dart';
import 'features/reader/domain/entities/reading_entities.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final logger = Logger(
    printer: PrettyPrinter(),
    level: Level.info,
  );

  try {
    final dir = await getApplicationSupportDirectory();
    await Hive.initFlutter(dir.path);

    // Register Hive adapters
    Hive.registerAdapter(BookAdapter());
    Hive.registerAdapter(ReadingProgressAdapter());
    Hive.registerAdapter(HighlightAdapter());
    Hive.registerAdapter(BookmarkAdapter());
    Hive.registerAdapter(AnnotationAdapter());
    Hive.registerAdapter(SettingsPayloadAdapter());

    await Hive.openBox<Book>(kBooksBoxName);
    await Hive.openBox<ReadingProgress>(kProgressBoxName);
    await Hive.openBox<Highlight>(kHighlightBoxName);
    await Hive.openBox<Bookmark>(kBookmarkBoxName);
    await Hive.openBox<Annotation>(kAnnotationBoxName);
    await Hive.openBox<SettingsPayload>(kSettingsBoxName);

    logger.i('Hive storage initialized at ${dir.path}');
  } catch (e) {
    logger.e('Failed to initialize local storage: $e');
  }

  runApp(const ProviderScope(child: LumenApp()));
}
