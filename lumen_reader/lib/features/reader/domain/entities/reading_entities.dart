import 'package:equatable/equatable.dart';
import 'package:hive_flutter/hive_flutter.dart';

@HiveType(typeId: 2)
class ReadingProgress extends Equatable {
  @HiveField(0)
  final String bookId;

  @HiveField(1)
  final String chapterId;

  @HiveField(2)
  final double progress; // 0.0 - 1.0

  @HiveField(3)
  final int scrollOffset;

  @HiveField(4)
  final int totalWordsRead;

  @HiveField(5)
  final DateTime updatedAt;

  const ReadingProgress({
    required this.bookId,
    required this.chapterId,
    required this.progress,
    required this.scrollOffset,
    required this.totalWordsRead,
    required this.updatedAt,
  });

  ReadingProgress copyWith({
    String? bookId,
    String? chapterId,
    double? progress,
    int? scrollOffset,
    int? totalWordsRead,
    DateTime? updatedAt,
  }) {
    return ReadingProgress(
      bookId: bookId ?? this.bookId,
      chapterId: chapterId ?? this.chapterId,
      progress: progress ?? this.progress,
      scrollOffset: scrollOffset ?? this.scrollOffset,
      totalWordsRead: totalWordsRead ?? this.totalWordsRead,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'bookId': bookId,
    'chapterId': chapterId,
    'progress': progress,
    'scrollOffset': scrollOffset,
    'totalWordsRead': totalWordsRead,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory ReadingProgress.fromMap(Map<String, dynamic> map) =>
      ReadingProgress(
        bookId: map['bookId'] as String,
        chapterId: map['chapterId'] as String,
        progress: (map['progress'] as num).toDouble(),
        scrollOffset: map['scrollOffset'] as int,
        totalWordsRead: map['totalWordsRead'] as int,
        updatedAt: DateTime.parse(map['updatedAt'] as String),
      );

  @override
  List<Object?> get props => [bookId, chapterId, progress, scrollOffset, totalWordsRead, updatedAt];
}

@HiveType(typeId: 3)
class Highlight extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String bookId;

  @HiveField(2)
  final String chapterId;

  @HiveField(3)
  final String selectedText;

  @HiveField(4)
  final int startOffset;

  @HiveField(5)
  final int endOffset;

  @HiveField(6)
  final String color; // yellow|green|blue|pink

  @HiveField(7)
  final DateTime createdAt;

  const Highlight({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.selectedText,
    required this.startOffset,
    required this.endOffset,
    required this.color,
    required this.createdAt,
  });

  Highlight copyWith({
    String? id, String? bookId, String? chapterId, String? selectedText,
    int? startOffset, int? endOffset, String? color, DateTime? createdAt,
  }) => Highlight(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    chapterId: chapterId ?? this.chapterId,
    selectedText: selectedText ?? this.selectedText,
    startOffset: startOffset ?? this.startOffset,
    endOffset: endOffset ?? this.endOffset,
    color: color ?? this.color,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'bookId': bookId, 'chapterId': chapterId,
    'selectedText': selectedText, 'startOffset': startOffset,
    'endOffset': endOffset, 'color': color,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Highlight.fromMap(Map<String, dynamic> m) => Highlight(
    id: m['id'] as String,
    bookId: m['bookId'] as String,
    chapterId: m['chapterId'] as String,
    selectedText: m['selectedText'] as String,
    startOffset: m['startOffset'] as int,
    endOffset: m['endOffset'] as int,
    color: m['color'] as String,
    createdAt: DateTime.parse(m['createdAt'] as String),
  );

  @override
  List<Object?> get props => [id, bookId, chapterId, selectedText, startOffset, endOffset, color, createdAt];
}

@HiveType(typeId: 4)
class Bookmark extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String bookId;

  @HiveField(2)
  final String chapterId;

  @HiveField(3)
  final int scrollOffset;

  @HiveField(4)
  final String snippet;

  @HiveField(5)
  final DateTime createdAt;

  const Bookmark({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.scrollOffset,
    required this.snippet,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id, 'bookId': bookId, 'chapterId': chapterId,
    'scrollOffset': scrollOffset, 'snippet': snippet,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Bookmark.fromMap(Map<String, dynamic> m) => Bookmark(
    id: m['id'] as String,
    bookId: m['bookId'] as String,
    chapterId: m['chapterId'] as String,
    scrollOffset: m['scrollOffset'] as int,
    snippet: m['snippet'] as String,
    createdAt: DateTime.parse(m['createdAt'] as String),
  );

  @override
  List<Object?> get props => [id, bookId, chapterId, scrollOffset, snippet, createdAt];
}

@HiveType(typeId: 5)
class Annotation extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String bookId;

  @HiveField(2)
  final String chapterId;

  @HiveField(3)
  final String anchorText;

  @HiveField(4)
  final int offset;

  @HiveField(5)
  final String note;

  @HiveField(6)
  final DateTime createdAt;

  @HiveField(7)
  final DateTime? updatedAt;

  const Annotation({
    required this.id,
    required this.bookId,
    required this.chapterId,
    required this.anchorText,
    required this.offset,
    required this.note,
    required this.createdAt,
    this.updatedAt,
  });

  Annotation copyWith({
    String? id, String? bookId, String? chapterId, String? anchorText,
    int? offset, String? note, DateTime? createdAt, DateTime? updatedAt,
  }) => Annotation(
    id: id ?? this.id,
    bookId: bookId ?? this.bookId,
    chapterId: chapterId ?? this.chapterId,
    anchorText: anchorText ?? this.anchorText,
    offset: offset ?? this.offset,
    note: note ?? this.note,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id, 'bookId': bookId, 'chapterId': chapterId,
    'anchorText': anchorText, 'offset': offset, 'note': note,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt?.toIso8601String(),
  };

  factory Annotation.fromMap(Map<String, dynamic> m) => Annotation(
    id: m['id'] as String,
    bookId: m['bookId'] as String,
    chapterId: m['chapterId'] as String,
    anchorText: m['anchorText'] as String,
    offset: m['offset'] as int,
    note: m['note'] as String,
    createdAt: DateTime.parse(m['createdAt'] as String),
    updatedAt: m['updatedAt'] == null
        ? null
        : DateTime.parse(m['updatedAt'] as String),
  );

  @override
  List<Object?> get props => [id, bookId, chapterId, anchorText, offset, note, createdAt, updatedAt];
}

@HiveType(typeId: 6)
class SettingsPayload extends Equatable {
  @HiveField(0)
  final double fontSize;

  @HiveField(1)
  final String fontFamily;

  @HiveField(2)
  final String theme; // light|dark|sepia|paper

  @HiveField(3)
  final bool autoNightMode;

  @HiveField(4)
  final double lineHeight;

  @HiveField(5)
  final double paragraphSpacing;

  @HiveField(6)
  final String pageTurnStyle; // curl|slide|none

  @HiveField(7)
  final bool keepScreenAwake;

  @HiveField(8)
  final bool syncEnabled;

  @HiveField(9)
  final bool reducedMotion;

  @HiveField(10)
  final bool largeText;

  const SettingsPayload({
    this.fontSize = 17,
    this.fontFamily = 'SF Pro Text',
    this.theme = 'light',
    this.autoNightMode = false,
    this.lineHeight = 1.6,
    this.paragraphSpacing = 1.2,
    this.pageTurnStyle = 'slide',
    this.keepScreenAwake = true,
    this.syncEnabled = false,
    this.reducedMotion = false,
    this.largeText = false,
  });

  SettingsPayload copyWith({
    double? fontSize, String? fontFamily, String? theme,
    bool? autoNightMode, double? lineHeight, double? paragraphSpacing,
    String? pageTurnStyle, bool? keepScreenAwake, bool? syncEnabled,
    bool? reducedMotion, bool? largeText,
  }) => SettingsPayload(
    fontSize: fontSize ?? this.fontSize,
    fontFamily: fontFamily ?? this.fontFamily,
    theme: theme ?? this.theme,
    autoNightMode: autoNightMode ?? this.autoNightMode,
    lineHeight: lineHeight ?? this.lineHeight,
    paragraphSpacing: paragraphSpacing ?? this.paragraphSpacing,
    pageTurnStyle: pageTurnStyle ?? this.pageTurnStyle,
    keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
    syncEnabled: syncEnabled ?? this.syncEnabled,
    reducedMotion: reducedMotion ?? this.reducedMotion,
    largeText: largeText ?? this.largeText,
  );

  Map<String, dynamic> toMap() => {
    'fontSize': fontSize, 'fontFamily': fontFamily, 'theme': theme,
    'autoNightMode': autoNightMode, 'lineHeight': lineHeight,
    'paragraphSpacing': paragraphSpacing, 'pageTurnStyle': pageTurnStyle,
    'keepScreenAwake': keepScreenAwake, 'syncEnabled': syncEnabled,
    'reducedMotion': reducedMotion, 'largeText': largeText,
  };

  factory SettingsPayload.fromMap(Map<String, dynamic> m) => SettingsPayload(
    fontSize: (m['fontSize'] as num?)?.toDouble() ?? 17,
    fontFamily: m['fontFamily'] as String? ?? 'SF Pro Text',
    theme: m['theme'] as String? ?? 'light',
    autoNightMode: m['autoNightMode'] as bool? ?? false,
    lineHeight: (m['lineHeight'] as num?)?.toDouble() ?? 1.6,
    paragraphSpacing: (m['paragraphSpacing'] as num?)?.toDouble() ?? 1.2,
    pageTurnStyle: m['pageTurnStyle'] as String? ?? 'slide',
    keepScreenAwake: m['keepScreenAwake'] as bool? ?? true,
    syncEnabled: m['syncEnabled'] as bool? ?? false,
    reducedMotion: m['reducedMotion'] as bool? ?? false,
    largeText: m['largeText'] as bool? ?? false,
  );

  @override
  List<Object?> get props => [
    fontSize, fontFamily, theme, autoNightMode, lineHeight,
    paragraphSpacing, pageTurnStyle, keepScreenAwake, syncEnabled,
    reducedMotion, largeText,
  ];
}
