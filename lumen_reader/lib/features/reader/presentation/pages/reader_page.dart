import 'dart:convert';
import 'dart:io';

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
  final bool _showControls = true;
  bool _isPlayingTts = false;
  bool _isLoading = true;

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
    _scrollCtrl.dispose();
    _pageCtrl.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    _tts.setCompletionHandler(_onTtsComplete);
  }

  Future<void> _loadBook() async {
    final book = await ref.read(readerBookProvider(widget.bookId).future);
    if (book == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    final progressRepo = ref.read(progressRepositoryProvider);
    final saved = await progressRepo.fetchProgress(book.id);

    try {
      if (book.format == 'epub') {
        await _loadEpubChapters(book);
      } else if (book.format == 'pdf') {
        final text = await PdfParser().extractText(book.filePath);
        _chapters = ['全文'];
        _chapterContents = [text];
      } else {
        // txt and other plain-text formats
        _chapters = ['全文'];
        _chapterContents = [await _extractPlainText(book.filePath)];
      }
      _chapterOffsets.add(0);
    } catch (_) {
      _chapters = ['错误'];
      _chapterContents = ['无法加载文件内容'];
    }

    if (saved != null) {
      _currentChapter = _chapters.indexWhere((c) => c == saved.chapterId);
      if (_currentChapter == -1) _currentChapter = 0;
      _currentProgress = saved.progress;
    }

    final repo = ref.read(bookRepositoryProvider);
    await repo.recordRead(book.id);

    if (mounted) {
      setState(() => _isLoading = false);
      if (saved != null && _scrollCtrl.hasClients) {
        _scrollCtrl.jumpTo(saved.scrollOffset.toDouble());
      }
    }
  }

  Future<void> _loadEpubChapters(BookEntity book) async {
    final chapters = await EpubParser().extractChapters(book.filePath);
    _chapters = chapters.map((c) => c.title).toList();
    _chapterContents = chapters.map((c) => c.content).toList();
    if (_chapters.isEmpty) {
      _chapters = ['未命名章节'];
      _chapterContents = ['无法解析 EPUB 内容'];
    }
  }

  Future<String> _extractPlainText(String path) async {
    try {
      final bytes = await File(path).readAsBytes();

      // Strip UTF-8 BOM
      if (bytes.length >= 3 &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF) {
        return utf8.decode(bytes.sublist(3), allowMalformed: true);
      }

      // Strip UTF-16 LE BOM
      if (bytes.length >= 2 &&
          bytes[0] == 0xFF &&
          bytes[1] == 0xFE) {
        return String.fromCharCodes(
          bytes.buffer.asUint16List(2),
        );
      }

      // Strip UTF-16 BE BOM
      if (bytes.length >= 2 &&
          bytes[0] == 0xFE &&
          bytes[1] == 0xFF) {
        final u16 = bytes.buffer.asUint16List(2);
        final swapped = Uint16List(u16.length);
        for (int i = 0; i < u16.length; i++) {
          swapped[i] = (u16[i] << 8) | (u16[i] >> 8);
        }
        return String.fromCharCodes(swapped);
      }

      // Try UTF-8 first
      try {
        return utf8.decode(bytes);
      } catch (_) {
        // Not valid UTF-8 — likely GBK/GB18030 for Chinese txt files.
        // Fallback: decode as Latin-1 so content is at least visible
        // (not perfect, but avoids blank page).
        return utf8.decode(bytes, allowMalformed: true);
      }
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
  Future<void> _autoSaveProgress() async {
    final now = DateTime.now();
    if (_lastSave != null &&
        now.difference(_lastSave!) < const Duration(seconds: 5)) {
      return;
    }
    _lastSave = now;

    final bookAsync = ref.read(readerBookProvider(widget.bookId));
    final book = bookAsync.valueOrNull;
    if (book == null) return;

    final repo = ref.read(progressRepositoryProvider);
    await repo.saveProgress(
      ReadingProgress(
        bookId: book.id,
        chapterId: _chapters.isNotEmpty ? _chapters[_currentChapter] : '',
        progress: _currentProgress,
        scrollOffset: _scrollCtrl.hasClients ? _scrollCtrl.offset.toInt() : 0,
        totalWordsRead: (_scrollCtrl.hasClients ? _scrollCtrl.offset ~/ 20 : 0),
        updatedAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bookAsync = ref.watch(readerBookProvider(widget.bookId));
    final settingsAsync = ref.watch(readerSettingsProvider);

    return Scaffold(
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
              _buildReaderSurface(book, settingsAsync.valueOrNull),
              _buildTopBar(book, settingsAsync.valueOrNull),
              _buildBottomBar(book, settingsAsync.valueOrNull),
              if (_isPlayingTts) _buildTtsOverlay(book),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
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
        onPageChanged: (i) => setState(() => _currentChapter = i),
        itemBuilder: (context, index) => _buildChapter(book, index, settings),
      );
    }
    return SingleChildScrollView(
      controller: _scrollCtrl,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: MediaQuery.of(context).padding.top + AppSpacing.md,
      ),
      child: _buildChapterBody(book, _currentChapter, settings),
    );
  }

  Widget _buildChapter(BookEntity book, int index, SettingsPayload? settings) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: MediaQuery.of(context).padding.top + AppSpacing.md,
      ),
      child: _buildChapterBody(book, index, settings),
    );
  }

  Widget _buildChapterBody(
    BookEntity book,
    int chapterIndex,
    SettingsPayload? s,
  ) {
    final theme = Theme.of(context);
    final textColor = _resolveTextColor(s, theme);

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '第 ${chapterIndex + 1} 章 · ${_chapters[chapterIndex]}',
            style: TextStyle(
              fontSize: (s?.fontSize ?? 17) + 4,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GestureDetector(
            onLongPressStart: (details) {
              _showHighlightMenu(book, chapterIndex, details.globalPosition);
            },
            child: Text(
              chapterIndex < _chapterContents.length
                  ? _chapterContents[chapterIndex]
                  : '无内容',
              style: TextStyle(
                fontSize: s?.fontSize ?? 17,
                height: s?.lineHeight ?? 1.6,
                color: textColor,
                fontFamily: s?.fontFamily,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxxl),
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

  Future<void> _addBookmark() async {
    final bookAsync = ref.read(readerBookProvider(widget.bookId));
    final book = bookAsync.valueOrNull;
    if (book == null) return;
    final repo = ref.read(progressRepositoryProvider);
    final bm = await repo.addBookmark(
      bookId: book.id,
      chapterId: _chapters[_currentChapter],
      scrollOffset: _scrollCtrl.hasClients ? _scrollCtrl.offset.toInt() : 0,
      snippet: '示例片段...',
    );
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('已添加书签 ${bm.id.substring(0, 6)}')));
    }
  }

  void _showHighlightMenu(BookEntity book, int chapterIndex, Offset pos) {
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
                      selectedText: '当前段落',
                      startOffset: 0,
                      endOffset: 0,
                      color: c,
                    );
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('已添加 $c 高亮')));
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

  Widget _buildHighlightList() => const _PlaceholderList(icon: Icons.highlight);
  Widget _buildAnnotationList() => const _PlaceholderList(icon: Icons.notes);
  Widget _buildBookmarkList() => const _PlaceholderList(icon: Icons.bookmark);

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
