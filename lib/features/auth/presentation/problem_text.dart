import '../../../core/api/problem.dart';
import '../../../l10n/app_localizations.dart';

/// The member's own words for an API problem. Never shows server text directly, so
/// every message exists in both languages.
String problemText(AppLocalizations l, Object error) {
  if (error is! ApiProblem) return l.genericError;
  final fields = (error.extra['errors'] as Map?) ?? const {};
  return switch (error.code) {
    'network' => l.networkError,
    'otp_wrong' || 'signing_wrong' => l.codeWrong((error.extra['attempts_left'] as int?) ?? 0),
    'otp_expired' || 'signing_expired' || 'signing_invalid' || 'signing_content_changed' =>
      l.codeExpired,
    'otp_locked' || 'signing_locked' => l.codeLocked,
    'otp_rate_limited' || 'signing_rate_limited' || 'throttled' => l.tooManyCodes,
    'invalid' when fields.containsKey('phone') => l.phoneInvalid,
    'invalid' when fields.containsKey('pin') => l.pinWeak,
    'treasurer_cannot_upload' => l.errTreasurerUpload,
    'second_official_required' => l.errSecondOfficial,
    'statement_duplicate' => l.errDuplicateStatement,
    'role_taken' => l.errRoleTaken,
    'already_member' => l.errAlreadyMember,
    'invite_other_phone' => l.errInviteOtherPhone,
    'invite_invalid' || 'invite_expired' => l.inviteInvalid,
    'bank_account_missing' => l.errBankMissing,
    'rules_invalid' => l.errRulesInvalid,
    'phone_required' => l.invitePhoneRequired,
    'not_allowed' || 'not_founding' => l.errNotAllowed,
    'file_too_large' => l.errFileTooLarge,
    'amounts_differ' => l.errAmountsDiffer,
    'objection_closed' => l.errObjectionClosed,
    _ => l.genericError,
  };
}
