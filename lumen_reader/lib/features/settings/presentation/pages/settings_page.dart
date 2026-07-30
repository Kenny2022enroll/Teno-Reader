import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../reader/domain/entities/reading_entities.dart';
import '../../../reader/infrastructure/book_repository.dart';
import '../../../reader/presentation/pages/reader_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settingsAsync = ref.watch(readerSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.pop(),
        ),
        title: const Text('设置'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: settingsAsync.when(
          data: (s) => ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            children: [
              _Section(
                title: '外观',
                children: [
                  _ListTile(
                    leading: const Icon(Icons.wb_sunny_outlined),
                    title: '主题',
                    subtitle: _themeLabel(s.theme),
                    trailing: _ThemeSelector(
                      value: s.theme,
                      onChanged: (v) => _save(s.copyWith(theme: v)),
                    ),
                  ),
                  _ListTile(
                    leading: const Icon(Icons.animation),
                    title: '页面过渡动效',
                    subtitle: s.pageTurnStyle == 'slide'
                        ? '滑动'
                        : s.pageTurnStyle == 'curl'
                            ? '翻页'
                            : '无',
                    trailing: DropdownButton<String>(
                      value: s.pageTurnStyle,
                      items: const [
                        DropdownMenuItem(value: 'slide', child: Text('滑动')),
                        DropdownMenuItem(value: 'curl', child: Text('翻页')),
                        DropdownMenuItem(value: 'none', child: Text('无')),
                      ],
                      onChanged: (v) {
                        if (v != null) _save(s.copyWith(pageTurnStyle: v));
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _Section(
                title: '阅读体验',
                children: [
                  _ListTile(
                    leading: const Icon(Icons.font_download_outlined),
                    title: '字体',
                    subtitle: s.fontFamily,
                    trailing: DropdownButton<String>(
                      value: s.fontFamily,
                      items: const [
                        DropdownMenuItem(
                          value: 'SF Pro Text',
                          child: Text('系统默认'),
                        ),
                        DropdownMenuItem(
                          value: 'Charter',
                          child: Text('Charter (衬线)'),
                        ),
                        DropdownMenuItem(
                          value: 'Georgia',
                          child: Text('Georgia'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) _save(s.copyWith(fontFamily: v));
                      },
                    ),
                  ),
                  SwitchListTile.adaptive(
                    value: s.autoNightMode,
                    onChanged: (v) => _save(s.copyWith(autoNightMode: v)),
                    secondary: const Icon(Icons.nightlight_round),
                    title: const Text('跟随系统深浅色'),
                  ),
                  SwitchListTile.adaptive(
                    value: s.keepScreenAwake,
                    onChanged: (v) => _save(s.copyWith(keepScreenAwake: v)),
                    secondary: const Icon(Icons.screen_lock_landscape),
                    title: const Text('保持屏幕常亮'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _Section(
                title: '无障碍',
                children: [
                  SwitchListTile.adaptive(
                    value: s.largeText,
                    onChanged: (v) => _save(s.copyWith(largeText: v)),
                    secondary: const Icon(Icons.text_fields),
                    title: const Text('大号文字'),
                  ),
                  SwitchListTile.adaptive(
                    value: s.reducedMotion,
                    onChanged: (v) => _save(s.copyWith(reducedMotion: v)),
                    secondary: const Icon(Icons.motion_photos_off_outlined),
                    title: const Text('减弱动态效果'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _Section(
                title: '同步与隐私',
                children: [
                  SwitchListTile.adaptive(
                    value: s.syncEnabled,
                    onChanged: (v) async {
                      final ns = s.copyWith(syncEnabled: v);
                      await _save(ns);
                      if (v) {
                        // ignore: use_build_context_synchronously
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('端到端加密同步已启用')),
                        );
                      }
                    },
                    secondary: const Icon(Icons.cloud_outlined),
                    title: const Text('启用云同步'),
                    subtitle: const Text('本地数据 AES-256 加密后上传'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.privacy_tip_outlined),
                    title: const Text('关于隐私保护'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showPrivacy,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _Section(
                title: '关于',
                children: [
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: const Text('Lumen Reader'),
                    subtitle: const Text('v1.0.0 · 跨平台阅读'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxxl),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('加载失败: $e')),
        ),
      ),
    );
  }

  String _themeLabel(String theme) {
    switch (theme) {
      case 'dark':
        return '深色';
      case 'sepia':
        return '护眼';
      case 'paper':
        return '纸张';
      default:
        return '浅色';
    }
  }

  Future<void> _save(SettingsPayload s) async {
    final repo = ref.read(bookRepositoryProvider);
    await repo.saveSettings(s);
    ref.invalidate(readerSettingsProvider);
  }

  void _showPrivacy() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('隐私承诺'),
        content: const Text(
          '1. 所有阅读数据默认仅存本地。\n'
          '2. 云同步使用 AES-256-CBC 端到端加密。\n'
          '3. 服务器无法读取您的书籍正文、高亮或笔记。\n'
          '4. 可随时一键清除所有本地与云端数据。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('好'),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            0,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelMedium!.copyWith(
              color: theme.colorScheme.primary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  Divider(
                    height: 0,
                    indent: 16,
                    endIndent: 16,
                    color: theme.dividerColor,
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ListTile extends StatelessWidget {
  const _ListTile({
    required this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'light', label: Text('日')),
        ButtonSegment(value: 'dark', label: Text('夜')),
        ButtonSegment(value: 'sepia', label: Text('护')),
        ButtonSegment(value: 'paper', label: Text('纸')),
      ],
      selected: {value},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
