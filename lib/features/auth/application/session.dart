import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

enum SessionStatus { unknown, signedOut, needsPin, signedIn }

/// Where the member is in sign-in. The router follows this.
class SessionController extends Notifier<SessionStatus> {
  @override
  SessionStatus build() {
    _restore();
    return SessionStatus.unknown;
  }

  Future<void> _restore() async {
    final has = await ref.read(authRepositoryProvider).hasSession();
    state = has ? SessionStatus.signedIn : SessionStatus.signedOut;
  }

  void signedIn({required bool hasPin}) =>
      state = hasPin ? SessionStatus.signedIn : SessionStatus.needsPin;

  void pinSet() => state = SessionStatus.signedIn;

  Future<void> signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    state = SessionStatus.signedOut;
  }
}

final sessionProvider =
    NotifierProvider<SessionController, SessionStatus>(SessionController.new);
