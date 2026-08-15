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
      String title = _filename(path);
      String? author;

      // Try to extract metadata from the PDF itself (documentInformation
      // is the stable Syncfusion API available across versions).
      try {
        final bytes = file.readAsBytesSync();
        final document = PdfDocument(inputBytes: bytes);
        try {
          final info = document.documentInformation;
          final t = info.title;
          // ignore: unnecessary_null_comparison
          if (t != null && t.isNotEmpty) {
            title = t;
          }
          final a = info.author;
          // ignore: unnecessary_null_comparison
          if (a != null && a.isNotEmpty) {
            author = a;
          }
        } catch (_) {}
        document.dispose();
      } catch (_) {}

      return BookInfo(
        title: title,
        author: author,
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
      final result = await compute(_extractTextSync, path);
      if (result.trim().isEmpty) {
        // Some scanned-image PDFs will return empty text.
        return '（此 PDF 可能为扫描件或图片版，暂无可用文本内容）\n\n'
            '如需提取文字，请使用 OCR 功能对 PDF 进行识别后再导入。';
      }
      return result;
    } catch (e) {
      _logger.e('PDF text extraction failed: $e');
      return '（读取 PDF 时发生错误：$e）\n\n'
          '建议：请尝试将文件转换为其他格式后重新导入。';
    }
  }

  static String _extractTextSync(String path) {
    final bytes = File(path).readAsBytesSync();
    if (bytes.isEmpty) return '';
    final document = PdfDocument(inputBytes: bytes);
    try {
      final extractor = PdfTextExtractor(document);
      // Use plain extractText() — the layoutOptions parameter is not
      // available on all Syncfusion package versions, so we use the
      // simpler, stable overload.
      final text = extractor.extractText();
      return text;
    } finally {
      document.dispose();
    }
  }

  String _filename(String p) {
    final parts = p.split(RegExp(r'[\\/]'));
    return parts.last.replaceFirst(RegExp(r'\.[^.]+$'), '');
  }
}
