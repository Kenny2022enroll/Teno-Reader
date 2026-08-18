import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/webdav/webdav_models.dart';
import '../../../../core/webdav/webdav_service.dart';
import '../../../reader/domain/entities/reading_entities.dart';
import '../../../reader/infrastructure/book_repository.dart';
import '../../../reader/presentation/pages/reader_page.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _urlController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _rootFolderController = TextEditingController(text: '/LumenReader');

  bool _obscurePassword = true;
  bool _webdavExpanded = false;
  bool _autoSync = true;

  @override
  void initState() {
    super.initState();
    _loadWebDAVSettings();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _rootFolderController.dispose();
    super.dispose();
  }

  Future<void> _loadWebDAVSettings() async {
    final storage = ref.read(storageServiceProvider);
    final s = await storage.loadWebDAVSettings();
    if (s != null) {
      _urlController.text = s.url;
      _usernameController.text = s.username;
      _passwordController.text = s.password;
      _rootFolderController.text = s.rootFolder;
      _autoSync = s.autoSync;
    }
    if (mounted) {
      setState(() {});
    }
  }

  WebDAVSettings _currentSettings() => WebDAVSettings(
        url: _urlController.text.trim(),
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        rootFolder: _rootFolderController.text.trim().isEmpty
            ? '/LumenReader'
            : _rootFolderController.text.trim(),
        autoSync: _autoSync,
      );

  void _showSnack(String message, {bool success = true}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success
            ? Theme.of(context).colorScheme.primary.withOpacity(0.85)
            : Theme.of(context).colorScheme.error.withOpacity(0.85),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _testConnection() async {
    final s = _currentSettings();
    if (!s.isConfigured) {
      _showSnack('请先填写服务器地址、用户名和密码', success: false);
      return;
    }
    final service = WebDAVService(Dio(), s);
    final result = await service.testConnection();
    if (result.ok) {
      _showSnack('连接成功');
    } else {
      _showSnack('连接失败: ${result.message}', success: false);
    }
  }

  Future<void> _saveSettings() async {
    final s = _currentSettings();
    final storage = ref.read(storageServiceProvider);
    await storage.saveWebDAVSettings(s);
    _showSnack('已保存 WebDAV 设置');
  }

  Future<void> _syncNow() async {
    final s = _currentSettings();
    if (!s.isConfigured) {
      _showSnack('请先配置 WebDAV 并保存', success: false);
      return;
    }
    final storage = ref.read(storageServiceProvider);
    final service = WebDAVService(Dio(), s);

    final progresses = storage.progress.values.toList();
    final highlights = storage.highlights.values.toList();
    final bookmarks = storage.bookmarks.values.toList();

    final uploadResult = await service.upload(
      progresses: progresses,
      highlights: highlights,
      bookmarks: bookmarks,
    );
    if (!uploadResult.ok) {
      _showSnack('上传失败: ${uploadResult.message}', success: false);
      return;
    }

    final downloadResult = await service.download(
      onProgress: (list) async {
        for (final p in list) {
          await storage.progress.put(p.bookId, p);
        }
      },
      onHighlights: (list) async {
        for (final h in list) {
          await storage.highlights.put(h.id, h);
        }
      },
      onBookmarks: (list) async {
        for (final b in list) {
          await storage.bookmarks.put(b.id, b);
        }
      },
    );

    if (downloadResult.ok) {
      _showSnack(
        '同步完成：已上传 ${uploadResult.uploaded ?? 0} / 已下载 ${downloadResult.downloaded ?? 0}',
      );
    } else {
      _showSnack('下载失败: ${downloadResult.message}', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                title: 'WebDAV 同步',
                children: [
                  ListTile(
                    leading: const Icon(Icons.folder_special_outlined),
                    title: const Text('WebDAV 同步'),
                    subtitle: const Text('通过 WebDAV 备份进度、笔记、书签'),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch.adaptive(
                          value: _autoSync,
                          onChanged: (v) {
                            setState(() => _autoSync = v);
                          },
                        ),
                        IconButton(
                          icon: Icon(
                            _webdavExpanded
                                ? Icons.expand_less
                                : Icons.expand_more,
                          ),
                          onPressed: () {
                            setState(() => _webdavExpanded = !_webdavExpanded);
                          },
                        ),
                      ],
                    ),
                  ),
                  if (_webdavExpanded) ...[
                    Divider(
                      height: 0,
                      indent: 16,
                      endIndent: 16,
                      color: Theme.of(context).dividerColor,
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.sm,
                      ),
                      child: TextField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          labelText: '服务器 URL',
                          hintText:
                              'https://dav.example.com/remote.php/dav/files/user',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.link_outlined),
                        ),
                        keyboardType: TextInputType.url,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      child: TextField(
                        controller: _usernameController,
                        decoration: const InputDecoration(
                          labelText: '用户名',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.xs,
                      ),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          labelText: '密码',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.xs,
                        AppSpacing.md,
                        AppSpacing.md,
                      ),
                      child: TextField(
                        controller: _rootFolderController,
                        decoration: const InputDecoration(
                          labelText: '根目录',
                          hintText: '/LumenReader',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.folder_outlined),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        0,
                        AppSpacing.md,
                        AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _testConnection,
                              icon: const Icon(Icons.network_check_outlined),
                              label: const Text('测试连接'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _saveSettings,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('保存'),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _syncNow,
                              icon: const Icon(Icons.sync_outlined),
                              label: const Text('立即同步'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              const _Section(
                title: '关于',
                children: [
                  ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('Lumen Reader'),
                    subtitle: Text('v1.0.0-rc.1 · 跨平台阅读'),
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
                if (i != children.length - 1 &&
                    !(children[i] is SwitchListTile &&
                        children[i + 1] is Padding))
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
