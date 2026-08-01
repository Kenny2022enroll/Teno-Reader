import 'dart:io';

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
      final bytes = File(path).readAsBytesSync();
      final document = PdfDocument(inputBytes: bytes);
      final extractor = PdfTextExtractor(document);

      final buffer = StringBuffer();
      for (int i = 0; i < document.pages.count; i++) {
        final text = extractor.extractTextFromPage(i);
        if (text.isNotEmpty) {
          if (buffer.isNotEmpty) buffer.write('\n\n');
          buffer.write(text);
        }
      }

      document.dispose();
      return buffer.toString();
    } catch (e) {
      _logger.e('PDF text extraction failed: $e');
      return '';
    }
  }

  String _filename(String p) {
    final parts = p.split(RegExp(r'[\\/]'));
    return parts.last.replaceFirst(RegExp(r'\.[^.]+$'), '');
  }
}
