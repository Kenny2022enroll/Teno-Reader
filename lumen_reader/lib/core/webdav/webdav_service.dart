import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../features/reader/domain/entities/reading_entities.dart';
import 'webdav_models.dart';

/// Cross-platform safe path join (avoids pulling `package:path`).
String _join(String a, String b) {
  if (a.isEmpty) return b;
  if (b.isEmpty) return a;
  if (a.endsWith('/')) return '$a$b';
  return '$a/$b';
}

class WebDAVService {
  WebDAVService(Dio dio, WebDAVSettings settings)
      : _dio = Dio(BaseOptions(
          baseUrl: _normalizeBaseUrl(settings.url),
          headers: {
            'Authorization':
                'Basic ${base64.encode(utf8.encode('${settings.username}:${settings.password}'))}',
          },
          connectTimeout: const Duration(seconds: 15),
          receiveTimeout: const Duration(seconds: 30),
          sendTimeout: const Duration(seconds: 60),
        )),
        _settings = settings;

  final Dio _dio;
  final WebDAVSettings _settings;

  static String _normalizeBaseUrl(String url) {
    if (url.endsWith('/')) return url.substring(0, url.length - 1);
    return url;
  }

  String _fullPath(String relative) {
    final root = _settings.rootFolder.startsWith('/')
        ? _settings.rootFolder
        : '/${_settings.rootFolder}';
    final rel = relative.startsWith('/') ? relative : '/$relative';
    return '$root$rel';
  }

  Future<WebDAVSyncResult> testConnection() async {
    try {
      final path = _fullPath('');
      await _dio.request(
        path,
        options: Options(
          method: 'PROPFIND',
          headers: {'Depth': '0'},
        ),
      );
      return const WebDAVSyncResult.success();
    } on DioException catch (e) {
      if (e.response?.statusCode == 404 || e.response?.statusCode == 301) {
        try {
          await _ensureRemoteDir('');
          return const WebDAVSyncResult.success();
        } catch (e2) {
          return WebDAVSyncResult.failed(e2.toString());
        }
      }
      return WebDAVSyncResult.failed(e.toString());
    } catch (e) {
      return WebDAVSyncResult.failed(e.toString());
    }
  }

  Future<void> _ensureRemoteDir(String path) async {
    final fullPath = _fullPath(path);
    try {
      final response = await _dio.request(
        fullPath,
        options: Options(method: 'MKCOL'),
      );
      if (response.statusCode != 201 && response.statusCode != 405) {
        throw Exception('MKCOL failed: ${response.statusCode}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 405) return;
      if (e.response?.statusCode == 201) return;
      rethrow;
    }
  }

  Future<WebDAVSyncResult> upload({
    required List<ReadingProgress> progresses,
    required List<Highlight> highlights,
    required List<Bookmark> bookmarks,
  }) async {
    try {
      await _ensureRemoteDir('');

      final progressPayload = {
        'v': 1,
        'items': progresses.map((e) => e.toMap()).toList(),
      };
      await _dio.put(
        _fullPath('/progress.json'),
        data: jsonEncode(progressPayload),
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      final highlightsPayload = {
        'v': 1,
        'items': highlights.map((e) => e.toMap()).toList(),
      };
      await _dio.put(
        _fullPath('/highlights.json'),
        data: jsonEncode(highlightsPayload),
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      final bookmarksPayload = {
        'v': 1,
        'items': bookmarks.map((e) => e.toMap()).toList(),
      };
      await _dio.put(
        _fullPath('/bookmarks.json'),
        data: jsonEncode(bookmarksPayload),
        options: Options(
          headers: {'Content-Type': 'application/json'},
        ),
      );

      return WebDAVSyncResult.success(
        uploaded: progresses.length + highlights.length + bookmarks.length,
      );
    } catch (e) {
      return WebDAVSyncResult.failed(e.toString());
    }
  }

  Future<WebDAVSyncResult> download({
    required void Function(List<ReadingProgress>) onProgress,
    void Function(List<Highlight>)? onHighlights,
    void Function(List<Bookmark>)? onBookmarks,
  }) async {
    int downloaded = 0;
    try {
      try {
        final resp = await _dio.get(_fullPath('/progress.json'));
        if (resp.data != null) {
          final data = jsonDecode(resp.data.toString()) as Map<String, dynamic>;
          final items = (data['items'] as List?) ?? [];
          final list = items
              .map((e) => ReadingProgress.fromMap(e as Map<String, dynamic>))
              .toList();
          onProgress(list);
          downloaded += list.length;
        }
      } on DioException catch (e) {
        if (e.response?.statusCode != 404) rethrow;
      }

      if (onHighlights != null) {
        try {
          final resp = await _dio.get(_fullPath('/highlights.json'));
          if (resp.data != null) {
            final data =
                jsonDecode(resp.data.toString()) as Map<String, dynamic>;
            final items = (data['items'] as List?) ?? [];
            final list = items
                .map((e) => Highlight.fromMap(e as Map<String, dynamic>))
                .toList();
            onHighlights(list);
            downloaded += list.length;
          }
        } on DioException catch (e) {
          if (e.response?.statusCode != 404) rethrow;
        }
      }

      if (onBookmarks != null) {
        try {
          final resp = await _dio.get(_fullPath('/bookmarks.json'));
          if (resp.data != null) {
            final data =
                jsonDecode(resp.data.toString()) as Map<String, dynamic>;
            final items = (data['items'] as List?) ?? [];
            final list = items
                .map((e) => Bookmark.fromMap(e as Map<String, dynamic>))
                .toList();
            onBookmarks(list);
            downloaded += list.length;
          }
        } on DioException catch (e) {
          if (e.response?.statusCode != 404) rethrow;
        }
      }

      return WebDAVSyncResult.success(downloaded: downloaded);
    } catch (e) {
      return WebDAVSyncResult.failed(e.toString());
    }
  }

  Future<WebDAVSyncResult> uploadBook(
      String localFilePath, String remoteName) async {
    try {
      await _ensureRemoteDir('/books');
      final file = File(localFilePath);
      final stream = file.openRead();
      final length = await file.length();

      await _dio.put(
        _fullPath('/books/$remoteName'),
        data: stream,
        options: Options(
          headers: {
            Headers.contentLengthHeader: length,
          },
        ),
      );

      return const WebDAVSyncResult.success(uploaded: 1);
    } catch (e) {
      return WebDAVSyncResult.failed(e.toString());
    }
  }

  Future<String?> downloadBook(String remoteName, String localDir) async {
    try {
      final localPath = _join(localDir, remoteName);
      await _dio.download(
        _fullPath('/books/$remoteName'),
        localPath,
      );
      return localPath;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      return null;
    } catch (e) {
      return null;
    }
  }
}
