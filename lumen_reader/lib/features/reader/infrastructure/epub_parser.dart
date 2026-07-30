import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../../domain/repositories/book_repository.dart';

/// Lightweight EPUB metadata / content extractor.
/// Full rendering is delegated to a dedicated epub widget in production;
/// here we only pull metadata + plain-text chapter content.
class EpubParser {
  Future<BookInfo> extract(String path) async {
    final bytes = File(path).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    String? opfPath;
    final container = archive.findFile('META-INF/container.xml');
    if (container != null) {
      final xml = XmlDocument.parse(String.fromCharCodes(container.content));
      opfPath = xml
          .findElements('rootfile')
          .first
          .getAttribute('full-path');
    }
    opfPath ??= 'OEBPS/content.opf';

    final opf = archive.findFile(opfPath);
    if (opf == null) {
      return const BookInfo(title: 'Unknown', format: 'epub');
    }

    final opfDoc = XmlDocument.parse(String.fromCharCodes(opf.content));
    final title = _text(opfDoc, ['dc:title', 'title']) ?? 'Unknown';
    final author = _text(opfDoc, ['dc:creator', 'creator']);
    final description = _text(opfDoc, ['dc:description', 'description']);

    String? coverHref;
    final meta = opfDoc.findElements('meta');
    for (final m in meta) {
      if (m.getAttribute('name') == 'cover') {
        final id = m.getAttribute('content');
        if (id != null) {
          coverHref = _findHrefForId(opfDoc, id);
        }
      }
    }

    String? coverPath;
    if (coverHref != null) {
      final dir = opfPath.substring(0, opfPath.lastIndexOf('/') + 1);
      final file = archive.findFile('$dir$coverHref');
      if (file != null) {
        final tmp = await File('${Directory.systemTemp.path}/lumen_cover_${DateTime.now().millisecondsSinceEpoch}.jpg');
        tmp.writeAsBytesSync(file.content as Uint8List);
        coverPath = tmp.path;
      }
    }

    return BookInfo(
      title: title,
      author: author,
      description: description,
      coverPath: coverPath,
      format: 'epub',
    );
  }

  String? _text(XmlDocument doc, List<String> names) {
    for (final n in names) {
      final el = doc.findElements(n);
      if (el.isNotEmpty) return el.first.text;
    }
    return null;
  }

  String? _findHrefForId(XmlDocument doc, String id) {
    final manifest = doc.findElements('manifest');
    if (manifest.isEmpty) return null;
    for (final item in manifest.first.children.whereType<XmlElement>()) {
      if (item.getAttribute('id') == id) return item.getAttribute('href');
    }
    return null;
  }
}
