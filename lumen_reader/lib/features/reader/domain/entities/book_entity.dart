import 'package:equatable/equatable.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';

part 'book_entity.g.dart';

@HiveType(typeId: 1)
@JsonSerializable()
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

  factory BookEntity.fromJson(Map<String, dynamic> json) =>
      _$BookEntityFromJson(json);
  Map<String, dynamic> toJson() => _$BookEntityToJson(this);

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
