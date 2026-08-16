import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../reader/domain/entities/book_entity.dart';
import '../../../reader/domain/entities/reading_entities.dart';
import '../../../reader/infrastructure/book_repository.dart';
import '../../../reader/infrastructure/progress_repository.dart';

enum BookDisplayMode {
  coverFlat,
  spineOut,
}

const String _prefsDisplayModeKey = 'shelf_display_mode';

final shelfBooksProvider = FutureProvider<List<BookEntity>>((ref) async {
  final repo = ref.watch(bookRepositoryProvider);
  return repo.fetchAllBooks();
});

final displayModeProvider =
    StateNotifierProvider<DisplayModeNotifier, BookDisplayMode>((ref) {
  return DisplayModeNotifier();
});

class DisplayModeNotifier extends StateNotifier<BookDisplayMode> {
  DisplayModeNotifier() : super(BookDisplayMode.coverFlat) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idx = prefs.getInt(_prefsDisplayModeKey) ?? 0;
      if (idx >= 0 && idx < BookDisplayMode.values.length) {
        state = BookDisplayMode.values[idx];
      }
    } catch (_) {}
  }

  Future<void> setMode(BookDisplayMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefsDisplayModeKey, mode.index);
    } catch (_) {}
  }

  void toggle() {
    setMode(
      state == BookDisplayMode.coverFlat
          ? BookDisplayMode.spineOut
          : BookDisplayMode.coverFlat,
    );
  }
}

class ShelfPage extends ConsumerStatefulWidget {
  const ShelfPage({super.key});

  @override
  ConsumerState<ShelfPage> createState() => _ShelfPageState();
}

class _ShelfPageState extends ConsumerState<ShelfPage> {
  late final TextEditingController _searchCtrl;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController()
      ..addListener(() {
        setState(() => _query = _searchCtrl.text);
      });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: _buildShelfBackground(isDark),
        child: SafeArea(
          child: Column(
            children: [
              _buildShelfAppBar(theme, isDark),
              _buildSearchBar(theme, isDark),
              const SizedBox(height: AppSpacing.sm),
              Expanded(child: _buildContent(theme, isDark)),
            ],
          ),
        ),
      ),
    );
  }

  BoxDecoration _buildShelfBackground(bool isDark) {
    if (isDark) {
      return const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A1410),
            Color(0xFF2A1F18),
            Color(0xFF1F1712),
            Color(0xFF261C15),
          ],
          stops: [0.0, 0.4, 0.7, 1.0],
        ),
      );
    }
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFD9B88C),
          Color(0xFFC9A876),
          Color(0xFFC49F6B),
          Color(0xFFBF9862),
        ],
        stops: [0.0, 0.35, 0.7, 1.0],
      ),
    );
  }

  Widget _buildShelfAppBar(ThemeData theme, bool isDark) {
    final displayMode = ref.watch(displayModeProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: (isDark
                ? const Color(0xFF14100C)
                : const Color(0xFFAF8A59))
            .withOpacity(0.55),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.black26
                : Colors.brown.withOpacity(0.35),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2C2018) : const Color(0xFF8B6239),
              borderRadius: BorderRadius.circular(AppRadius.md),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.menu_book_rounded,
              color: isDark ? const Color(0xFFE0C097) : const Color(0xFFF5E6CC),
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Center(
              child: Text(
                '书架',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: isDark
                      ? const Color(0xFFE8D3B1)
                      : const Color(0xFF3F2A18),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
          IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (isDark
                        ? const Color(0xFF2C2018)
                        : const Color(0xFF8B6239))
                    .withOpacity(0.9),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                displayMode == BookDisplayMode.coverFlat
                    ? Icons.view_agenda_outlined
                    : Icons.auto_stories_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            tooltip: displayMode == BookDisplayMode.coverFlat
                ? '切换到书脊朝外'
                : '切换到正面朝上',
            onPressed: () {
              ref.read(displayModeProvider.notifier).toggle();
            },
          ),
          IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (isDark
                        ? const Color(0xFF2C2018)
                        : const Color(0xFF8B6239))
                    .withOpacity(0.9),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
            tooltip: '导入书籍',
            onPressed: _import,
          ),
          IconButton(
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (isDark
                        ? const Color(0xFF2C2018)
                        : const Color(0xFF8B6239))
                    .withOpacity(0.9),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                Icons.settings_outlined,
                color:
                    isDark ? const Color(0xFFE0C097) : const Color(0xFFF5E6CC),
                size: 20,
              ),
            ),
            tooltip: '设置',
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme, bool isDark) {
    final bgColor = isDark
        ? const Color(0xFF2C2018).withOpacity(0.75)
        : const Color(0xFF8B6239).withOpacity(0.35);
    final hintColor =
        isDark ? const Color(0xFFA08568) : const Color(0xFF5C3E22);
    final textColor =
        isDark ? const Color(0xFFEFE0C7) : const Color(0xFF3F2A18);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        0,
      ),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.brown.withOpacity(0.25),
          ),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: TextStyle(color: textColor),
          cursorColor: textColor,
          decoration: InputDecoration(
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, color: hintColor, size: 20),
            hintText: '搜索书架',
            hintStyle: TextStyle(color: hintColor),
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme, bool isDark) {
    final booksAsync = ref.watch(shelfBooksProvider);
    final displayMode = ref.watch(displayModeProvider);

    return booksAsync.when(
      data: (books) {
        final filtered = _query.isEmpty
            ? books
            : books.where((b) {
                final q = _query.toLowerCase();
                return b.title.toLowerCase().contains(q) ||
                    b.author.toLowerCase().contains(q);
              }).toList();

        if (filtered.isEmpty) {
          return _EmptyShelf(
            onImport: _import,
            isSearch: _query.isNotEmpty,
            isDark: isDark,
          );
        }
        return _BookShelfGrid(
          books: filtered,
          isDark: isDark,
          displayMode: displayMode,
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Text('加载失败: $e'),
        ),
      ),
    );
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['epub', 'pdf', 'txt'],
      allowMultiple: true,
    );
    if (result == null || result.files.isEmpty) return;

    final repo = ref.read(bookRepositoryProvider);
    int added = 0;
    for (final f in result.files) {
      if (f.path != null) {
        try {
          await repo.addBookFromFile(filePath: f.path!);
          added++;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text('导入失败: ${f.name} — $e')));
          }
        }
      }
    }
    if (added > 0 && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('成功导入 $added 本书')));
    }
    ref.invalidate(shelfBooksProvider);
  }
}

// ===========================================================================
// SKEUOMORPHIC BOOK SHELF GRID
// ===========================================================================
class _BookShelfGrid extends ConsumerWidget {
  const _BookShelfGrid({
    required this.books,
    required this.isDark,
    required this.displayMode,
  });
  final List<BookEntity> books;
  final bool isDark;
  final BookDisplayMode displayMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxExtent =
            displayMode == BookDisplayMode.coverFlat ? 160.0 : 110.0;
        const spacing = AppSpacing.md;
        final crossAxisCount =
            ((constraints.maxWidth + spacing) / (maxExtent + spacing)).floor();
        final cols = crossAxisCount < 2 ? 2 : crossAxisCount;

        final rows = (books.length / cols).ceil();
        final List<Widget> children = [];

        for (int r = 0; r < rows; r++) {
          final start = r * cols;
          final end = (start + cols).clamp(0, books.length);

          children.add(
            _ShelfPlankRow(
              isDark: isDark,
              rowIndex: r,
              books: books.sublist(start, end),
              cols: cols,
              displayMode: displayMode,
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        );
      },
    );
  }
}

class _ShelfPlankRow extends StatelessWidget {
  const _ShelfPlankRow({
    required this.isDark,
    required this.rowIndex,
    required this.books,
    required this.cols,
    required this.displayMode,
  });
  final bool isDark;
  final int rowIndex;
  final List<BookEntity> books;
  final int cols;
  final BookDisplayMode displayMode;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(cols, (i) {
                final book = i < books.length ? books[i] : null;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xs,
                    ),
                    child: book != null
                        ? _BookCard(
                            book: book,
                            isDark: isDark,
                            displayMode: displayMode,
                          )
                        : const SizedBox.shrink(),
                  ),
                );
              }),
            ),
          ),
          Transform.translate(
            offset: const Offset(0, -6),
            child: _ShelfPlank(isDark: isDark),
          ),
        ],
      ),
    );
  }
}

class _ShelfPlank extends StatelessWidget {
  const _ShelfPlank({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          top: Radius.zero,
          bottom: Radius.circular(AppRadius.sm),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [
                  Color(0xFF4A3728),
                  Color(0xFF2E2117),
                  Color(0xFF1F160F),
                  Color(0xFF140E09),
                ]
              : const [
                  Color(0xFF8B6239),
                  Color(0xFF6B4A27),
                  Color(0xFF563A1E),
                  Color(0xFF3F2A14),
                ],
          stops: const [0.0, 0.25, 0.7, 1.0],
        ),
        boxShadow: [
          const BoxShadow(
            color: Colors.black38,
            blurRadius: 6,
            offset: Offset(0, -3),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark
                ? const Color(0xFF6B4F37).withOpacity(0.9)
                : const Color(0xFFD4B188),
            width: 1.2,
          ),
        ),
      ),
      child: CustomPaint(
        painter: _WoodGrainPainter(isDark: isDark, seed: isDark ? 3 : 7),
      ),
    );
  }
}

class _WoodGrainPainter extends CustomPainter {
  _WoodGrainPainter({required this.isDark, required this.seed});
  final bool isDark;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6;

    for (int i = 0; i < 6; i++) {
      final y = 4 + rng.nextDouble() * (size.height - 8);
      final color = (isDark
              ? const Color(0xFF1A120B)
              : const Color(0xFF5C3E22))
          .withOpacity(0.2 + rng.nextDouble() * 0.25);
      paint.color = color;
      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= size.width; x += 12) {
        final wave = sin((x / 50) + rng.nextDouble() * 3) * 0.9;
        path.lineTo(x, y + wave);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WoodGrainPainter old) =>
      old.isDark != isDark || old.seed != seed;
}

// ===========================================================================
// BOOK CARD (supports both coverFlat and spineOut modes)
// ===========================================================================
class _BookCard extends ConsumerStatefulWidget {
  const _BookCard({
    required this.book,
    required this.isDark,
    required this.displayMode,
  });
  final BookEntity book;
  final bool isDark;
  final BookDisplayMode displayMode;

  @override
  ConsumerState<_BookCard> createState() => _BookCardState();
}

class _BookCardState extends ConsumerState<_BookCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final progressAsync = ref.watch(progressProvider(widget.book.id));

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        transform: Matrix4.identity()
          ..translate(0.0, _pressed ? 3.0 : 0.0)
          ..scale(_pressed ? 0.97 : 1.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => context.push('/reader/${widget.book.id}'),
            onLongPress: () => _showMenu(context),
            child: widget.displayMode == BookDisplayMode.coverFlat
                ? _buildCoverFlatMode(progressAsync)
                : _buildSpineOutMode(progressAsync),
          ),
        ),
      ),
    );
  }

  Widget _buildCoverFlatMode(AsyncValue<ReadingProgress?> progressAsync) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 0.68,
              child: _SkeuomorphicBookCover(
                book: widget.book,
                isDark: widget.isDark,
              ),
            ),
            SizedBox(
              height: 48,
              child: _CoverReflection(
                book: widget.book,
                isDark: widget.isDark,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.isDark
                    ? const Color(0xFFEFE0C7)
                    : const Color(0xFF3A2614),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: widget.isDark
                    ? const Color(0xFFB09878)
                    : const Color(0xFF6B4A27),
              ),
            ),
          ],
        ),
        Positioned(
          left: 8,
          bottom: 64,
          child: progressAsync.when(
            data: (p) {
              final pct = ((p?.progress ?? 0) * 100).round();
              return Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: widget.isDark
                      ? const Color(0xFFD4B188)
                      : const Color(0xFF5C3E22),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
        Positioned(
          right: 4,
          bottom: 60,
          child: GestureDetector(
            onTap: () => _showMenu(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 4,
              ),
              child: Text(
                '•••',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: widget.isDark
                      ? const Color(0xFFB09878).withOpacity(0.85)
                      : const Color(0xFF6B4A27).withOpacity(0.85),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpineOutMode(AsyncValue<ReadingProgress?> progressAsync) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 0.22,
              child: _SpineOutBook(
                book: widget.book,
                isDark: widget.isDark,
              ),
            ),
            SizedBox(
              height: 40,
              child: _SpineReflection(
                book: widget.book,
                isDark: widget.isDark,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.book.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: widget.isDark
                    ? const Color(0xFFEFE0C7)
                    : const Color(0xFF3A2614),
                height: 1.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              widget.book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: widget.isDark
                    ? const Color(0xFFB09878)
                    : const Color(0xFF6B4A27),
              ),
            ),
          ],
        ),
        Positioned(
          left: 4,
          bottom: 54,
          child: progressAsync.when(
            data: (p) {
              final pct = ((p?.progress ?? 0) * 100).round();
              return Text(
                '$pct%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: widget.isDark
                      ? const Color(0xFFD4B188)
                      : const Color(0xFF5C3E22),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
        Positioned(
          right: 2,
          bottom: 50,
          child: GestureDetector(
            onTap: () => _showMenu(context),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 2,
              ),
              child: Text(
                '•••',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: widget.isDark
                      ? const Color(0xFFB09878).withOpacity(0.85)
                      : const Color(0xFF6B4A27).withOpacity(0.85),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.push_pin_outlined),
              title: Text(widget.book.isPinned ? '取消置顶' : '置顶'),
              onTap: () async {
                final repo = ref.read(bookRepositoryProvider);
                await repo.pinBook(
                  widget.book.id,
                  pinned: !widget.book.isPinned,
                );
                ref.invalidate(shelfBooksProvider);
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('书籍详情'),
              onTap: () {
                Navigator.pop(sheetContext);
                _showBookDetails(context);
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppPalette.lightRed,
              ),
              title: const Text(
                '从书架移除',
                style: TextStyle(color: AppPalette.lightRed),
              ),
              onTap: () async {
                final repo = ref.read(bookRepositoryProvider);
                await repo.removeBook(widget.book.id);
                ref.invalidate(shelfBooksProvider);
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showBookDetails(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor =
        isDark ? const Color(0xFFEFE0C7) : const Color(0xFF3A2614);
    final subColor = isDark ? const Color(0xFFB09878) : const Color(0xFF6B4A27);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF221914) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
        contentPadding: const EdgeInsets.all(AppSpacing.lg),
        content: SizedBox(
          width: 320,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 72,
                      height: 100,
                      child: _SkeuomorphicBookCover(
                        book: widget.book,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.book.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: textColor,
                              fontWeight: FontWeight.w700,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            widget.book.author,
                            style: TextStyle(
                              color: subColor,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white12
                                  : Colors.brown.shade100,
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              widget.book.format.toUpperCase(),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: subColor,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                const Divider(height: 1),
                const SizedBox(height: AppSpacing.md),
                _DetailRow(
                  label: '文件路径',
                  value: widget.book.filePath,
                  isDark: isDark,
                ),
                _DetailRow(
                  label: '加入书架',
                  value: widget.book.addedAt.toString().substring(0, 16),
                  isDark: isDark,
                ),
                _DetailRow(
                  label: '上次阅读',
                  value: widget.book.lastReadAt == null
                      ? '尚未阅读'
                      : widget.book.lastReadAt.toString().substring(0, 16),
                  isDark: isDark,
                ),
                _DetailRow(
                  label: '预计字数',
                  value: widget.book.totalWords == null
                      ? '—'
                      : '${widget.book.totalWords}',
                  isDark: isDark,
                ),
                _DetailRow(
                  label: '置顶',
                  value: widget.book.isPinned ? '是' : '否',
                  isDark: isDark,
                ),
                if (widget.book.description != null &&
                    widget.book.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '简介',
                    style: TextStyle(
                      color: subColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.book.description!.trim(),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    required this.isDark,
  });
  final String label;
  final String value;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDark ? const Color(0xFFEFE0C7) : const Color(0xFF3A2614);
    final subColor = isDark ? const Color(0xFFB09878) : const Color(0xFF6B4A27);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: TextStyle(
                color: subColor,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final progressProvider = FutureProvider.family<ReadingProgress?, String>((
  ref,
  bookId,
) {
  final repo = ref.watch(progressRepositoryProvider);
  return repo.fetchProgress(bookId);
});

// ===========================================================================
// COVER FLAT MODE — SKEUOMORPHIC BOOK COVER
// ===========================================================================
class _SkeuomorphicBookCover extends StatelessWidget {
  const _SkeuomorphicBookCover({required this.book, required this.isDark});
  final BookEntity book;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final cover = ClipRRect(
      borderRadius: const BorderRadius.horizontal(
        left: Radius.circular(4),
        right: Radius.circular(AppRadius.sm),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            left: 8,
            right: 5,
            child: Stack(
              children: [
                Positioned.fill(child: _CoverImageContent(book: book)),
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.22),
                            Colors.white.withOpacity(0.08),
                            Colors.transparent,
                            Colors.transparent,
                          ],
                          stops: const [0.0, 0.25, 0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 9,
            child: _BookSpine(isDark: isDark, book: book),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 6,
            child: _BookPageEdge(isDark: isDark),
          ),
          Positioned.fill(
            left: 8,
            right: 5,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: Colors.white.withOpacity(0.15),
                      width: 1,
                    ),
                    left: BorderSide(
                      color: Colors.white.withOpacity(0.06),
                      width: 1,
                    ),
                    right: BorderSide(
                      color: Colors.black.withOpacity(0.3),
                      width: 1,
                    ),
                    bottom: BorderSide(
                      color: Colors.black.withOpacity(0.4),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.horizontal(
          left: Radius.circular(4),
          right: Radius.circular(AppRadius.sm),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.32),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: cover,
    );
  }
}

class _CoverImageContent extends StatelessWidget {
  const _CoverImageContent({required this.book});
  final BookEntity book;

  @override
  Widget build(BuildContext context) {
    if (book.coverPath != null) {
      final f = File(book.coverPath!);
      if (f.existsSync()) {
        return Image.file(
          f,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) {
            return _FallbackCover(book: book);
          },
        );
      }
    }
    return _FallbackCover(book: book);
  }
}

class _BookSpine extends StatelessWidget {
  const _BookSpine({required this.isDark, required this.book});
  final bool isDark;
  final BookEntity book;

  @override
  Widget build(BuildContext context) {
    final colorSeed = book.title.codeUnits.fold<int>(0, (a, b) => a + b) +
        book.author.codeUnits.fold<int>(0, (a, b) => a + b);
    final palette = <Color>[
      const Color(0xFF3A1F11),
      const Color(0xFF1F3044),
      const Color(0xFF2E2144),
      const Color(0xFF1F3A28),
      const Color(0xFF3A2A11),
      const Color(0xFF3B1B33),
    ];
    final spineDark = palette[colorSeed % palette.length];
    final spineLight = Color.lerp(spineDark, Colors.brown.shade200, 0.3)!;
    final spineHighlight = Color.lerp(spineDark, Colors.white, 0.2)!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            spineDark,
            Color.lerp(spineDark, spineLight, 0.1)!,
            Color.lerp(spineDark, spineLight, 0.4)!,
            spineHighlight,
          ],
          stops: const [0.0, 0.35, 0.75, 1.0],
        ),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
      ),
      child: CustomPaint(
        painter: _SpineGrainPainter(spineColor: spineDark, seed: colorSeed),
      ),
    );
  }
}

class _SpineGrainPainter extends CustomPainter {
  _SpineGrainPainter({required this.spineColor, required this.seed});
  final Color spineColor;
  final int seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = Random(seed);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 0; i < 4; i++) {
      final x = 1.0 + (i * (size.width - 2) / 4);
      paint.color = Colors.black.withOpacity(0.5);
      canvas.drawLine(Offset(x, 2), Offset(x, size.height - 2), paint);
      paint.color = Colors.white.withOpacity(0.08);
      canvas.drawLine(
        Offset(x + 0.4, 2),
        Offset(x + 0.4, size.height - 2),
        paint,
      );
    }

    final speck = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 14; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      speck.color = (rng.nextBool()
              ? Colors.black
              : Color.lerp(spineColor, Colors.white, 0.3)!)
          .withOpacity(rng.nextDouble() * 0.4);
      canvas.drawCircle(Offset(x, y), 0.5, speck);
    }
  }

  @override
  bool shouldRepaint(covariant _SpineGrainPainter old) =>
      old.seed != seed || old.spineColor != spineColor;
}

class _BookPageEdge extends StatelessWidget {
  const _BookPageEdge({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Color(0xFFF5EEDD),
            Color(0xFFF8F2E0),
            Color(0xFFFBF5E5),
            Color(0xFFFFFAF0),
            Color(0xFFEDE3CB),
          ],
          stops: [0.0, 0.3, 0.65, 0.85, 1.0],
        ),
        borderRadius: BorderRadius.horizontal(
          right: Radius.circular(AppRadius.sm),
        ),
      ),
      child: CustomPaint(painter: _PageLinePainter()),
    );
  }
}

class _PageLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFC9B894).withOpacity(0.5)
      ..strokeWidth = 0.4
      ..style = PaintingStyle.stroke;
    for (double y = 3; y < size.height - 2; y += 1.8) {
      paint.color = Color.lerp(
        const Color(0xFFC9B894).withOpacity(0.35),
        const Color(0xFFC9B894).withOpacity(0.7),
        (y / size.height).clamp(0.0, 1.0),
      )!;
      canvas.drawLine(Offset(0, y), Offset(size.width - 0.2, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

class _CoverReflection extends StatelessWidget {
  const _CoverReflection({required this.book, required this.isDark});
  final BookEntity book;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.35,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.transparent],
          stops: [0.0, 0.55],
        ).createShader(bounds),
        child: Transform(
          alignment: Alignment.topCenter,
          transform: Matrix4.identity()
            ..scale(1.0, -0.4)
            ..translate(0.0, -1.25),
          child: ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(4),
              right: Radius.circular(AppRadius.sm),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  left: 8,
                  right: 5,
                  child: _CoverImageContent(book: book),
                ),
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: 9,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          Color(0xFF2A1A0E),
                          Color(0xFF5A3A22),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: 6,
                  child: Container(color: const Color(0xFFFBF5E5)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===========================================================================
// SPINE OUT MODE — VERTICAL SPINE DISPLAY
// ===========================================================================
class _SpineOutBook extends StatelessWidget {
  const _SpineOutBook({required this.book, required this.isDark});
  final BookEntity book;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colorSeed = book.title.codeUnits.fold<int>(0, (a, b) => a + b) +
        book.author.codeUnits.fold<int>(0, (a, b) => a + b);
    final spinePalette = <Color>[
      const Color(0xFF6B3410),
      const Color(0xFF2C4A6B),
      const Color(0xFF4A3A6B),
      const Color(0xFF2E5A3A),
      const Color(0xFF6B4A20),
      const Color(0xFF5A2A4A),
      const Color(0xFF6B2A2A),
      const Color(0xFF1A4A5A),
    ];
    final baseColor = spinePalette[colorSeed % spinePalette.length];
    final lighter = Color.lerp(baseColor, Colors.white, 0.25)!;
    final darker = Color.lerp(baseColor, Colors.black, 0.35)!;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 24,
            spreadRadius: -4,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.32),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.4),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            darker,
            baseColor,
            lighter,
            baseColor,
            darker,
          ],
          stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(0.2),
                        Colors.white.withOpacity(0.06),
                        Colors.transparent,
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.3, 0.65, 1.0],
                    ),
                  ),
                ),
              ),
            ),
            Positioned.fill(
              left: 2,
              right: 2,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: Center(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              letterSpacing: 0.5,
                              shadows: [
                                Shadow(
                                  color: Colors.black38,
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8, top: 4),
                    child: Text(
                      book.author.length > 6
                          ? '${book.author.substring(0, 6)}.'
                          : book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w500,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 2.5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.black.withOpacity(0.08),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 2.5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                    colors: [
                      Colors.black.withOpacity(0.35),
                      Colors.black.withOpacity(0.06),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 6,
              left: 4,
              right: 4,
              child: Container(
                height: 1,
                color: Colors.black.withOpacity(0.3),
              ),
            ),
            Positioned(
              bottom: 6,
              left: 4,
              right: 4,
              child: Container(
                height: 1,
                color: Colors.black.withOpacity(0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpineReflection extends StatelessWidget {
  const _SpineReflection({required this.book, required this.isDark});
  final BookEntity book;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final colorSeed = book.title.codeUnits.fold<int>(0, (a, b) => a + b) +
        book.author.codeUnits.fold<int>(0, (a, b) => a + b);
    final spinePalette = <Color>[
      const Color(0xFF6B3410),
      const Color(0xFF2C4A6B),
      const Color(0xFF4A3A6B),
      const Color(0xFF2E5A3A),
      const Color(0xFF6B4A20),
      const Color(0xFF5A2A4A),
    ];
    final baseColor = spinePalette[colorSeed % spinePalette.length];
    final darker = Color.lerp(baseColor, Colors.black, 0.25)!;

    return Opacity(
      opacity: 0.35,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.transparent],
          stops: [0.0, 0.55],
        ).createShader(bounds),
        child: Transform(
          alignment: Alignment.topCenter,
          transform: Matrix4.identity()
            ..scale(1.0, -0.45)
            ..translate(0.0, -1.22),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    darker,
                    baseColor,
                    darker,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FallbackCover extends StatelessWidget {
  const _FallbackCover({required this.book});
  final BookEntity book;

  @override
  Widget build(BuildContext context) {
    final colors = [
      const Color(0xFF1D3557),
      const Color(0xFF6D4C41),
      const Color(0xFF4527A0),
      const Color(0xFF00695C),
      const Color(0xFFBF360C),
      const Color(0xFF4A148C),
      const Color(0xFF01579B),
      const Color(0xFF880E4F),
    ];
    final seed = book.title.codeUnits.fold<int>(0, (a, b) => a + b) +
        book.author.codeUnits.fold<int>(0, (a, b) => a + b);
    final i = seed % colors.length;
    final base = colors[i];
    final lighter = Color.lerp(base, Colors.white, 0.22)!;
    final darker = Color.lerp(base, Colors.black, 0.35)!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [lighter, base, darker],
          stops: const [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 80,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withOpacity(0.18), Colors.transparent],
                ),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                book.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  height: 1.2,
                  shadows: [
                    Shadow(
                      color: Colors.black38,
                      offset: Offset(0, 1),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 10,
            right: 10,
            bottom: 10,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 1.2,
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({
    required this.onImport,
    required this.isSearch,
    required this.isDark,
  });
  final VoidCallback onImport;
  final bool isSearch;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final textColor =
        isDark ? const Color(0xFFEFE0C7) : const Color(0xFF3A2614);
    final subColor = isDark ? const Color(0xFFB09878) : const Color(0xFF6B4A27);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: (isDark
                    ? const Color(0xFF2C2018)
                    : Colors.white)
                .withOpacity(0.92),
            borderRadius: BorderRadius.circular(AppRadius.xl),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [Color(0xFF4A3728), Color(0xFF2A1F18)]
                        : const [Color(0xFFAF8A59), Color(0xFF8B6239)],
                  ),
                  borderRadius: BorderRadius.circular(60),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(
                  isSearch ? Icons.search_off : Icons.menu_book_rounded,
                  size: 52,
                  color: isDark
                      ? const Color(0xFFE0C097)
                      : const Color(0xFFF5E6CC),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                isSearch ? '未找到相关书籍' : '书架空空如也',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                isSearch
                    ? '尝试使用其他关键字'
                    : '导入 EPUB / PDF / TXT 文件开启阅读之旅',
                style: TextStyle(color: subColor, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              if (!isSearch) ...[
                const SizedBox(height: AppSpacing.lg),
                FilledButton.icon(
                  onPressed: onImport,
                  style: FilledButton.styleFrom(
                    backgroundColor: isDark
                        ? const Color(0xFFB8860B)
                        : const Color(0xFF8B4513),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.md,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('导入书籍', style: TextStyle(fontSize: 15)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
