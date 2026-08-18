import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/book_entity.dart';
import '../../domain/entities/reading_entities.dart';
import '../../infrastructure/book_repository.dart';
import '../../infrastructure/epub_parser.dart';
import '../../infrastructure/pdf_parser.dart';
import '../../infrastructure/progress_repository.dart';

final readerSettingsProvider = FutureProvider<SettingsPayload>((ref) {
  final repo = ref.watch(bookRepositoryProvider);
  return repo.loadSettings();
});

final readerBookProvider = FutureProvider.family<BookEntity?, String>((
  ref,
  id,
) {
  final repo = ref.watch(bookRepositoryProvider);
  return repo.fetchBook(id);
});

String _decodeTxtFile(String path) {
  final bytes = File(path).readAsBytesSync();
  if (bytes.isEmpty) return '';

  // Strip UTF-8 BOM
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    return utf8.decode(bytes.sublist(3), allowMalformed: true);
  }

  // Strip UTF-16 LE BOM
  if (bytes.length >= 2 && bytes[0] == 0xFF && bytes[1] == 0xFE) {
    try {
      return String.fromCharCodes(bytes.buffer.asUint16List(2));
    } catch (_) {
      return utf8.decode(bytes.sublist(2), allowMalformed: true);
    }
  }

  // Strip UTF-16 BE BOM
  if (bytes.length >= 2 && bytes[0] == 0xFE && bytes[1] == 0xFF) {
    try {
      final u16 = bytes.buffer.asUint16List(2);
      final swapped = Uint16List(u16.length);
      for (int i = 0; i < u16.length; i++) {
        swapped[i] = (u16[i] << 8) | (u16[i] >> 8);
      }
      return String.fromCharCodes(swapped);
    } catch (_) {
      return utf8.decode(bytes.sublist(2), allowMalformed: true);
    }
  }

  // Try strict UTF-8 first
  try {
    return utf8.decode(bytes);
  } catch (_) {
    // Not valid UTF-8. Common case: Chinese GBK/GB18030 encoded files.
    // Strategy: heuristically decode as GBK-like multibyte sequence.
    // Most Chinese GBK characters use 2-byte sequences with first byte
    // in 0x81-0xFE range. We cannot decode perfectly without a codec,
    // but we can produce a readable (with replacement characters) output
    // and append a notice if we detect non-Latin byte patterns.
    final buffer = StringBuffer();
    int i = 0;
    int multibyteCount = 0;
    while (i < bytes.length) {
      final b = bytes[i];
      if (b < 0x80) {
        // ASCII — always valid
        buffer.writeCharCode(b);
        i++;
      } else if (b >= 0x81 && b <= 0xFE && i + 1 < bytes.length) {
        // Likely a GBK/GB18030 two-byte sequence
        bytes[i + 1]; // touch second byte (boundary check via index)
        // Try to interpret as a raw character; will be garbage but
        // avoids throwing. Real GBK decoding needs a dedicated codec.
        buffer.writeCharCode(0xFFFD); // replacement char �
        i += 2;
        multibyteCount++;
      } else {
        buffer.writeCharCode(0xFFFD);
        i++;
      }
    }
    if (multibyteCount > 5) {
      buffer.writeln();
      buffer.writeln();
      buffer.writeln('—');
      buffer.writeln('提示：检测到本文件可能采用 GBK/GB18030 编码。');
      buffer.writeln('建议：请在电脑上用记事本或 VS Code 打开文件，');
      buffer.writeln('另存为 UTF-8 编码后再导入，即可获得完美的阅读效果。');
    }
    return buffer.toString();
  }
}

class ReaderPage extends ConsumerStatefulWidget {
  const ReaderPage({super.key, required this.bookId});
  final String bookId;

  @override
  ConsumerState<ReaderPage> createState() => _ReaderPageState();
}

class _ReaderPageState extends ConsumerState<ReaderPage> {
  late final ScrollController _scrollCtrl;
  late final PageController _pageCtrl;
  final FlutterTts _tts = FlutterTts();

  List<String> _chapters = const []; // chapter titles
  List<String> _chapterContents = const []; // chapter text content
  final List<double> _chapterOffsets = [];
  int _currentChapter = 0;
  double _currentProgress = 0;
  bool _showControls = true;
  bool _isPlayingTts = false;
  bool _isLoading = true;
  ReadingProgress? _savedProgress;
  bool _needsPositionRestore = false;
  int _restoreAttempts = 0;
  // Cached state captured before dispose so the async save can complete
  // even after the widget is gone.
  int _lastScrollOffset = 0;
  String _lastChapterId = '0:';

  Map<String, String> _epubImagePaths = {};

  /// Currently selected text within the chapter body, captured via
  /// SelectionArea.onSelectionChanged. Used by the highlight context menu
  /// so the user's actual selection (not a placeholder) is stored.
  SelectedContent? _currentSelection;

  @override
  void initState() {
    super.initState();
    _scrollCtrl = ScrollController()..addListener(_onScroll);
    _pageCtrl = PageController();
    _initTts();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadBook());
  }

  @override
  void dispose() {
    // Capture the latest scroll position synchronously so the async save
    // triggered here does not touch an already-disposed controller.
    if (_scrollCtrl.hasClients) {
      _lastScrollOffset = _scrollCtrl.offset.toInt();
    }
    // Schedule the final save with cached state — do not await (dispose
    // must be synchronous), but the data has been snapshotted above.
    _autoSaveProgress(force: true);
    _scrollCtrl.dispose();
    _pageCtrl.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    // Pick a language that matches the (mostly Chinese) reading content.
    // Fall back to the system default / en-US when Chinese TTS is unavailable.
    final langs = await _tts.getLanguages ?? <String>[];
    const preferred = ['zh-CN', 'zh-TW', 'zh-HK'];
    String picked = 'en-US';
    for (final p in preferred) {
      if (langs.any((l) => l.toLowerCase() == p.toLowerCase())) {
        picked = p;
        break;
      }
    }
    await _tts.setLanguage(picked);
    await _tts.setSpeechRate(0.5);
    _tts.setCompletionHandler(_onTtsComplete);
  }

  int _resolveChapterIndex(ReadingProgress saved, List<String> chapters) {
    if (chapters.isEmpty) return 0;
    final chapterId = saved.chapterId;
    final colonIdx = chapterId.indexOf(':');
    if (colonIdx > 0) {
      final n = int.tryParse(chapterId.substring(0, colonIdx));
      if (n != null && n >= 0 && n < chapters.length) {
        return n;
      }
    }
    final byTitle = chapters.indexWhere(
      (c) => c == chapterId || c.trim() == chapterId.trim(),
    );
    if (byTitle >= 0) return byTitle;
    final estimated = (saved.progress * chapters.length).floor();
    return estimated.clamp(0, chapters.length - 1);
  }

  Future<void> _loadBook() async {
    final book = await ref.read(readerBookProvider(widget.bookId).future);
    if (book == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final progressRepo = ref.read(progressRepositoryProvider);
    final saved = await progressRepo.fetchProgress(book.id);
    _savedProgress = saved;

    String errorHint = '';
    try {
      if (book.format == 'epub') {
        await _loadEpubChapters(book);
        if (_chapters.isEmpty) {
          errorHint = '无法解析 EPUB 章节结构。请确认文件未损坏。';
        }
      } else if (book.format == 'pdf') {
        try {
          final text = await PdfParser().extractText(book.filePath);
          _chapters = ['全文'];
          _chapterContents = [text];
        } catch (e) {
          errorHint = 'PDF 解析失败（$e）。若为加密 PDF，请先解密后再导入。';
        }
      } else {
        // txt and other plain-text formats
        try {
          _chapters = ['全文'];
          _chapterContents = [await _extractPlainText(book.filePath)];
        } catch (e) {
          errorHint = '读取纯文本文件失败（$e）。';
        }
      }
      _chapterOffsets.add(0);
    } catch (e) {
      errorHint = '加载文件时发生异常：$e';
    }

    // Provide graceful fallback content instead of generic error screen
    if (_chapters.isEmpty || _chapterContents.isEmpty) {
      _chapters = ['提示'];
      final buffer = StringBuffer();
      buffer.writeln('抱歉，暂时无法读取本书内容。');
      buffer.writeln();
      if (errorHint.isNotEmpty) {
        buffer.writeln('原因：$errorHint');
        buffer.writeln();
      }
      buffer.writeln('格式：${book.format.toUpperCase()}');
      buffer.writeln('文件：${book.filePath.split('/').last}');
      buffer.writeln();
      buffer.writeln('建议的解决办法：');
      buffer.writeln('  1. 用电脑上的阅读器打开文件，确认能正常显示；');
      buffer.writeln('  2. EPUB：可尝试用 Calibre 转换为标准 EPUB3 后再导入；');
      buffer.writeln('  3. PDF：如为扫描件，需先 OCR 识别为可搜索文本；');
      buffer.writeln('  4. TXT：用记事本另存为 UTF-8 编码后再导入；');
      buffer.writeln('  5. 将文件重新复制到本地再导入（排除文件路径问题）。');
      _chapterContents = [buffer.toString()];
    }
    // Ensure empty content is still readable
    for (var i = 0; i < _chapterContents.length; i++) {
      if (_chapterContents[i].trim().isEmpty) {
        _chapterContents[i] = '（本章节暂无内容）';
      }
    }

    // Restore saved position
    if (saved != null && _chapters.isNotEmpty) {
      _currentChapter = _resolveChapterIndex(saved, _chapters);
      _currentProgress = saved.progress.clamp(0.0, 1.0);
      _needsPositionRestore = true;
    }

    final repo = ref.read(bookRepositoryProvider);
    await repo.recordRead(book.id);

    if (mounted) {
      setState(() => _isLoading = false);
      // Schedule position restoration AFTER the layout phase so the
      // ScrollController / PageController have clients attached.
      if (_needsPositionRestore) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
      }
    }
  }

  /// Actually apply the saved scroll / page position after first build.
  void _restorePosition() {
    final saved = _savedProgress;
    if (saved == null || !mounted) return;
    _restoreAttempts++;
    try {
      final s = ref.read(readerSettingsProvider).valueOrNull;
      final usePageView =
          s?.pageTurnStyle == 'curl' || s?.pageTurnStyle == 'slide';
      if (usePageView) {
        if (_pageCtrl.hasClients) {
          _pageCtrl.jumpToPage(_currentChapter);
        } else if (_restoreAttempts < 8) {
          // PageView not yet attached — retry on the next frame, but bound
          // the number of attempts so we never recurse forever.
          WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
          return;
        }
      } else if (_scrollCtrl.hasClients) {
        final max = _scrollCtrl.position.maxScrollExtent;
        // Prefer saved absolute scrollOffset if plausible; else use percentage.
        double target;
        if (saved.scrollOffset > 0 &&
            saved.scrollOffset.toDouble() <= max + 200) {
          target = saved.scrollOffset.toDouble();
        } else {
          target = _currentProgress * max;
        }
        _scrollCtrl.jumpTo(target.clamp(0.0, max));
      } else if (_restoreAttempts < 8) {
        // ScrollController still not attached — try one more frame, but bound.
        WidgetsBinding.instance.addPostFrameCallback((_) => _restorePosition());
        return;
      }
    } catch (_) {}
    _needsPositionRestore = false;
  }

  Future<void> _loadEpubChapters(BookEntity book) async {
    try {
      final result = await EpubParser().extractChaptersWithImages(
        book.filePath,
      );
      _chapters = result.chapters.map((c) => c.title).toList();
      _chapterContents = result.chapters.map((c) => c.content).toList();
      final imgMap = <String, String>{};
      for (final img in result.images) {
        imgMap[img.archivePath] = img.extractedPath;
      }
      _epubImagePaths = imgMap;
    } catch (_) {
      final chapters = await EpubParser().extractChapters(book.filePath);
      _chapters = chapters.map((c) => c.title).toList();
      _chapterContents = chapters.map((c) => c.content).toList();
      _epubImagePaths = {};
    }
    if (_chapters.isEmpty) {
      _chapters = ['未命名章节'];
      _chapterContents = ['无法解析 EPUB 内容'];
    }
  }

  Future<String> _extractPlainText(String path) async {
    try {
      return await compute(_decodeTxtFile, path);
    } catch (_) {
      return '';
    }
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final max = _scrollCtrl.position.maxScrollExtent;
    setState(() {
      _currentProgress = max > 0 ? _scrollCtrl.offset / max : 0;
    });
    _autoSaveProgress();
  }

  DateTime? _lastSave;
  Future<void> _autoSaveProgress({bool force = false}) async {
    final now = DateTime.now();
    if (!force &&
        _lastSave != null &&
        now.difference(_lastSave!) < const Duration(seconds: 5)) {
      return;
    }
    _lastSave = now;

    // Cache snapshot synchronously so a subsequent dispose() cannot pull
    // the rug out from under the awaited save below.
    final s = ref.read(readerSettingsProvider).valueOrNull;
    final usePageView =
        s?.pageTurnStyle == 'curl' || s?.pageTurnStyle == 'slide';

    final chapter = _chapters.isNotEmpty && _currentChapter < _chapters.length
        ? '$_currentChapter:${_chapters[_currentChapter]}'
        : '0:';
    _lastChapterId = chapter;

    int scrollOffset;
    int wordsRead;
    if (usePageView) {
      // For PageView mode, compute an aggregate offset: chapter * 10000 + %
      scrollOffset = _currentChapter * 10000 +
          (_currentProgress * 10000).round().clamp(0, 9999);
      wordsRead = _currentChapter * 500 + (_currentProgress * 500).round();
    } else if (_scrollCtrl.hasClients) {
      scrollOffset = _scrollCtrl.offset.toInt();
      wordsRead = _scrollCtrl.offset ~/ 20 + _currentChapter * 500;
      _lastScrollOffset = scrollOffset;
    } else {
      // Controller already disposed (e.g., during dispose()): use cached.
      scrollOffset = _lastScrollOffset;
      wordsRead = _lastScrollOffset ~/ 20 + _currentChapter * 500;
    }

    final bookAsync = ref.read(readerBookProvider(widget.bookId));
    final book = bookAsync.valueOrNull;
    if (book == null) return;

    final repo = ref.read(progressRepositoryProvider);
    try {
      await repo.saveProgress(
        ReadingProgress(
          bookId: book.id,
          chapterId: _lastChapterId,
          progress: _currentProgress,
          scrollOffset: scrollOffset,
          totalWordsRead: wordsRead,
          updatedAt: now,
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(readerBookProvider(widget.bookId));
    final settingsAsync = ref.watch(readerSettingsProvider);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _autoSaveProgress(force: true);
        if (mounted) this.context.pop();
      },
      child: Scaffold(
        backgroundColor: _resolveBgColor(
          settingsAsync.valueOrNull,
          Theme.of(context),
        ),
        body: bookAsync.when(
          data: (book) {
            if (book == null) return const Center(child: Text('书籍未找到'));
            if (_isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return Stack(
              children: [
                GestureDetector(
                  // Tap on the chapter surface (without drag) toggles the
                  // reading chrome. The SelectionArea inside still wins
                  // long-press / drag gestures for text selection.
                  behavior: HitTestBehavior.translucent,
                  onTap: () => setState(() => _showControls = !_showControls),
                  child: _buildReaderSurface(book, settingsAsync.valueOrNull),
                ),
                _buildTopBar(book, settingsAsync.valueOrNull),
                _buildBottomBar(book, settingsAsync.valueOrNull),
                if (_isPlayingTts) _buildTtsOverlay(book),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败: $e')),
        ),
      ),
    );
  }

  Color _resolveBgColor(SettingsPayload? s, ThemeData theme) {
    final brightness = theme.brightness;
    if (s == null) return theme.scaffoldBackgroundColor;
    switch (s.theme) {
      case 'sepia':
        return AppPalette.sepiaBackground;
      case 'paper':
        return Colors.white;
      case 'dark':
        return AppPalette.darkBackground;
      case 'light':
      default:
        return brightness == Brightness.dark
            ? AppPalette.darkBackground
            : AppPalette.lightBackground;
    }
  }

  Widget _buildReaderSurface(BookEntity book, SettingsPayload? settings) {
    if (settings?.pageTurnStyle == 'curl' ||
        settings?.pageTurnStyle == 'slide') {
      return PageView.builder(
        controller: _pageCtrl,
        itemCount: _chapters.length,
        onPageChanged: (i) {
          setState(() {
            _currentChapter = i;
            _currentProgress = 0;
          });
          _autoSaveProgress();
        },
        itemBuilder: (context, index) {
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: MediaQuery.of(context).padding.top + AppSpacing.md,
            ),
            child: _buildChapterBody(book, index, settings),
          );
        },
      );
    }
    final padding = EdgeInsets.symmetric(
      horizontal: AppSpacing.xl,
      vertical: MediaQuery.of(context).padding.top + AppSpacing.md,
    );
    return ListView.custom(
      controller: _scrollCtrl,
      padding: padding,
      childrenDelegate: SliverChildListDelegate([
        _buildChapterBody(book, _currentChapter, settings),
        _buildChapterNav(book, settings),
      ], addAutomaticKeepAlives: false),
    );
  }

  List<InlineSpan> _parseContentTokens(
    String content,
    Color textColor,
    SettingsPayload? s,
  ) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\[IMAGE:([^\]]+)\]');
    final matches = pattern.allMatches(content);
    int cursor = 0;
    for (final m in matches) {
      if (m.start > cursor) {
        final text = content.substring(cursor, m.start);
        spans.add(
          TextSpan(
            text: text,
            style: TextStyle(
              fontSize: s?.fontSize ?? 17,
              height: s?.lineHeight ?? 1.6,
              color: textColor,
              fontFamily: s?.fontFamily,
            ),
          ),
        );
      }
      final archivePath = m.group(1) ?? '';
      final extractedPath = _epubImagePaths[archivePath];
      if (extractedPath != null && extractedPath.isNotEmpty) {
        final file = File(extractedPath);
        if (file.existsSync()) {
          spans.add(
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    file,
                    fit: BoxFit.fitWidth,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          );
          cursor = m.end;
          continue;
        }
      }
      spans.add(WidgetSpan(child: Container()));
      cursor = m.end;
    }
    if (cursor < content.length) {
      final text = content.substring(cursor);
      spans.add(
        TextSpan(
          text: text,
          style: TextStyle(
            fontSize: s?.fontSize ?? 17,
            height: s?.lineHeight ?? 1.6,
            color: textColor,
            fontFamily: s?.fontFamily,
          ),
        ),
      );
    }
    return spans;
  }

  Widget _buildChapterBody(
    BookEntity book,
    int chapterIndex,
    SettingsPayload? s,
  ) {
    final theme = Theme.of(context);
    final textColor = _resolveTextColor(s, theme);

    final content = chapterIndex < _chapterContents.length
        ? _chapterContents[chapterIndex]
        : '无内容';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12, top: 16),
          child: Text(
            '第 ${chapterIndex + 1} 章 · ${_chapters[chapterIndex]}',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ).copyWith(color: textColor),
          ),
        ),
        // Note: a single SelectionArea wraps the chapter body so the user
        // can select text via the native long-press + drag gesture; the
        // GestureDetector-on-SelectionArea pattern from earlier swallowed
        // the selection gesture, making highlights impossible to create.
        SelectionArea(
          onSelectionChanged: (selection) {
            _currentSelection = selection;
          },
          contextMenuBuilder: (context, state) {
            final text = state.selectedContent?.plainText ?? '';
            return AdaptiveTextSelectionToolbar.buttonItems(
              anchors: state.contextMenuAnchors,
              buttonItems: [
                ...state.contextMenuButtonItems,
                if (text.isNotEmpty)
                  ContextMenuButtonItem(
                    label: '高亮',
                    onPressed: () {
                      ContextMenuController.remove();
                      _showHighlightMenu(book, chapterIndex, text);
                    },
                  ),
                if (text.isNotEmpty)
                  ContextMenuButtonItem(
                    label: '书签',
                    onPressed: () {
                      ContextMenuController.remove();
                      _addBookmark(snippet: text);
                    },
                  ),
              ],
            );
          },
          child: RichText(
            textWidthBasis: TextWidthBasis.longestLine,
            text: TextSpan(
              children: _parseContentTokens(content, textColor, s),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxxl),
      ],
    );
  }

  Widget _buildChapterNav(BookEntity book, SettingsPayload? s) {
    final textColor = _resolveTextColor(s, Theme.of(context));
    final hasPrev = _currentChapter > 0;
    final hasNext = _currentChapter < _chapters.length - 1;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Row(
        children: [
          Expanded(
            child: TextButton.icon(
              onPressed: hasPrev
                  ? () {
                      setState(() {
                        _currentChapter--;
                        _currentProgress = 0;
                      });
                      _scrollCtrl.jumpTo(0);
                      _autoSaveProgress();
                    }
                  : null,
              icon: const Icon(Icons.arrow_back_ios_rounded),
              label: const Text('上一章'),
              style: TextButton.styleFrom(foregroundColor: textColor),
            ),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: hasNext
                  ? () {
                      setState(() {
                        _currentChapter++;
                        _currentProgress = 0;
                      });
                      _scrollCtrl.jumpTo(0);
                      _autoSaveProgress();
                    }
                  : null,
              icon: const Icon(Icons.arrow_forward_ios_rounded),
              label: const Text('下一章'),
              style: TextButton.styleFrom(foregroundColor: textColor),
            ),
          ),
        ],
      ),
    );
  }

  Color _resolveTextColor(SettingsPayload? s, ThemeData theme) {
    if (s == null) return theme.textTheme.bodyMedium!.color!;
    switch (s.theme) {
      case 'sepia':
        return AppPalette.sepiaText;
      case 'paper':
        return const Color(0xFF2C2C2E);
      case 'dark':
        return AppPalette.darkLabel;
      case 'light':
      default:
        return theme.brightness == Brightness.dark
            ? AppPalette.darkLabel
            : AppPalette.lightLabel;
    }
  }

  Widget _buildTopBar(BookEntity book, SettingsPayload? s) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: AnimatedSlideDown(
        visible: _showControls,
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          decoration: BoxDecoration(
            color: _resolveBgColor(s, Theme.of(context)).withOpacity(0.9),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 12),
            ],
          ),
          child: SafeArea(
            bottom: false,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () => context.pop(),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.bookmark_border_rounded),
                  tooltip: '添加书签',
                  onPressed: _addBookmark,
                ),
                IconButton(
                  icon: Icon(
                    _isPlayingTts ? Icons.pause_circle : Icons.play_circle,
                  ),
                  tooltip: '朗读',
                  onPressed: _toggleTts,
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar(BookEntity book, SettingsPayload? s) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: AnimatedSlideUp(
        visible: _showControls,
        child: Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom,
          ),
          decoration: BoxDecoration(
            color: _resolveBgColor(s, Theme.of(context)).withOpacity(0.92),
            boxShadow: const [
              BoxShadow(color: Color(0x22000000), blurRadius: 12),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildChapterScrubber(),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _BottomAction(
                        icon: Icons.star_outline,
                        label: '高亮',
                        onTap: _showHighlights,
                      ),
                      _BottomAction(
                        icon: Icons.notes_rounded,
                        label: '注释',
                        onTap: _showAnnotations,
                      ),
                      _BottomAction(
                        icon: Icons.bookmark_rounded,
                        label: '书签',
                        onTap: _showBookmarks,
                      ),
                      _BottomAction(
                        icon: Icons.text_fields_rounded,
                        label: '排版',
                        onTap: _showTypographyPanel,
                      ),
                      _BottomAction(
                        icon: _isDark(s) ? Icons.light_mode : Icons.dark_mode,
                        label: s?.theme == 'sepia' ? '护眼' : '主题',
                        onTap: _cycleTheme,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _isDark(SettingsPayload? s) =>
      s?.theme == 'dark' ||
      Theme.of(context).brightness == Brightness.dark && s == null;

  Widget _buildChapterScrubber() {
    if (_chapters.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Text(
            '第${_currentChapter + 1}章',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Expanded(
            child: Slider(
              value: _currentProgress.clamp(0.0, 1.0),
              onChanged: (v) {
                setState(() => _currentProgress = v);
                if (_scrollCtrl.hasClients) {
                  final max = _scrollCtrl.position.maxScrollExtent;
                  _scrollCtrl.jumpTo(v * max);
                }
              },
            ),
          ),
          Text(
            '${(_currentProgress * 100).round()}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildTtsOverlay(BookEntity book) {
    return Positioned(
      right: AppSpacing.md,
      bottom: 160,
      child: Material(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(40),
        elevation: 8,
        child: InkWell(
          onTap: _toggleTts,
          borderRadius: BorderRadius.circular(40),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Icon(Icons.pause, color: Colors.white),
          ),
        ),
      ),
    );
  }

  Future<void> _addBookmark({String? snippet}) async {
    final bookAsync = ref.read(readerBookProvider(widget.bookId));
    final book = bookAsync.valueOrNull;
    if (book == null) return;
    final repo = ref.read(progressRepositoryProvider);
    // Prefer the captured selection; otherwise approximate the visible
    // snippet from the current chapter content around the scroll offset so
    // the user has *some* context when jumping back to this bookmark.
    final snippetText = snippet ?? _approximateVisibleSnippet();
    final bm = await repo.addBookmark(
      bookId: book.id,
      chapterId: _chapters[_currentChapter],
      scrollOffset: _scrollCtrl.hasClients ? _scrollCtrl.offset.toInt() : 0,
      snippet: snippetText,
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已添加书签 ${bm.id.substring(0, 6)}')));
    }
  }

  /// Rough visible-text snippet for bookmarks added without an explicit
  /// selection. Picks ~40 chars around the current scroll offset.
  String _approximateVisibleSnippet() {
    if (_chapterContents.isEmpty || _currentChapter >= _chapterContents.length) {
      return '书签';
    }
    final content = _chapterContents[_currentChapter];
    final offset = (_scrollCtrl.hasClients ? _scrollCtrl.offset.toInt() : 0)
        .clamp(0, content.length);
    final start = (offset - 20).clamp(0, content.length);
    final end = (offset + 20).clamp(0, content.length);
    final raw = content.substring(start, end).replaceAll(RegExp(r'\s+'), ' ').trim();
    return raw.isEmpty ? '书签' : raw;
  }

  void _showHighlightMenu(BookEntity book, int chapterIndex, String selectedText) {
    final safeText = selectedText.isEmpty ? '（空选区）' : selectedText;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '高亮颜色',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              safeText.length > 60 ? '${safeText.substring(0, 60)}…' : safeText,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              children: ['yellow', 'green', 'blue', 'pink'].map((c) {
                return ChoiceChip(
                  label: Text(c),
                  selected: false,
                  onSelected: (_) async {
                    final repo = ref.read(progressRepositoryProvider);
                    await repo.addHighlight(
                      bookId: book.id,
                      chapterId: _chapters[chapterIndex],
                      selectedText: selectedText,
                      startOffset: 0,
                      endOffset: selectedText.length,
                      color: c,
                    );
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('已添加 $c 高亮')));
                    }
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleTts() async {
    if (_isPlayingTts) {
      await _tts.stop();
      setState(() => _isPlayingTts = false);
    } else {
      final text = _currentChapter < _chapterContents.length
          ? _chapterContents[_currentChapter]
          : '';
      if (text.isEmpty) return;
      await _tts.speak(
        text.substring(0, text.length > 600 ? 600 : text.length),
      );
      setState(() => _isPlayingTts = true);
    }
  }

  void _onTtsComplete() {
    setState(() => _isPlayingTts = false);
  }

  void _showHighlights() {
    _showBottomSheet(title: '我的高亮', child: _buildHighlightList());
  }

  void _showAnnotations() {
    _showBottomSheet(title: '我的注释', child: _buildAnnotationList());
  }

  void _showBookmarks() {
    _showBottomSheet(title: '我的书签', child: _buildBookmarkList());
  }

  void _showTypographyPanel() {
    _showBottomSheet(title: '排版设置', child: _buildTypographyPanel());
  }

  Future<void> _cycleTheme() async {
    final s = await ref.read(readerSettingsProvider.future);
    final order = ['light', 'dark', 'sepia', 'paper'];
    final i = order.indexOf(s.theme);
    final next = order[(i + 1) % order.length];
    final repo = ref.read(bookRepositoryProvider);
    await repo.saveSettings(s.copyWith(theme: next));
    ref.invalidate(readerSettingsProvider);
  }

  void _showBottomSheet({required String title, required Widget child}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Flexible(child: child),
              const SizedBox(height: AppSpacing.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightList() {
    return FutureBuilder<List<Highlight>>(
      future: ref.read(progressRepositoryProvider).fetchHighlights(widget.bookId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data!;
        if (items.isEmpty) {
          return const _PlaceholderList(icon: Icons.highlight);
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final h = items[i];
            return ListTile(
              leading: _HighlightColorDot(color: h.color),
              title: Text(
                h.selectedText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(h.chapterId),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () async {
                  await ref
                      .read(progressRepositoryProvider)
                      .deleteHighlight(h.id);
                  if (mounted) setState(() {});
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnnotationList() {
    return FutureBuilder<List<Annotation>>(
      future: ref.read(progressRepositoryProvider).fetchAnnotations(widget.bookId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data!;
        if (items.isEmpty) {
          return const _PlaceholderList(icon: Icons.notes);
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final a = items[i];
            return ListTile(
              title: Text(a.note),
              subtitle: Text(a.anchorText),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () async {
                  await ref
                      .read(progressRepositoryProvider)
                      .deleteAnnotation(a.id);
                  if (mounted) setState(() {});
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBookmarkList() {
    return FutureBuilder<List<Bookmark>>(
      future: ref.read(progressRepositoryProvider).fetchBookmarks(widget.bookId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data!;
        if (items.isEmpty) {
          return const _PlaceholderList(icon: Icons.bookmark);
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const ClampingScrollPhysics(),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final b = items[i];
            return ListTile(
              leading: const Icon(Icons.bookmark, size: 20),
              title: Text(
                b.snippet,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(b.chapterId),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                onPressed: () async {
                  await ref
                      .read(progressRepositoryProvider)
                      .deleteBookmark(b.id);
                  if (mounted) setState(() {});
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTypographyPanel() {
    final s = ref.watch(readerSettingsProvider).valueOrNull;
    final settings = s ?? const SettingsPayload();

    return StatefulBuilder(
      builder: (context, setInner) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SteppedRow(
              label: '字号',
              value: settings.fontSize,
              min: 12,
              max: 28,
              onChanged: (v) async {
                final repo = ref.read(bookRepositoryProvider);
                await repo.saveSettings(
                  settings.copyWith(fontSize: v.toDouble()),
                );
                setInner(() {});
                ref.invalidate(readerSettingsProvider);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _SteppedRow(
              label: '行距',
              value: settings.lineHeight,
              min: 1.0,
              max: 2.4,
              step: 0.1,
              onChanged: (v) async {
                final repo = ref.read(bookRepositoryProvider);
                await repo.saveSettings(settings.copyWith(lineHeight: v));
                setInner(() {});
                ref.invalidate(readerSettingsProvider);
              },
            ),
            const SizedBox(height: AppSpacing.md),
            _SteppedRow(
              label: '段间距',
              value: settings.paragraphSpacing,
              min: 0.5,
              max: 2.5,
              step: 0.1,
              onChanged: (v) async {
                final repo = ref.read(bookRepositoryProvider);
                await repo.saveSettings(settings.copyWith(paragraphSpacing: v));
                setInner(() {});
                ref.invalidate(readerSettingsProvider);
              },
            ),
          ],
        );
      },
    );
  }
}

class _PlaceholderList extends StatelessWidget {
  const _PlaceholderList({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).hintColor),
            const SizedBox(height: AppSpacing.sm),
            Text('暂无内容', style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _HighlightColorDot extends StatelessWidget {
  const _HighlightColorDot({required this.color});
  final String color;

  @override
  Widget build(BuildContext context) {
    const mapping = {
      'yellow': AppPalette.highlightYellow,
      'green': AppPalette.highlightGreen,
      'blue': AppPalette.highlightBlue,
      'pink': AppPalette.highlightPink,
    };
    final c = mapping[color] ?? Colors.grey.shade300;
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
  }
}

class _SteppedRow extends StatelessWidget {
  const _SteppedRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    this.step = 1,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final double step;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: () => onChanged((value - step).clamp(min, max)),
        ),
        Expanded(
          child: Center(
            child: Text(
              step == 1 ? value.toStringAsFixed(0) : value.toStringAsFixed(1),
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: () => onChanged((value + step).clamp(min, max)),
        ),
      ],
    );
  }
}

class _BottomAction extends StatelessWidget {
  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.primary;
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: textColor),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 11, color: textColor)),
          ],
        ),
      ),
    );
  }
}

class AnimatedSlideDown extends StatefulWidget {
  const AnimatedSlideDown({
    required this.child,
    required this.visible,
    super.key,
  });
  final Widget child;
  final bool visible;

  @override
  State<AnimatedSlideDown> createState() => _AnimatedSlideDownState();
}

class _AnimatedSlideDownState extends State<AnimatedSlideDown>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
      value: widget.visible ? 1.0 : 0.0,
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: AppMotion.curve));
  }

  @override
  void didUpdateWidget(AnimatedSlideDown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(position: _offset, child: widget.child);
  }
}

class AnimatedSlideUp extends StatefulWidget {
  const AnimatedSlideUp({
    required this.child,
    required this.visible,
    super.key,
  });
  final Widget child;
  final bool visible;

  @override
  State<AnimatedSlideUp> createState() => _AnimatedSlideUpState();
}

class _AnimatedSlideUpState extends State<AnimatedSlideUp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
      value: widget.visible ? 1.0 : 0.0,
    );
    _offset = Tween<Offset>(
      begin: const Offset(0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: AppMotion.curve));
  }

  @override
  void didUpdateWidget(AnimatedSlideUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible) {
      _ctrl.forward();
    } else {
      _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(position: _offset, child: widget.child);
  }
}
