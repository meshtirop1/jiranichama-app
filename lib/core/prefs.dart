import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Small settings kept on this phone (how the app looks, the language). Nothing here is
/// secret, but the phone's secure storage is the one store the app already has.
abstract class PrefsStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}

class SecurePrefsStore implements PrefsStore {
  static const _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: 'pref_$key');
    } catch (_) {
      return null; // no storage (widget tests, a locked keystore): use the defaults
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: 'pref_$key', value: value);
    } catch (_) {
      // Not saved: the setting still applies until the app closes.
    }
  }
}

class MemoryPrefsStore implements PrefsStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

final prefsStoreProvider = Provider<PrefsStore>((ref) => SecurePrefsStore());

/// "Easy to read": for older members and anyone who does not see well. Every choice
/// applies to the whole app at once and is remembered on this phone.
@immutable
class A11ySettings {
  const A11ySettings({
    this.textScale = 1,
    this.bold = false,
    this.highContrast = false,
    this.largeTargets = false,
    this.reduceMotion = false,
    this.themeMode = ThemeMode.system,
  });

  /// 1 = normal. The steps offered run from 0.9 to 2.
  final double textScale;
  final bool bold;
  final bool highContrast;

  /// Taller buttons and rows, easier to hit.
  final bool largeTargets;

  /// No sliding or bouncing; the loading sign turns slowly.
  final bool reduceMotion;
  final ThemeMode themeMode;

  static const textSteps = [0.9, 1.0, 1.15, 1.3, 1.5, 1.75, 2.0];

  bool get isDefault =>
      textScale == 1 && !bold && !highContrast && !largeTargets && !reduceMotion &&
      themeMode == ThemeMode.system;

  A11ySettings copyWith({double? textScale, bool? bold, bool? highContrast,
          bool? largeTargets, bool? reduceMotion, ThemeMode? themeMode}) =>
      A11ySettings(
        textScale: textScale ?? this.textScale,
        bold: bold ?? this.bold,
        highContrast: highContrast ?? this.highContrast,
        largeTargets: largeTargets ?? this.largeTargets,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        themeMode: themeMode ?? this.themeMode,
      );

  Map<String, Object> toJson() => {
        'text': textScale,
        'bold': bold,
        'contrast': highContrast,
        'large': largeTargets,
        'calm': reduceMotion,
        'theme': themeMode.name,
      };

  factory A11ySettings.fromJson(Map<String, dynamic> j) => A11ySettings(
        textScale: ((j['text'] as num?)?.toDouble() ?? 1).clamp(0.9, 2.0),
        bold: j['bold'] == true,
        highContrast: j['contrast'] == true,
        largeTargets: j['large'] == true,
        reduceMotion: j['calm'] == true,
        themeMode: ThemeMode.values.asNameMap()[j['theme']] ?? ThemeMode.system,
      );

  /// The phone's own settings still count: whichever asks for more wins.
  MediaQueryData apply(MediaQueryData m) {
    final phone = m.textScaler.scale(1);
    return m.copyWith(
      textScaler: TextScaler.linear(math.min(2.4, math.max(phone, textScale * phone))),
      boldText: m.boldText || bold,
      disableAnimations: m.disableAnimations || reduceMotion,
      highContrast: m.highContrast || highContrast,
    );
  }
}

class A11yController extends Notifier<A11ySettings> {
  static const _key = 'a11y';

  @override
  A11ySettings build() {
    _load();
    return const A11ySettings();
  }

  Future<void> _load() async {
    final raw = await ref.read(prefsStoreProvider).read(_key);
    if (raw == null) return;
    try {
      state = A11ySettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      // A damaged value: keep the defaults.
    }
  }

  void set(A11ySettings next) {
    state = next;
    ref.read(prefsStoreProvider).write(_key, jsonEncode(next.toJson()));
  }

  void reset() => set(const A11ySettings());
}

final a11yProvider = NotifierProvider<A11yController, A11ySettings>(A11yController.new);
