import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';

import 'config.dart';
import 'core/locale.dart';
import 'core/prefs.dart';
import 'l10n/app_localizations.dart';
import 'router.dart';

class JiraniApp extends ConsumerWidget {
  const JiraniApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    final a11y = ref.watch(a11yProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: JiraniTheme.light(highContrast: a11y.highContrast,
          largeTargets: a11y.largeTargets),
      darkTheme: JiraniTheme.dark(highContrast: a11y.highContrast,
          largeTargets: a11y.largeTargets),
      themeMode: a11y.themeMode,
      themeAnimationDuration: a11y.reduceMotion ? Duration.zero
          : const Duration(milliseconds: 200),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      // "Easy to read" applies to every screen: text size, bold, contrast, motion.
      builder: (context, child) => MediaQuery(
        data: a11y.apply(MediaQuery.of(context)),
        child: AppConfig.isProduction
            ? child!
            : Banner(
                message: AppConfig.flavor.toUpperCase(),
                location: BannerLocation.topEnd,
                child: child!,
              ),
      ),
    );
  }
}
