import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

enum SessionStatus { unknown, signedOut, needsPin, signedIn }

/// Where the member is in sign-in. The router follows this.
class SessionController extends Notifier<SessionStatus> {
  @override
  SessionStatus build() {
    // The session ended under us (the refresh token was refused): back to sign-in,
    // instead of leaving every screen waiting on requests that will never succeed.
    final sub = ref.read(apiClientProvider).sessionEnded.listen((_) {
      if (state == SessionStatus.signedOut) return;
      ref.read(signInEpochProvider.notifier).bump();
      state = SessionStatus.signedOut;
    });
    ref.onDispose(sub.cancel);
    _restore();
    return SessionStatus.unknown;
  }

  Future<void> _restore() async {
    final has = await ref.read(authRepositoryProvider).hasSession();
    state = has ? SessionStatus.signedIn : SessionStatus.signedOut;
  }

  void signedIn({required bool hasPin}) {
    ref.read(signInEpochProvider.notifier).bump();
    state = hasPin ? SessionStatus.signedIn : SessionStatus.needsPin;
  }

  void pinSet() => state = SessionStatus.signedIn;

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    // Not awaited: sign-out never waits on the keystore.
    unawaited(ref.read(phoneSignerProvider).forget());
    ref.read(signInEpochProvider.notifier).bump();
    state = SessionStatus.signedOut;
  }
}

final sessionProvider =
    NotifierProvider<SessionController, SessionStatus>(SessionController.new);
