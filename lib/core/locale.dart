import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'prefs.dart';

/// The language the member picked. Null follows the phone's language. Remembered on this
/// phone, so the app opens in it next time, even before signing in.
class LocaleController extends Notifier<Locale?> {
  static const _key = 'language';

  @override
  Locale? build() {
    _load();
    return null;
  }

  Future<void> _load() async {
    final code = await ref.read(prefsStoreProvider).read(_key);
    if (code != null && code.isNotEmpty && state == null) state = Locale(code);
  }

  void set(Locale locale) {
    state = locale;
    ref.read(prefsStoreProvider).write(_key, locale.languageCode);
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale?>(LocaleController.new);

/// The country chosen at sign-up (Kenya, Uganda or Tanzania for now). It decides how a
/// local phone number is read and is saved on the person's profile.
class CountryController extends Notifier<String> {
  @override
  String build() => 'KE';

  void set(String code) => state = code;
}

final countryProvider = NotifierProvider<CountryController, String>(CountryController.new);
