import 'package:hive_flutter/hive_flutter.dart';

import '../../features/reader/domain/entities/book_entity.dart';
import '../../features/reader/domain/entities/reading_entities.dart';

class BookAdapter extends TypeAdapter<BookEntity> {
  @override
  final int typeId = 1;

  @override
  BookEntity read(BinaryReader reader) {
    return BookEntity(
      id: reader.readString(),
      title: reader.readString(),
      author: reader.readString(),
      coverPath: reader.readBool() ? reader.readString() : null,
      description: reader.readBool() ? reader.readString() : null,
      filePath: reader.readString(),
      format: reader.readString(),
      totalWords: reader.readInt(),
      addedAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      lastReadAt: reader.readBool()
          ? DateTime.fromMillisecondsSinceEpoch(reader.readInt())
          : null,
      isPinned: reader.readBool(),
    );
  }

  @override
  void write(BinaryWriter writer, BookEntity obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    writer.writeString(obj.author);
    writer.writeBool(obj.coverPath != null);
    if (obj.coverPath != null) writer.writeString(obj.coverPath!);
    writer.writeBool(obj.description != null);
    if (obj.description != null) writer.writeString(obj.description!);
    writer.writeString(obj.filePath);
    writer.writeString(obj.format);
    writer.writeInt(obj.totalWords ?? 0);
    writer.writeInt(obj.addedAt.millisecondsSinceEpoch);
    writer.writeBool(obj.lastReadAt != null);
    if (obj.lastReadAt != null) {
      writer.writeInt(obj.lastReadAt!.millisecondsSinceEpoch);
    }
    writer.writeBool(obj.isPinned);
  }
}

class ReadingProgressAdapter extends TypeAdapter<ReadingProgress> {
  @override
  final int typeId = 2;

  @override
  ReadingProgress read(BinaryReader r) => ReadingProgress(
    bookId: r.readString(),
    chapterId: r.readString(),
    progress: r.readDouble(),
    scrollOffset: r.readInt(),
    totalWordsRead: r.readInt(),
    updatedAt: DateTime.fromMillisecondsSinceEpoch(r.readInt()),
  );

  @override
  void write(BinaryWriter w, ReadingProgress obj) {
    w.writeString(obj.bookId);
    w.writeString(obj.chapterId);
    w.writeDouble(obj.progress);
    w.writeInt(obj.scrollOffset);
    w.writeInt(obj.totalWordsRead);
    w.writeInt(obj.updatedAt.millisecondsSinceEpoch);
  }
}

class HighlightAdapter extends TypeAdapter<Highlight> {
  @override
  final int typeId = 3;

  @override
  Highlight read(BinaryReader r) => Highlight(
    id: r.readString(),
    bookId: r.readString(),
    chapterId: r.readString(),
    selectedText: r.readString(),
    startOffset: r.readInt(),
    endOffset: r.readInt(),
    color: r.readString(),
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.readInt()),
  );

  @override
  void write(BinaryWriter w, Highlight obj) {
    w.writeString(obj.id);
    w.writeString(obj.bookId);
    w.writeString(obj.chapterId);
    w.writeString(obj.selectedText);
    w.writeInt(obj.startOffset);
    w.writeInt(obj.endOffset);
    w.writeString(obj.color);
    w.writeInt(obj.createdAt.millisecondsSinceEpoch);
  }
}

class BookmarkAdapter extends TypeAdapter<Bookmark> {
  @override
  final int typeId = 4;

  @override
  Bookmark read(BinaryReader r) => Bookmark(
    id: r.readString(),
    bookId: r.readString(),
    chapterId: r.readString(),
    scrollOffset: r.readInt(),
    snippet: r.readString(),
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.readInt()),
  );

  @override
  void write(BinaryWriter w, Bookmark obj) {
    w.writeString(obj.id);
    w.writeString(obj.bookId);
    w.writeString(obj.chapterId);
    w.writeInt(obj.scrollOffset);
    w.writeString(obj.snippet);
    w.writeInt(obj.createdAt.millisecondsSinceEpoch);
  }
}

class AnnotationAdapter extends TypeAdapter<Annotation> {
  @override
  final int typeId = 5;

  @override
  Annotation read(BinaryReader r) => Annotation(
    id: r.readString(),
    bookId: r.readString(),
    chapterId: r.readString(),
    anchorText: r.readString(),
    offset: r.readInt(),
    note: r.readString(),
    createdAt: DateTime.fromMillisecondsSinceEpoch(r.readInt()),
    updatedAt: r.readBool()
        ? DateTime.fromMillisecondsSinceEpoch(r.readInt())
        : null,
  );

  @override
  void write(BinaryWriter w, Annotation obj) {
    w.writeString(obj.id);
    w.writeString(obj.bookId);
    w.writeString(obj.chapterId);
    w.writeString(obj.anchorText);
    w.writeInt(obj.offset);
    w.writeString(obj.note);
    w.writeInt(obj.createdAt.millisecondsSinceEpoch);
    w.writeBool(obj.updatedAt != null);
    if (obj.updatedAt != null) {
      w.writeInt(obj.updatedAt!.millisecondsSinceEpoch);
    }
  }
}

class SettingsPayloadAdapter extends TypeAdapter<SettingsPayload> {
  @override
  final int typeId = 6;

  @override
  SettingsPayload read(BinaryReader r) => SettingsPayload(
    fontSize: r.readDouble(),
    fontFamily: r.readString(),
    theme: r.readString(),
    autoNightMode: r.readBool(),
    lineHeight: r.readDouble(),
    paragraphSpacing: r.readDouble(),
    pageTurnStyle: r.readString(),
    keepScreenAwake: r.readBool(),
    syncEnabled: r.readBool(),
    reducedMotion: r.readBool(),
    largeText: r.readBool(),
  );

  @override
  void write(BinaryWriter w, SettingsPayload obj) {
    w.writeDouble(obj.fontSize);
    w.writeString(obj.fontFamily);
    w.writeString(obj.theme);
    w.writeBool(obj.autoNightMode);
    w.writeDouble(obj.lineHeight);
    w.writeDouble(obj.paragraphSpacing);
    w.writeString(obj.pageTurnStyle);
    w.writeBool(obj.keepScreenAwake);
    w.writeBool(obj.syncEnabled);
    w.writeBool(obj.reducedMotion);
    w.writeBool(obj.largeText);
  }
}
