import 'package:equatable/equatable.dart';
import 'package:hive_flutter/hive_flutter.dart';

@HiveType(typeId: 1)
class BookEntity extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String author;

  @HiveField(3)
  final String? coverPath;

  @HiveField(4)
  final String? description;

  @HiveField(5)
  final String filePath;

  @HiveField(6)
  final String format; // epub | pdf | txt

  @HiveField(7)
  final int? totalWords;

  @HiveField(8)
  final DateTime addedAt;

  @HiveField(9)
  final DateTime? lastReadAt;

  @HiveField(10)
  final bool isPinned;

  const BookEntity({
    required this.id,
    required this.title,
    required this.author,
    this.coverPath,
    this.description,
    required this.filePath,
    required this.format,
    this.totalWords,
    required this.addedAt,
    this.lastReadAt,
    this.isPinned = false,
  });

  BookEntity copyWith({
    String? id,
    String? title,
    String? author,
    String? coverPath,
    String? description,
    String? filePath,
    String? format,
    int? totalWords,
    DateTime? addedAt,
    DateTime? lastReadAt,
    bool? isPinned,
  }) {
    return BookEntity(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      coverPath: coverPath ?? this.coverPath,
      description: description ?? this.description,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      totalWords: totalWords ?? this.totalWords,
      addedAt: addedAt ?? this.addedAt,
      lastReadAt: lastReadAt ?? this.lastReadAt,
      isPinned: isPinned ?? this.isPinned,
    );
  }

  factory BookEntity.fromJson(Map<String, dynamic> json) => BookEntity(
    id: json['id'] as String,
    title: json['title'] as String,
    author: json['author'] as String,
    coverPath: json['coverPath'] as String?,
    description: json['description'] as String?,
    filePath: json['filePath'] as String,
    format: json['format'] as String,
    totalWords: json['totalWords'] as int?,
    addedAt: DateTime.parse(json['addedAt'] as String),
    lastReadAt: json['lastReadAt'] == null
        ? null
        : DateTime.parse(json['lastReadAt'] as String),
    isPinned: json['isPinned'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'author': author,
    'coverPath': coverPath,
    'description': description,
    'filePath': filePath,
    'format': format,
    'totalWords': totalWords,
    'addedAt': addedAt.toIso8601String(),
    'lastReadAt': lastReadAt?.toIso8601String(),
    'isPinned': isPinned,
  };

  @override
  List<Object?> get props => [
    id,
    title,
    author,
    coverPath,
    description,
    filePath,
    format,
    totalWords,
    addedAt,
    lastReadAt,
    isPinned,
  ];
}
