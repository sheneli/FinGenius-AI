import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'config/session_providers.dart';
import 'routing/router.dart';
import 'theme/theme.dart';

/// Root widget. Theme follows the signed-in user's preference (dark default).
class FinGeniusApp extends ConsumerWidget {
  const FinGeniusApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final themeMode = switch (profile?.prefs.theme) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };

    return MaterialApp.router(
      title: 'FinGenius AI',
      debugShowCheckedModeBanner: false,
      theme: FgTheme.light(),
      darkTheme: FgTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      builder: (context, child) {
        // Cap text scaling at 2.0 — layouts are tested to 200%.
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(
            textScaler: media.textScaler.clamp(maxScaleFactor: 2.0),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
