import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../reader/domain/entities/book_entity.dart';
import '../../../reader/domain/entities/reading_entities.dart';
import '../../../reader/infrastructure/book_repository.dart';
import '../../../reader/infrastructure/progress_repository.dart';

final shelfBooksProvider = FutureProvider<List<BookEntity>>((ref) async {
  final repo = ref.watch(bookRepositoryProvider);
  return repo.fetchAllBooks();
});

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

  /// Wooden bookshelf layered background (simulated wood grain via gradients).
  BoxDecoration _buildShelfBackground(bool isDark) {
    if (isDark) {
      // Dark walnut
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
    // Light oak wood grain
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
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: (isDark ? const Color(0xFF14100C) : const Color(0xFFAF8A59))
            .withOpacity(0.55),
        border: Border(
          bottom: BorderSide(
            color: (isDark ? Colors.black26 : Colors.brown.withOpacity(0.35)),
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
                color:
                    (isDark ? const Color(0xFF2C2018) : const Color(0xFF8B6239))
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
                color:
                    (isDark ? const Color(0xFF2C2018) : const Color(0xFF8B6239))
                        .withOpacity(0.9),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                Icons.settings_outlined,
                color: isDark
                    ? const Color(0xFFE0C097)
                    : const Color(0xFFF5E6CC),
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
    final hintColor = isDark
        ? const Color(0xFFA08568)
        : const Color(0xFF5C3E22);
    final textColor = isDark
        ? const Color(0xFFEFE0C7)
        : const Color(0xFF3F2A18);

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
        return _BookShelfGrid(books: filtered, isDark: isDark);
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
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('导入失败: ${f.name} — $e')));
          }
        }
      }
    }
    if (added > 0 && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('成功导入 $added 本书')));
    }
    ref.invalidate(shelfBooksProvider);
  }
}

// ===========================================================================
// SKEUOMORPHIC BOOK SHELF GRID — each row sits on a wooden shelf plank
// ===========================================================================
class _BookShelfGrid extends ConsumerWidget {
  const _BookShelfGrid({required this.books, required this.isDark});
  final List<BookEntity> books;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Figure out how many columns the SliverGridDelegateWithMaxCrossAxisExtent
    // will produce given maxCrossAxisExtent = 160.
    return LayoutBuilder(
      builder: (context, constraints) {
        const maxExtent = 160.0;
        const spacing = AppSpacing.md;
        final crossAxisCount =
            ((constraints.maxWidth + spacing) / (maxExtent + spacing)).floor();
        final cols = crossAxisCount < 2 ? 2 : crossAxisCount;

        // Build rows of shelf planks
        final rows = (books.length / cols).ceil();
        final List<Widget> children = [];

        for (int r = 0; r < rows; r++) {
          final start = r * cols;
          final end = (start + cols).clamp(0, books.length);

          // Book row with shelf plank under it
          children.add(
            _ShelfPlankRow(
              isDark: isDark,
              rowIndex: r,
              books: books.sublist(start, end),
              cols: cols,
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
  });
  final bool isDark;
  final int rowIndex;
  final List<BookEntity> books;
  final int cols;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The row of books — the cover+reflection combo is laid out so
          // book covers visually rest on the shelf plank below.
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
                        ? _BookCard(book: book, isDark: isDark)
                        : const SizedBox.shrink(),
                  ),
                );
              }),
            ),
          ),
          // The shelf plank visually positioned so the book covers
          // appear to rest on top of it.
          Transform.translate(
            offset: const Offset(0, -6),
            child: _ShelfPlank(isDark: isDark),
          ),
        ],
      ),
    );
  }
}

/// A single wooden shelf plank with thickness and top highlights / shadows.
class _ShelfPlank extends StatelessWidget {
  const _ShelfPlank({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.vertical(
          top: Radius.zero,
          bottom: Radius.circular(AppRadius.sm),
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [
                  Color(0xFF4A3728), // top highlight (facing light)
                  Color(0xFF2E2117), // plank body
                  Color(0xFF1F160F), // plank shadow side
                  Color(0xFF140E09), // plank bottom
                ]
              : const [
                  Color(0xFF8B6239), // top light
                  Color(0xFF6B4A27), // main plank
                  Color(0xFF563A1E), // darker
                  Color(0xFF3F2A14), // bottom
                ],
          stops: const [0.0, 0.25, 0.7, 1.0],
        ),
        boxShadow: [
          // Top lip catch-light
          const BoxShadow(
            color: Colors.black38,
            blurRadius: 6,
            offset: Offset(0, -3), // shadow cast ON the back wall by books
          ),
          // Plank drop shadow to next row
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
      // Wood grain lines on plank face
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
      final color = (isDark ? const Color(0xFF1A120B) : const Color(0xFF5C3E22))
          .withOpacity(0.2 + rng.nextDouble() * 0.25);
      paint.color = color;
      final path = Path()..moveTo(0, y);
      // Wavy horizontal grain line
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
// SKEUOMORPHIC BOOK CARD — with spine, page edges, shadows & reflection
// ===========================================================================
class _BookCard extends ConsumerStatefulWidget {
  const _BookCard({required this.book, required this.isDark});
  final BookEntity book;
  final bool isDark;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 0.68,
                  child: _SkeuomorphicBookCover(
                    book: widget.book,
                    isDark: widget.isDark,
                  ),
                ),
                // Reflection area (below book, above shelf plank) —
                // bounded to 30% of cover height.
                SizedBox(
                  height: 48,
                  child: _CoverReflection(
                    book: widget.book,
                    isDark: widget.isDark,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                // Book metadata below the reflection
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
                progressAsync.when(
                  data: (p) => Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: p?.progress ?? 0,
                        minHeight: 3,
                        backgroundColor: widget.isDark
                            ? const Color(0xFF3A2A1C)
                            : const Color(0xFF8B6239).withOpacity(0.35),
                        valueColor: AlwaysStoppedAnimation(
                          widget.isDark
                              ? const Color(0xFFE8B86A)
                              : const Color(0xFFB35A1F),
                        ),
                      ),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
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
                // ignore: use_build_context_synchronously
                Navigator.pop(sheetContext);
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
                // ignore: use_build_context_synchronously
                Navigator.pop(sheetContext);
              },
            ),
          ],
        ),
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

/// A book cover rendered with book-binding realism:
///   - spine (left darker strip with subtle vertical grain)
///   - page edge (right off-white strip with horizontal page lines)
///   - multiple shadows (close shadow + far soft shadow)
///   - inner border highlight (bevel)
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
          // Background cover image / fallback
          Positioned.fill(
            left: 8, // leave room for spine
            right: 5, // leave room for page edge
            child: _CoverImageContent(book: book),
          ),
          // Book spine overlay (left binding)
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 9,
            child: _BookSpine(isDark: isDark, book: book),
          ),
          // Page edge overlay (right)
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 6,
            child: _BookPageEdge(isDark: isDark),
          ),
          // Cover bevel / highlight (inner border)
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
          // 1. Far, soft ambient shadow
          BoxShadow(
            color: Colors.black.withOpacity(0.35),
            blurRadius: 14,
            spreadRadius: 1,
            offset: const Offset(0, 8),
          ),
          // 2. Tight contact shadow underneath
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 3,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
          // 3. Inner-right side shade (so book doesn't look flat)
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

/// Left book-binding spine: darker gradient with a few vertical lines.
class _BookSpine extends StatelessWidget {
  const _BookSpine({required this.isDark, required this.book});
  final bool isDark;
  final BookEntity book;

  @override
  Widget build(BuildContext context) {
    // Pick a "bookbinding cloth" color based on title hash
    final colorSeed =
        book.title.codeUnits.fold<int>(0, (a, b) => a + b) +
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
    final spineLight = Color.lerp(spineDark, Colors.brown.shade200, 0.25)!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            spineDark,
            spineDark,
            Color.lerp(spineDark, spineLight, 0.2)!,
            Color.lerp(spineDark, spineLight, 0.5)!,
          ],
          stops: const [0.0, 0.4, 0.75, 1.0],
        ),
        borderRadius: const BorderRadius.horizontal(left: Radius.circular(4)),
      ),
      // Add subtle grain lines on the spine
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

    // Vertical grooves along the spine
    for (int i = 0; i < 3; i++) {
      final x = 1.5 + (i * (size.width - 3) / 3);
      paint.color = Colors.black.withOpacity(0.55);
      canvas.drawLine(Offset(x, 2), Offset(x, size.height - 2), paint);
      paint.color = Colors.white.withOpacity(0.06);
      canvas.drawLine(
        Offset(x + 0.5, 2),
        Offset(x + 0.5, size.height - 2),
        paint,
      );
    }

    // Random tiny speckles
    final speck = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < 12; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      speck.color =
          (rng.nextBool()
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

/// Right-side book page edge: off-white with subtle horizontal lines.
class _BookPageEdge extends StatelessWidget {
  const _BookPageEdge({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            // paper transition from cover side
            const Color(0xFFF5EEDD),
            const Color(0xFFF8F2E0),
            const Color(0xFFFBF5E5),
            // outermost: catches the light brighter
            const Color(0xFFFFFAF0),
            // subtle shadow at the very edge
            const Color(0xFFEDE3CB),
          ],
          stops: const [0.0, 0.3, 0.65, 0.85, 1.0],
        ),
        borderRadius: const BorderRadius.horizontal(
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
    // Draw horizontal page lines to simulate stacked pages
    for (double y = 3; y < size.height - 2; y += 1.8) {
      // slight left-to-right fade on lines for realism
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

/// A reflection of the book cover rendered beneath it.
class _CoverReflection extends StatelessWidget {
  const _CoverReflection({required this.book, required this.isDark});
  final BookEntity book;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    // Reflection is ~30% of cover height, faded from top to transparent.
    return Opacity(
      opacity: 0.5,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (bounds) => const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black, Colors.transparent],
          stops: [0.0, 0.8],
        ).createShader(bounds),
        child: Transform(
          alignment: Alignment.topCenter,
          transform: Matrix4.identity()
            ..scale(1.0, -0.4) // flip vertically + squash
            ..translate(0.0, -1.25),
          // A clipped, simplified cover — we only need the cover image shape
          // + spine/page edge colors for a convincing reflection.
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
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [
                          const Color(0xFF2A1A0E),
                          const Color(0xFF5A3A22),
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
    final seed =
        book.title.codeUnits.fold<int>(0, (a, b) => a + b) +
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
          // Subtle leather-sheen highlight
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
          // Title
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
          // Subtle embossed frame
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
    final textColor = isDark
        ? const Color(0xFFEFE0C7)
        : const Color(0xFF3A2614);
    final subColor = isDark ? const Color(0xFFB09878) : const Color(0xFF6B4A27);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: (isDark ? const Color(0xFF2C2018) : Colors.white)
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
                isSearch ? '尝试使用其他关键字' : '导入 EPUB / PDF / TXT 文件开启阅读之旅',
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
