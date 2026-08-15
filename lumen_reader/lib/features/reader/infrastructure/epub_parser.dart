import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
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
  static String _decodeContent(dynamic content) {
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
    // Strip UTF-16 LE BOM
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return String.fromCharCodes(bytes.buffer.asUint16List(2));
    }
    // Strip UTF-16 BE BOM
    if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
      final u16 = bytes.buffer.asUint16List(2);
      final swapped = Uint16List(u16.length);
      for (int i = 0; i < u16.length; i++) {
        swapped[i] = (u16[i] << 8) | (u16[i] >> 8);
      }
      return String.fromCharCodes(swapped);
    }
    return utf8.decode(bytes.sublist(start), allowMalformed: true);
  }

  Future<BookInfo> extract(String path) async {
    return compute(_extractInIsolate, path);
  }

  static BookInfo _extractInIsolate(String path) {
    final archive = _openArchiveSync(path);
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
    // 1. Try meta[name="cover"] -> content references manifest id
    final meta = opfDoc.findAllElements('meta');
    for (final m in meta) {
      if (m.getAttribute('name')?.toLowerCase() == 'cover') {
        final id = m.getAttribute('content');
        if (id != null) {
          coverHref = _findHrefForId(opfDoc, id);
          if (coverHref != null) break;
        }
      }
    }
    // 2. Fallback: search manifest for items with cover-like properties/ids
    coverHref ??= _findCoverHrefInManifest(opfDoc);

    String? coverPath;
    if (coverHref != null) {
      final dir = opfPath.contains('/')
          ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
          : '';
      final candidates = <String>['$dir$coverHref', coverHref];
      // Try path with URL decoding (some epubs encode spaces etc.)
      for (final c in candidates) {
        final file = archive.findFile(c) ?? archive.findFile(Uri.decodeFull(c));
        if (file != null) {
          try {
            final ext = c.toLowerCase().split('.').last;
            final ts = DateTime.now().millisecondsSinceEpoch;
            final tmpExt =
                (ext == 'png' || ext == 'jpeg' || ext == 'webp') ? ext : 'jpg';
            final tmp = File(
              '${Directory.systemTemp.path}/lumen_cover_$ts.$tmpExt',
            );
            tmp.writeAsBytesSync(
              file.content is Uint8List
                  ? file.content as Uint8List
                  : Uint8List.fromList(file.content as List<int>),
            );
            coverPath = tmp.path;
            break;
          } catch (_) {
            continue;
          }
        }
      }
    }

    // 3. Last resort: scan the archive for any image named "cover"
    if (coverPath == null) {
      for (final file in archive.files) {
        final name = file.name.toLowerCase();
        if ((name.contains('cover') || name.contains('封面')) &&
            RegExp(r'\.(jpg|jpeg|png|webp)$').hasMatch(name)) {
          try {
            final ts = DateTime.now().millisecondsSinceEpoch;
            final ext = name.split('.').last;
            final tmp = File(
              '${Directory.systemTemp.path}/lumen_cover_$ts.$ext',
            );
            tmp.writeAsBytesSync(
              file.content is Uint8List
                  ? file.content as Uint8List
                  : Uint8List.fromList(file.content as List<int>),
            );
            coverPath = tmp.path;
            break;
          } catch (_) {}
        }
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
    return compute(_extractChaptersInIsolate, path);
  }

  static List<EpubChapter> _extractChaptersInIsolate(String path) {
    final archive = _openArchiveSync(path);
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

  static Archive _openArchiveSync(String path) {
    final bytes = File(path).readAsBytesSync();
    return ZipDecoder().decodeBytes(bytes);
  }

  static String? _findOpfPath(Archive archive) {
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

  static EpubChapter _parseHtmlChapter(String html) {
    String title = '';
    String content = '';
    bool usedXml = false;

    try {
      // Try strict XML parsing first (for valid XHTML)
      final doc = XmlDocument.parse(html);
      final titleEls = doc.findAllElements('title');
      if (titleEls.isNotEmpty) {
        title = titleEls.first.text.trim();
      }
      final bodyEls = doc.findAllElements('body');
      if (bodyEls.isNotEmpty) {
        content = _extractText(bodyEls.first).trim();
        usedXml = true;
      }
    } catch (_) {
      // XML parsing failed — try lenient HTML extraction below
    }

    // If XML parsing failed or produced empty content, use regex fallback
    if (!usedXml || content.isEmpty) {
      final titleMatch = RegExp(
        r'<title[^>]*>(.*?)</title>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(html);
      if (titleMatch != null && title.isEmpty) {
        title = titleMatch.group(1)!.trim();
      }
      // Extract body content first if available
      var bodyHtml = html;
      final bodyMatch = RegExp(
        r'<body[^>]*>(.*?)</body>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(html);
      if (bodyMatch != null) {
        bodyHtml = bodyMatch.group(1)!;
      }
      content = _stripHtmlTags(bodyHtml);
      if (content.isEmpty) {
        content = _stripHtmlTags(html);
      }
    }

    if (title.isEmpty) {
      // Try <h1> as chapter title fallback
      final h1Match = RegExp(
        r'<h1[^>]*>(.*?)</h1>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(html);
      if (h1Match != null) {
        title = _stripHtmlTags(h1Match.group(1)!).trim();
      }
    }
    if (title.isEmpty) title = '未命名章节';
    return EpubChapter(title: title, content: content);
  }

  static String _stripHtmlTags(String input) {
    // Replace block elements with newlines first
    var s = input.replaceAllMapped(
      RegExp(
        r'</?(p|div|br/?|h[1-6]|li|tr|blockquote|section|article|header|footer|nav|aside)[^>]*>',
        caseSensitive: false,
      ),
      (_) => '\n',
    );
    // Strip remaining tags
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');
    // Decode HTML entities
    s = s
        .replaceAllMapped(RegExp(r'&nbsp;', caseSensitive: false), (_) => ' ')
        .replaceAllMapped(RegExp(r'&amp;', caseSensitive: false), (_) => '&')
        .replaceAllMapped(RegExp(r'&lt;', caseSensitive: false), (_) => '<')
        .replaceAllMapped(RegExp(r'&gt;', caseSensitive: false), (_) => '>')
        .replaceAllMapped(RegExp(r'&quot;', caseSensitive: false), (_) => '"')
        .replaceAllMapped(RegExp(r'&#39;', caseSensitive: false), (_) => "'")
        .replaceAllMapped(
          RegExp(r'&#(\d+);'),
          (m) => String.fromCharCode(int.parse(m.group(1)!)),
        )
        .replaceAllMapped(
          RegExp(r'&#x([0-9a-fA-F]+);'),
          (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
        );
    // Collapse whitespace
    s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
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

  static String _extractText(XmlNode node) {
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

  static String? _text(XmlDocument doc, List<String> names) {
    for (final n in names) {
      final el = doc.findAllElements(n);
      if (el.isNotEmpty) return el.first.text;
    }
    return null;
  }

  static String? _findHrefForId(XmlDocument doc, String id) {
    final manifest = doc.findAllElements('manifest');
    if (manifest.isEmpty) return null;
    for (final item in manifest.first.children.whereType<XmlElement>()) {
      if (item.getAttribute('id') == id) return item.getAttribute('href');
    }
    return null;
  }

  /// Fallback: search manifest for an item that looks like a cover.
  static String? _findCoverHrefInManifest(XmlDocument doc) {
    final manifest = doc.findAllElements('manifest');
    if (manifest.isEmpty) return null;
    String? byProp;
    String? byId;
    String? byMediaType;
    for (final item in manifest.first.children.whereType<XmlElement>()) {
      final id = item.getAttribute('id')?.toLowerCase() ?? '';
      final href = item.getAttribute('href');
      final mediaType = item.getAttribute('media-type')?.toLowerCase() ?? '';
      final props = item.getAttribute('properties')?.toLowerCase() ?? '';

      if (href == null) continue;

      // EPUB 3: properties="cover-image"
      if (props.contains('cover-image')) byProp ??= href;

      // Common manifest id naming patterns
      if (id == 'cover' ||
          id == 'cover-image' ||
          id == 'coverimage' ||
          id.contains('cover')) {
        byId ??= href;
      }

      // Pick the first image manifest item as last resort
      if (byMediaType == null &&
          (mediaType.startsWith('image/') ||
              RegExp(
                r'\.(jpg|jpeg|png|webp)$',
                caseSensitive: false,
              ).hasMatch(href))) {
        byMediaType = href;
      }
    }
    return byProp ?? byId ?? byMediaType;
  }
}
