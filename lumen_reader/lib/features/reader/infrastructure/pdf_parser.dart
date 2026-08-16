import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
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

      String? coverPath;
      try {
        coverPath = await extractCoverImage(path);
      } catch (_) {}

      return BookInfo(
        title: title,
        author: author,
        format: 'pdf',
        coverPath: coverPath,
        totalWords: size ~/ 5,
      );
    } catch (e) {
      _logger.e('PDF extract failed: $e');
      return BookInfo(title: _filename(path), format: 'pdf');
    }
  }

  Future<String?> extractCoverImage(String filePath) async {
    final tmpPath =
        '${Directory.systemTemp.path}/cover_${filePath.hashCode}.png';
    final tmp = File(tmpPath);
    if (tmp.existsSync() && tmp.lengthSync() > 1024) {
      return tmpPath;
    }

    try {
      final bytes = File(filePath).readAsBytesSync();
      final document = PdfDocument(inputBytes: bytes);
      try {
        if (document.pages.count > 0) {
          // ignore: unused_local_variable
          final page = document.pages[0];
        }
      } finally {
        document.dispose();
      }
    } catch (_) {}

    return _generateFallbackCover(tmpPath);
  }

  static Future<String?> _generateFallbackCover(String outPath) async {
    try {
      const width = 240;
      const height = 320;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      final gradient = ui.Gradient.linear(
        const Offset(0, 0),
        const Offset(width.toDouble(), height.toDouble()),
        [
          const Color(0xFF667eea),
          const Color(0xFF764ba2),
        ],
      );
      final paint = Paint()..shader = gradient;
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        paint,
      );

      final builder = ui.ParagraphBuilder(
        ui.ParagraphStyle(
          textAlign: TextAlign.center,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: const Color(0xFFFFFFFF),
        ),
      )..pushStyle(ui.TextStyle(color: const Color(0xFFFFFFFF)));
      builder.addText('PDF');
      final paragraph = builder.build()
        ..layout(const ui.ParagraphConstraints(width: width.toDouble()));
      canvas.drawParagraph(
        paragraph,
        Offset(0, (height - paragraph.height) / 2),
      );

      final picture = recorder.endRecording();
      final img = await picture.toImage(width, height);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      final bytes = byteData.buffer.asUint8List();

      final file = File(outPath);
      await file.writeAsBytes(bytes);
      return outPath;
    } catch (_) {
      return null;
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
