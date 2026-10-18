import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';

import 'config.dart';
import 'core/locale.dart';
import 'l10n/app_localizations.dart';
import 'router.dart';

class JiraniApp extends ConsumerWidget {
  const JiraniApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final locale = ref.watch(localeProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appName,
      debugShowCheckedModeBanner: false,
      theme: JiraniTheme.light(),
      darkTheme: JiraniTheme.dark(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: router,
      builder: (context, child) => AppConfig.isProduction
          ? child!
          : Banner(
              message: AppConfig.flavor.toUpperCase(),
              location: BannerLocation.topEnd,
              child: child!,
            ),
    );
  }
}
