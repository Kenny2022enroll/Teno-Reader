import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_theme.dart';
import '../../reader/domain/entities/book_entity.dart';
import '../../reader/infrastructure/book_repository.dart';

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
    _searchCtrl = TextEditingController()..addListener(() {
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
        AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm,
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
          return _EmptyShelf(
            onImport: _import,
            isSearch: _query.isNotEmpty,
          );
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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('导入失败: ${f.name} — $e')),
            );
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
        AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.xl,
      ),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 160,
        mainAxisSpacing: AppSpacing.lg,
        crossAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.68,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return _BookCard(book: book);
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
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.curve,
        transform: Matrix4.identity()..scale(_pressed ? 0.96 : 1.0),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.md),
            onTap: () => context.push('/reader/${widget.book.id}'),
            onLongPress: () => _showMenu(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    child: _CoverImage(book: widget.book),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  widget.book.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  widget.book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall,
                ),
                progressAsync.when(
                  data: (p) => Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: p?.progress ?? 0,
                        minHeight: 3,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
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
                await repo.pinBook(widget.book.id, pinned: !widget.book.isPinned);
                ref.invalidate(shelfBooksProvider);
                // ignore: use_build_context_synchronously
                Navigator.pop(sheetContext);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppPalette.lightRed),
              title: const Text('从书架移除', style: TextStyle(color: AppPalette.lightRed)),
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

final progressProvider = FutureProvider.family<ReadingProgress?, String>(
  (ref, bookId) {
    final repo = ref.watch(progressRepositoryProvider);
    return repo.fetchProgress(bookId);
  },
);

class _CoverImage extends StatelessWidget {
  const _CoverImage({required this.book});
  final BookEntity book;

  @override
  Widget build(BuildContext context) {
    if (book.coverPath != null) {
      return Image.network(book.coverPath!, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
        return _FallbackCover(book: book);
      });
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
      theme.colorScheme.primary.withOpacity(0.85),
      theme.colorScheme.secondary.withOpacity(0.85),
      AppPalette.lightPurple.withOpacity(0.85),
      AppPalette.lightTeal.withOpacity(0.85),
      AppPalette.lightOrange.withOpacity(0.85),
    ];
    final color = colors[book.title.codeUnits.fold(0, (a, b) => a + b) % colors.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.9), color.withOpacity(0.55)],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Text(
            book.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 18,
              height: 1.2,
            ),
          ),
        ),
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
