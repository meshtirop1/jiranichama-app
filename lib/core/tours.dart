import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../l10n/app_localizations.dart';

/// Which guided tours this phone has already shown. Each tour plays once, by itself, the
/// first time its screen opens; the help button replays it any time.
abstract class TourMemory {
  Future<bool> seen(String tour);
  Future<void> markSeen(String tour);
  Future<void> forget(String tour);
}

/// Every guided tour in the app, so Settings can play them all again.
const allTours = ['sign-in', 'home', 'chama-overview', 'chama-records', 'chama-members',
    'chama-rules', 'money-out'];

class SecureTourMemory implements TourMemory {
  static const _storage = FlutterSecureStorage();

  @override
  Future<bool> seen(String tour) async {
    try {
      return await _storage.read(key: 'tour_$tour') != null;
    } catch (_) {
      // Storage not available (widget tests, a locked keystore): do not interrupt.
      return true;
    }
  }

  @override
  Future<void> markSeen(String tour) async {
    try {
      await _storage.write(key: 'tour_$tour', value: '1');
    } catch (_) {}
  }

  @override
  Future<void> forget(String tour) async {
    try {
      await _storage.delete(key: 'tour_$tour');
    } catch (_) {}
  }
}

class MemoryTourMemory implements TourMemory {
  final Set<String> shown = {};

  @override
  Future<bool> seen(String tour) async => shown.contains(tour);

  @override
  Future<void> markSeen(String tour) async => shown.add(tour);

  @override
  Future<void> forget(String tour) async => shown.remove(tour);
}

final tourMemoryProvider = Provider<TourMemory>((ref) => SecureTourMemory());

/// Tours already looked at while the app runs: a screen that rebuilds does not check (or
/// start) its tour again.
final _handled = <String>{};

/// Settings → "Show the guided tours again": each one plays the next time its screen opens.
Future<void> replayTours(WidgetRef ref) async {
  final memory = ref.read(tourMemoryProvider);
  for (final t in allTours) {
    _handled.remove(t);
    await memory.forget(t);
  }
}

TourLabels tourLabels(AppLocalizations l) =>
    TourLabels(next: l.tourNext, done: l.tourDone, skip: l.tourSkip);

/// Plays [tour] once on this phone, after the screen has settled (so the parts it points
/// at have loaded). [steps] is built at that moment.
void showTourOnce(BuildContext context, WidgetRef ref, String tour,
    List<TourStep> Function() steps, {Duration settle = const Duration(milliseconds: 700)}) {
  if (!_handled.add(tour)) return;
  final memory = ref.read(tourMemoryProvider);
  Future<void>(() async {
    if (await memory.seen(tour)) return;
    await Future<void>.delayed(settle);
    if (!context.mounted) return;
    await memory.markSeen(tour);
    if (!context.mounted) return;
    await showTour(context, steps(), labels: tourLabels(AppLocalizations.of(context)));
  });
}

/// The "?" in an app bar: plays the screen's tour again.
class TourButton extends StatelessWidget {
  const TourButton({super.key, required this.steps});

  final List<TourStep> Function() steps;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return IconButton(
      key: const ValueKey('tour-help'),
      tooltip: l.tourHelp,
      icon: const Icon(Icons.help_outline_rounded),
      onPressed: () => showTour(context, steps(), labels: tourLabels(l)),
    );
  }
}
