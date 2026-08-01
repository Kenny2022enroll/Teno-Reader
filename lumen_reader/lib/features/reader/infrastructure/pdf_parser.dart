import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../domain/repositories/book_repository.dart';

class PdfParser {
  final _logger = Logger();

  Future<BookInfo> extract(String path) async {
    try {
      final file = File(path);
      final size = file.lengthSync();
      return BookInfo(
        title: _filename(path),
        format: 'pdf',
        totalWords: size ~/ 5,
      );
    } catch (e) {
      _logger.e('PDF extract failed: $e');
      return BookInfo(title: _filename(path), format: 'pdf');
    }
  }

  /// Extract all text from a PDF file, joining pages with newlines.
  Future<String> extractText(String path) async {
    try {
      return await compute(_extractTextSync, path);
    } catch (e) {
      _logger.e('PDF text extraction failed: $e');
      return '';
    }
  }

  static String _extractTextSync(String path) {
    final bytes = File(path).readAsBytesSync();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final text = extractor.extractText();
    document.dispose();
    return text;
  }

  String _filename(String p) {
    final parts = p.split(RegExp(r'[\\/]'));
    return parts.last.replaceFirst(RegExp(r'\.[^.]+$'), '');
  }
}
