import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The language the member picked. Null follows the phone's language.
class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() => null;

  void set(Locale locale) => state = locale;
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
