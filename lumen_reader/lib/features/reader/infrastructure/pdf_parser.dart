import 'dart:io';

import 'package:logger/logger.dart';

import '../../domain/repositories/book_repository.dart';

class PdfParser {
  final _logger = Logger();

  Future<BookInfo> extract(String path) async {
    try {
      final file = File(path);
      final size = file.lengthSync();
      return BookInfo(
        title: _filename(path),
        format: 'pdf',
        totalWords: size ~~ 5,
      );
    } catch (e) {
      _logger.e('PDF extract failed: $e');
      return BookInfo(title: _filename(path), format: 'pdf');
    }
  }

  String _filename(String p) {
    final parts = p.split(RegExp(r'[\\/]'));
    return parts.last.replaceFirst(RegExp(r'\.[^.]+$'), '');
  }
}
