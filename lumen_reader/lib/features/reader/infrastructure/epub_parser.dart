import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

import '../domain/repositories/book_repository.dart';

class EpubChapter {
  final String title;
  final String content;
  const EpubChapter({required this.title, required this.content});
}

class EpubImage {
  final String archivePath;
  final String extractedPath;
  final int width;
  final int height;
  const EpubImage({
    required this.archivePath,
    required this.extractedPath,
    required this.width,
    required this.height,
  });
}

class EpubParseResult {
  final List<EpubChapter> chapters;
  final List<EpubImage> images;
  const EpubParseResult({required this.chapters, required this.images});
}

class EpubParser {
  static String _decodeContent(dynamic content) {
    final bytes = content is Uint8List
        ? content
        : Uint8List.fromList(content as List<int>);
    var start = 0;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      start = 3;
    }
    if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return String.fromCharCodes(bytes.buffer.asUint16List(2));
    }
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

  static String _coverTmpPath(String path, String ext) {
    return '${Directory.systemTemp.path}/book_${path.hashCode}_cover.$ext';
  }

  static String? _writeCoverBytes(
    String path,
    dynamic fileContent,
    String ext,
  ) {
    try {
      final tmpExt =
          (ext == 'png' || ext == 'jpeg' || ext == 'webp' || ext == 'gif')
              ? ext
              : 'jpg';
      final tmp = File(_coverTmpPath(path, tmpExt));
      if (tmp.existsSync() && tmp.lengthSync() > 1024) {
        return tmp.path;
      }
      tmp.writeAsBytesSync(
        fileContent is Uint8List
            ? fileContent as Uint8List
            : Uint8List.fromList(fileContent as List<int>),
      );
      if (tmp.existsSync() && tmp.lengthSync() > 0) {
        return tmp.path;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static bool _isImageFile(ArchiveFile file) {
    final name = file.name.toLowerCase();
    final mediaType = (file.compressType == null ? '' : '').toLowerCase();
    if (mediaType.startsWith('image/')) return true;
    return RegExp(
      r'\.(jpg|jpeg|png|webp|gif)$',
      caseSensitive: false,
    ).hasMatch(name);
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
    coverHref ??= _findCoverHrefInManifest(opfDoc);

    String? coverPath;
    if (coverHref != null) {
      final dir = opfPath.contains('/')
          ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
          : '';
      final candidates = <String>['$dir$coverHref', coverHref];
      for (final c in candidates) {
        final file = archive.findFile(c) ?? archive.findFile(Uri.decodeFull(c));
        if (file != null) {
          final ext = c.toLowerCase().split('.').last;
          final result = _writeCoverBytes(path, file.content, ext);
          if (result != null) {
            coverPath = result;
            break;
          }
        }
      }
    }

    if (coverPath == null) {
      for (final file in archive.files) {
        final name = file.name.toLowerCase();
        final baseName = name.split('/').last;
        if (RegExp(
          r'^cover\.(jpg|jpeg|png|webp)$',
          caseSensitive: false,
        ).hasMatch(baseName)) {
          final ext = baseName.split('.').last;
          final result = _writeCoverBytes(path, file.content, ext);
          if (result != null) {
            coverPath = result;
            break;
          }
        }
      }
    }

    if (coverPath == null) {
      for (final file in archive.files) {
        final name = file.name.toLowerCase();
        if ((name.contains('cover') || name.contains('封面')) &&
            RegExp(r'\.(jpg|jpeg|png|webp|gif)$').hasMatch(name)) {
          final ext = name.split('.').last;
          final result = _writeCoverBytes(path, file.content, ext);
          if (result != null) {
            coverPath = result;
            break;
          }
        }
      }
    }

    if (coverPath == null) {
      final imageFiles = <ArchiveFile>[];
      for (final file in archive.files) {
        if (_isImageFile(file) && file.size > 0) {
          imageFiles.add(file);
        }
      }
      if (imageFiles.isNotEmpty) {
        imageFiles.sort((a, b) => b.size.compareTo(a.size));
        final largest = imageFiles.first;
        final name = largest.name.toLowerCase();
        final ext = RegExp(
              r'\.(jpg|jpeg|png|webp|gif)$',
              caseSensitive: false,
            ).firstMatch(name)?.group(1) ??
            'jpg';
        coverPath = _writeCoverBytes(path, largest.content, ext);
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

  Future<List<EpubChapter>> extractChapters(String path) async {
    return compute(_extractChaptersInIsolate, path);
  }

  Future<EpubParseResult> extractChaptersWithImages(String path) async {
    return compute(_extractChaptersWithImagesInIsolate, path);
  }

  static EpubParseResult _extractChaptersWithImagesInIsolate(String path) {
    final archive = _openArchiveSync(path);
    final opfPath = _findOpfPath(archive);
    if (opfPath == null) {
      return const EpubParseResult(chapters: [], images: []);
    }

    final opf = archive.findFile(opfPath);
    if (opf == null) {
      return const EpubParseResult(chapters: [], images: []);
    }

    final opfDoc = XmlDocument.parse(_decodeContent(opf.content));
    final opfDir = opfPath.contains('/')
        ? opfPath.substring(0, opfPath.lastIndexOf('/') + 1)
        : '';

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

    final spineEl = opfDoc.findAllElements('spine');
    if (spineEl.isEmpty) {
      return const EpubParseResult(chapters: [], images: []);
    }

    final extractedImages = <String, EpubImage>{};
    final tmpDir = Directory.systemTemp.path;
    final bookTag = 'book_${path.hashCode}';

    final chapters = <EpubChapter>[];
    for (final itemref in spineEl.first.children.whereType<XmlElement>()) {
      final idref = itemref.getAttribute('idref');
      if (idref == null || !manifest.containsKey(idref)) continue;

      final href = manifest[idref]!;
      final filePath = '$opfDir$href';
      final file = archive.findFile(filePath);
      if (file == null) continue;

      final html = _decodeContent(file.content);
      final baseDir = filePath.contains('/')
          ? filePath.substring(0, filePath.lastIndexOf('/') + 1)
          : '';

      final chapterResult = _parseHtmlChapterWithImages(
        html,
        baseDir,
        archive,
        (imgSrc) {
          final archivePath = _resolveHrefForImage(baseDir, imgSrc, archive);
          if (archivePath == null) return null;
          if (extractedImages.containsKey(archivePath)) {
            return archivePath;
          }
          final imgFile = archive.findFile(archivePath);
          if (imgFile == null) return null;

          final safeName = archivePath
              .replaceAll('/', '_')
              .replaceAll('\\', '_')
              .replaceAll(' ', '_');
          final ext = safeName.contains('.')
              ? safeName.split('.').last.toLowerCase()
              : 'png';
          final validExt =
              RegExp(r'^(jpg|jpeg|png|webp|gif)$').hasMatch(ext) ? ext : 'png';
          final outPath = '$tmpDir/${bookTag}_img_$safeName';
          try {
            final f = File(outPath);
            if (!f.existsSync() || f.lengthSync() <= 0) {
              f.writeAsBytesSync(
                imgFile.content is Uint8List
                    ? imgFile.content as Uint8List
                    : Uint8List.fromList(imgFile.content as List<int>),
              );
            }
            extractedImages[archivePath] = EpubImage(
              archivePath: archivePath,
              extractedPath: outPath,
              width: 0,
              height: 0,
            );
            return archivePath;
          } catch (_) {
            return null;
          }
        },
      );

      chapters.add(chapterResult);
    }

    return EpubParseResult(
      chapters: chapters,
      images: extractedImages.values.toList(),
    );
  }

  static String? _resolveHrefForImage(
    String baseDir,
    String imgSrc,
    Archive archive,
  ) {
    if (imgSrc.isEmpty) return null;
    final src = imgSrc.trim();
    if (src.startsWith('http://') || src.startsWith('https://')) return null;
    if (src.startsWith('data:')) return null;

    var clean = src;
    final hashIdx = clean.indexOf('#');
    if (hashIdx >= 0) clean = clean.substring(0, hashIdx);
    final queryIdx = clean.indexOf('?');
    if (queryIdx >= 0) clean = clean.substring(0, queryIdx);

    if (clean.startsWith('/')) {
      clean = clean.substring(1);
      final f =
          archive.findFile(clean) ?? archive.findFile(Uri.decodeFull(clean));
      if (f != null) return clean;
      return null;
    }

    final combined = '$baseDir$clean';
    var normalized = _normalizePath(combined);
    var f = archive.findFile(normalized) ??
        archive.findFile(Uri.decodeFull(normalized));
    if (f != null) return normalized;

    f = archive.findFile(clean) ?? archive.findFile(Uri.decodeFull(clean));
    if (f != null) return clean;

    for (final file in archive.files) {
      final name = file.name;
      if (name.endsWith('/$clean') || name == clean) {
        return name;
      }
    }
    return null;
  }

  static String _normalizePath(String path) {
    if (!path.contains('..')) return path;
    final parts = path.split('/');
    final stack = <String>[];
    for (final p in parts) {
      if (p == '..') {
        if (stack.isNotEmpty) stack.removeLast();
      } else if (p != '.') {
        stack.add(p);
      }
    }
    return stack.join('/');
  }

  static EpubChapter _parseHtmlChapterWithImages(
    String html,
    String baseDir,
    Archive archive,
    String? Function(String imgSrc) onImage,
  ) {
    String title = '';
    String content = '';
    bool usedXml = false;

    try {
      final doc = XmlDocument.parse(html);
      final titleEls = doc.findAllElements('title');
      if (titleEls.isNotEmpty) {
        title = titleEls.first.text.trim();
      }
      final bodyEls = doc.findAllElements('body');
      if (bodyEls.isNotEmpty) {
        content = _extractTextWithImages(bodyEls.first, onImage).trim();
        usedXml = true;
      }
    } catch (_) {}

    if (!usedXml || content.isEmpty) {
      final titleMatch = RegExp(
        r'<title[^>]*>(.*?)</title>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(html);
      if (titleMatch != null && title.isEmpty) {
        title = titleMatch.group(1)!.trim();
      }
      var bodyHtml = html;
      final bodyMatch = RegExp(
        r'<body[^>]*>(.*?)</body>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(html);
      if (bodyMatch != null) {
        bodyHtml = bodyMatch.group(1)!;
      }
      content = _stripHtmlTagsWithImages(bodyHtml, onImage);
      if (content.isEmpty) {
        content = _stripHtmlTagsWithImages(html, onImage);
      }
    }

    if (title.isEmpty) {
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

  static String _extractTextWithImages(
    XmlNode node,
    String? Function(String imgSrc) onImage,
  ) {
    final buffer = StringBuffer();
    for (final child in node.children) {
      if (child is XmlText) {
        buffer.write(child.text);
      } else if (child is XmlElement) {
        final tag = child.name.local.toLowerCase();
        if (tag == 'img') {
          final src = child.getAttribute('src');
          if (src != null) {
            final resolved = onImage(src);
            if (resolved != null) {
              buffer.write('[IMAGE:$resolved]');
            }
          }
        } else {
          buffer.write(_extractTextWithImages(child, onImage));
        }
        if (_blockTags.contains(tag)) {
          buffer.write('\n');
        }
      }
    }
    return buffer.toString();
  }

  static String _stripHtmlTagsWithImages(
    String input,
    String? Function(String imgSrc) onImage,
  ) {
    final imgRegex = RegExp(
      r'''<img\s[^>]*src\s*=\s*["']([^"']+)["'][^>]*>''',
      caseSensitive: false,
      dotAll: true,
    );
    var withMarkers = input.replaceAllMapped(imgRegex, (m) {
      final src = m.group(1) ?? '';
      final resolved = onImage(src);
      if (resolved != null) {
        return '[IMAGE:$resolved]';
      }
      return '';
    });
    var s = withMarkers.replaceAllMapped(
      RegExp(
        r'</?(p|div|br/?|h[1-6]|li|tr|blockquote|section|article|header|footer|nav|aside)[^>]*>',
        caseSensitive: false,
      ),
      (_) => '\n',
    );
    s = s.replaceAllMapped(RegExp(r'<[^>]+>'), (m) {
      final t = m.group(0)!;
      if (t.contains('[IMAGE:')) return t;
      return '';
    });
    s = s.replaceAllMapped(RegExp(r'<[^>]+>'), (_) => '');
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
    s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
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
    } catch (_) {}

    if (!usedXml || content.isEmpty) {
      final titleMatch = RegExp(
        r'<title[^>]*>(.*?)</title>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(html);
      if (titleMatch != null && title.isEmpty) {
        title = titleMatch.group(1)!.trim();
      }
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
    var s = input.replaceAllMapped(
      RegExp(
        r'</?(p|div|br/?|h[1-6]|li|tr|blockquote|section|article|header|footer|nav|aside)[^>]*>',
        caseSensitive: false,
      ),
      (_) => '\n',
    );
    s = s.replaceAll(RegExp(r'<[^>]+>'), '');
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
    s = s.replaceAll(RegExp(r'[ \t]+'), ' ');
    s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return s.trim();
  }

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

      if (props.contains('cover-image')) byProp ??= href;

      if (id == 'cover' ||
          id == 'cover-image' ||
          id == 'coverimage' ||
          id.contains('cover')) {
        byId ??= href;
      }

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
