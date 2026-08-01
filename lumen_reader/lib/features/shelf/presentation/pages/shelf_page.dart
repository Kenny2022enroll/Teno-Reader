import 'dart:io';

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

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md),
          child: Icon(
            Icons.menu_book_rounded,
            color: theme.colorScheme.primary,
            size: 26,
          ),
        ),
        title: const Text('书架'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded),
            tooltip: '导入书籍',
            onPressed: _import,
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '设置',
            onPressed: () => context.go('/settings'),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(theme),
            Expanded(child: _buildContent(theme)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: TextField(
          controller: _searchCtrl,
          decoration: InputDecoration(
            border: InputBorder.none,
            prefixIcon: Icon(Icons.search, color: theme.hintColor, size: 20),
            hintText: '搜索书架',
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
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
          return _EmptyShelf(onImport: _import, isSearch: _query.isNotEmpty);
        }
        return _BookGrid(books: filtered);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('加载失败: $e')),
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
    for (final f in result.files) {
      if (f.path != null) {
        try {
          await repo.addBookFromFile(filePath: f.path!);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('导入失败: ${f.name} — $e')));
          }
        }
      }
    }
    ref.invalidate(shelfBooksProvider);
  }
}

class _BookGrid extends ConsumerWidget {
  const _BookGrid({required this.books});
  final List<BookEntity> books;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      // crossAxisSpacing is 0 so the wooden shelves connect across each row;
      // horizontal padding inside each cell provides book-to-book spacing.
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 175,
        mainAxisSpacing: AppSpacing.xl,
        crossAxisSpacing: 0,
        childAspectRatio: 0.5,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: _BookCard(book: books[index]),
        );
      },
    );
  }
}

class _BookCard extends ConsumerStatefulWidget {
  const _BookCard({required this.book});
  final BookEntity book;

  @override
  ConsumerState<_BookCard> createState() => _BookCardState();
}

class _BookCardState extends ConsumerState<_BookCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progressAsync = ref.watch(progressProvider(widget.book.id));

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.95 : 1.0,
        duration: AppMotion.fast,
        curve: AppMotion.curve,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => context.push('/reader/${widget.book.id}'),
            onLongPress: () => _showMenu(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 3D cover + reflection, sitting on the shelf below.
                Expanded(
                  child: _SkeuomorphicBook(
                    book: widget.book,
                    pressed: _pressed,
                  ),
                ),
                _WoodenShelf(brightness: theme.brightness),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelLarge,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        widget.book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      progressAsync.when(
                        data: (p) => ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: p?.progress ?? 0,
                            minHeight: 2.5,
                            backgroundColor:
                                theme.colorScheme.surfaceContainerHighest,
                            valueColor: AlwaysStoppedAnimation(
                              theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
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

/// A single skeuomorphic book: a 3D cover with spine shadow, page-edge
/// highlight, and a faded reflection beneath it.
class _SkeuomorphicBook extends StatelessWidget {
  const _SkeuomorphicBook({required this.book, required this.pressed});
  final BookEntity book;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = c.maxWidth;
        final coverH = c.maxHeight * 0.74;
        final reflectH = c.maxHeight - coverH;

        return SizedBox(
          width: width,
          height: c.maxHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Reflection — rendered first so the cover's drop shadow can
              // sit on top of it.
              Positioned(
                left: 0,
                top: coverH,
                width: width,
                height: reflectH,
                child: _CoverReflection(
                  book: book,
                  coverHeight: coverH,
                  width: width,
                ),
              ),
              // The 3D cover.
              Positioned(
                left: 0,
                top: 0,
                width: width,
                height: coverH,
                child: _Cover3D(book: book, pressed: pressed),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Book cover with a perspective Y-rotation, spine gradient, page-edge
/// highlight, top sheen, and a drop shadow.
class _Cover3D extends StatelessWidget {
  const _Cover3D({required this.book, required this.pressed});
  final BookEntity book;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0018) // perspective
        ..rotateY(pressed ? -0.28 : -0.14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.38),
              blurRadius: 14,
              offset: const Offset(6, 9),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 4,
              offset: const Offset(2, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _CoverImage(book: book),
              // Spine shadow on the left edge — simulates the curved binding.
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                width: 16,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.black.withOpacity(0.5),
                        Colors.black.withOpacity(0.18),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
              ),
              // Page-edge highlight on the right — the exposed paper stack.
              Positioned(
                right: 0,
                top: 2,
                bottom: 2,
                width: 3,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(0.2),
                        Colors.white.withOpacity(0.4),
                      ],
                    ),
                  ),
                ),
              ),
              // Top sheen for a glossy laminate look.
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 44,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.14),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Faded, vertically-flipped reflection of the cover. Uses [OverflowBox] so
/// the reflection shows the cover's bottom edge (not a rescaled copy), and a
/// [ShaderMask] to fade it into the surface below.
class _CoverReflection extends StatelessWidget {
  const _CoverReflection({
    required this.book,
    required this.coverHeight,
    required this.width,
  });
  final BookEntity book;
  final double coverHeight;
  final double width;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.4),
            Colors.white.withOpacity(0.1),
            Colors.transparent,
          ],
          stops: const [0.0, 0.55, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: ClipRect(
        child: OverflowBox(
          maxHeight: coverHeight,
          maxWidth: width,
          alignment: Alignment.topCenter,
          child: Transform(
            alignment: Alignment.topCenter,
            transform: Matrix4.identity()..scaleY(-1),
            child: SizedBox(
              width: width,
              height: coverHeight,
              child: _CoverImage(book: book),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.book});
  final BookEntity book;

  @override
  Widget build(BuildContext context) {
    if (book.coverPath != null) {
      return Image.file(
        File(book.coverPath!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _FallbackCover(book: book),
      );
    }
    return _FallbackCover(book: book);
  }
}

class _FallbackCover extends StatelessWidget {
  const _FallbackCover({required this.book});
  final BookEntity book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      AppPalette.lightPurple,
      AppPalette.lightTeal,
      AppPalette.lightOrange,
    ];
    final color =
        colors[book.title.codeUnits.fold(0, (a, b) => a + b) % colors.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.92),
            Color.lerp(color, Colors.black, 0.4)!,
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Text(
            book.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 15,
              height: 1.2,
              shadows: [
                Shadow(
                  color: Colors.black54,
                  blurRadius: 4,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A wooden shelf plank: a horizontal gradient bar with a top highlight and
/// a cast shadow below. Rendered per-cell with crossAxisSpacing = 0 so
/// adjacent planks form a continuous shelf across the row.
class _WoodenShelf extends StatelessWidget {
  const _WoodenShelf({required this.brightness});
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;
    final colors = isDark
        ? const [Color(0xFF5A3D2A), Color(0xFF3E2723), Color(0xFF2A1A15)]
        : const [Color(0xFFB5835A), Color(0xFF8B5A2B), Color(0xFF6B3410)];

    return Container(
      height: 10,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(isDark ? 0.1 : 0.3),
            width: 0.5,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.32),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
    );
  }
}

class _EmptyShelf extends StatelessWidget {
  const _EmptyShelf({required this.onImport, required this.isSearch});
  final VoidCallback onImport;
  final bool isSearch;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(60),
              ),
              child: Icon(
                isSearch ? Icons.search_off : Icons.menu_book_rounded,
                size: 52,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              isSearch ? '未找到相关书籍' : '书架空空如也',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isSearch ? '尝试使用其他关键字' : '导入 EPUB / PDF / TXT 文件开启阅读之旅',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (!isSearch) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton.icon(
                onPressed: onImport,
                icon: const Icon(Icons.add),
                label: const Text('导入书籍'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
