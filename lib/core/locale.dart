import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The language the member picked. Null follows the phone's language.
class LocaleController extends Notifier<Locale?> {
  @override
  Locale? build() => null;

  void set(Locale locale) => state = locale;
}

final localeProvider = NotifierProvider<LocaleController, Locale?>(LocaleController.new);
