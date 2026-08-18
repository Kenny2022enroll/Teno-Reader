// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/reader/presentation/pages/reader_page.dart';
import '../features/shelf/presentation/pages/shelf_page.dart';
import '../features/settings/presentation/pages/settings_page.dart';
import '../core/theme/app_theme.dart';

final _router = GoRouter(
  initialLocation: '/shelf',
  routes: [
    GoRoute(
      path: '/shelf',
      name: 'shelf',
      pageBuilder: (_, state) => NoTransitionPage(child: const ShelfPage()),
    ),
    GoRoute(
      path: '/reader/:bookId',
      name: 'reader',
      pageBuilder: (_, state) {
        final bookId = state.pathParameters['bookId']!;
        return CustomTransitionPage(
          key: state.pageKey,
          child: ReaderPage(bookId: bookId),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.04),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
                child: child,
              ),
            );
          },
        );
      },
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      pageBuilder: (_, state) => NoTransitionPage(child: const SettingsPage()),
    ),
  ],
);

class LumenApp extends ConsumerWidget {
  const LumenApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = ref.watch(appThemeProvider);

    return MaterialApp.router(
      title: 'Lumen Reader',
      debugShowCheckedModeBanner: false,
      theme: theme.lightTheme,
      darkTheme: theme.darkTheme,
      themeMode: theme.mode,
      routerConfig: _router,
      // HIG-style scroll behaviors on all platforms
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        scrollbars: false,
      ),
      builder: (context, child) {
        // Honour the OS-level text scaler (accessibility / Dynamic Type).
        // The previous implementation hard-coded TextScaler.noScaling, which
        // silently disabled platform text scaling even though the README
        // advertises "dynamic type / large text" support. Removing that
        // override lets users with vision needs actually scale the UI.
        return child ?? const SizedBox.shrink();
      },
    );
  }
}
