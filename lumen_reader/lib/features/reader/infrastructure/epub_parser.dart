import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../domain/repositories/book_repository.dart';

/// A parsed EPUB chapter: title + plain-text content.
class EpubChapter {
  final String title;
  final String content;
  const EpubChapter({required this.title, required this.content});
}

/// Lightweight EPUB metadata / content extractor.
class EpubParser {
  /// Decode archive file content as UTF-8, stripping BOM if present.
  String _decodeContent(dynamic content) {
    final bytes = content is Uint8List
        ? content
        : Uint8List.fromList(content as List<int>);
    var start = 0;
    // Strip UTF-8 BOM (EF BB BF) if present
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      start = 3;
    }
    return utf8.decode(bytes.sublist(start), allowMalformed: true);
  }

  Future<BookInfo> extract(String path) async {
    final archive = _openArchive(path);
    final opfPath = _findOpfPath(archive);
    if (opfPath == null) {
      return const BookInfo(title: 'Unknown', format: 'epub');
    }

    final opf = archive.findFile(opfPath);
    if (opf == null) {
      return const BookInfo(title: 'Unknown', format: 'epub');
    }

    final opfDoc = XmlDocument.parse(_decodeContent(opf.content));
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
        final ts = DateTime.now().millisecondsSinceEpoch;
        final tmp = File('${Directory.systemTemp.path}/lumen_cover_$ts.jpg');
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

  /// Extract all chapters from an EPUB file in spine order.
  Future<List<EpubChapter>> extractChapters(String path) async {
    final archive = _openArchive(path);
    final opfPath = _findOpfPath(archive);
    if (opfPath == null) return [];

    final opf = archive.findFile(opfPath);
    if (opf == null) return [];

    final opfDoc = XmlDocument.parse(_decodeContent(opf.content));
    final opfDir = opfPath.contains('/')
        ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
        : '';

    // Build manifest map: id -> href
    final manifest = <String, String>{};
    final manifestEl = opfDoc.findAllElements('manifest');
    if (manifestEl.isNotEmpty) {
      for (final item in manifestEl.first.children.whereType<XmlElement>()) {
        final id = item.getAttribute('id');
        final href = item.getAttribute('href');
        if (id != null && href != null) {
          manifest[id] = href;
        }
      }
    }

    // Get spine order (reading order)
    final spineEl = opfDoc.findAllElements('spine');
    if (spineEl.isEmpty) return [];

    final chapters = <EpubChapter>[];
    for (final itemref in spineEl.first.children.whereType<XmlElement>()) {
      final idref = itemref.getAttribute('idref');
      if (idref == null || !manifest.containsKey(idref)) continue;

      final href = manifest[idref]!;
      final filePath = '$opfDir$href';
      final file = archive.findFile(filePath);
      if (file == null) continue;

      final html = _decodeContent(file.content);
      chapters.add(_parseHtmlChapter(html));
    }

    return chapters;
  }

  Archive _openArchive(String path) {
    final bytes = File(path).readAsBytesSync();
    return ZipDecoder().decodeBytes(bytes);
  }

  String? _findOpfPath(Archive archive) {
    final container = archive.findFile('META-INF/container.xml');
    if (container != null) {
      final xml = XmlDocument.parse(_decodeContent(container.content));
      final rootfiles = xml.findAllElements('rootfile');
      if (rootfiles.isNotEmpty) {
        return rootfiles.first.getAttribute('full-path');
      }
    }
    return 'OEBPS/content.opf';
  }

  EpubChapter _parseHtmlChapter(String html) {
    String title = '';
    String content = '';

    try {
      final doc = XmlDocument.parse(html);

      // Try <title> tag
      final titleEls = doc.findAllElements('title');
      if (titleEls.isNotEmpty) {
        title = titleEls.first.text.trim();
      }

      // Extract text from <body>
      final bodyEls = doc.findAllElements('body');
      if (bodyEls.isNotEmpty) {
        content = _extractText(bodyEls.first).trim();
      }
    } catch (_) {
      // HTML not valid XML — fall back to regex stripping
      final titleMatch = RegExp(
        r'<title[^>]*>(.*?)</title>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(html);
      if (titleMatch != null) {
        title = titleMatch.group(1)!.trim();
      }
      content = html
          .replaceAll(RegExp(r'<[^>]+>'), '\n')
          .replaceAll(RegExp(r'&nbsp;'), ' ')
          .replaceAll(RegExp(r'&amp;'), '&')
          .replaceAll(RegExp(r'&lt;'), '<')
          .replaceAll(RegExp(r'&gt;'), '>')
          .replaceAll(RegExp(r'&quot;'), '"')
          .replaceAll(RegExp(r'\n{3,}'), '\n\n')
          .trim();
    }

    if (title.isEmpty) title = '未命名章节';
    return EpubChapter(title: title, content: content);
  }

  static const _blockTags = <String>{
    'p',
    'div',
    'br',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'li',
    'tr',
    'blockquote',
    'section',
  };

  String _extractText(XmlNode node) {
    final buffer = StringBuffer();
    for (final child in node.children) {
      if (child is XmlText) {
        buffer.write(child.text);
      } else if (child is XmlElement) {
        final tag = child.name.local.toLowerCase();
        buffer.write(_extractText(child));
        if (_blockTags.contains(tag)) {
          buffer.write('\n');
        }
      }
    }
    return buffer.toString();
  }

  String? _text(XmlDocument doc, List<String> names) {
    for (final n in names) {
      final el = doc.findAllElements(n);
      if (el.isNotEmpty) return el.first.text;
    }
    return null;
  }

  String? _findHrefForId(XmlDocument doc, String id) {
    final manifest = doc.findAllElements('manifest');
    if (manifest.isEmpty) return null;
    for (final item in manifest.first.children.whereType<XmlElement>()) {
      if (item.getAttribute('id') == id) return item.getAttribute('href');
    }
    return null;
  }
}
