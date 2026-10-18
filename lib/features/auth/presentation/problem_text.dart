import '../../../core/api/problem.dart';
import '../../../l10n/app_localizations.dart';

/// The member's own words for an API problem. Never shows server text directly, so
/// every message exists in both languages.
String problemText(AppLocalizations l, Object error) {
  if (error is! ApiProblem) return l.genericError;
  return switch (error.code) {
    'network' => l.networkError,
    'otp_wrong' => l.codeWrong((error.extra['attempts_left'] as int?) ?? 0),
    'otp_expired' => l.codeExpired,
    'otp_locked' => l.codeLocked,
    'otp_rate_limited' || 'throttled' => l.tooManyCodes,
    'invalid' when (error.extra['errors'] as Map?)?.containsKey('phone') ?? false =>
      l.phoneInvalid,
    'invalid' when (error.extra['errors'] as Map?)?.containsKey('pin') ?? false => l.pinWeak,
    _ => l.genericError,
  };
}
