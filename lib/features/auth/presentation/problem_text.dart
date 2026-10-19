import '../../../core/api/problem.dart';
import '../../../l10n/app_localizations.dart';

/// The member's own words for an API problem. Never shows server text directly, so
/// every message exists in both languages.
/// Why a member may not borrow (loans quote reasons and request refusals).
String loanReasonText(AppLocalizations l, String code) => switch (code) {
      'too_new' => l.loanWhyTooNew,
      'in_arrears' => l.loanWhyArrears,
      'loan_open' => l.loanWhyOpen,
      'over_limit' => l.loanWhyOverLimit,
      'term_too_long' => l.loanWhyTerm,
      _ => l.genericError,
    };

String problemText(AppLocalizations l, Object error) {
  if (error is! ApiProblem) return l.genericError;
  // Field errors come as a map from form validation, but as a list from the rules check
  // (path, code, message); only the map form names fields here.
  final rawErrors = error.extra['errors'];
  final fields = rawErrors is Map ? rawErrors : const {};
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
    'no_change' => l.errNoRuleChange,
    'meeting_state' => l.errMeetingState,
    'loans_off' => l.errLoansOff,
    'own_fine' => l.errOwnFine,
    'fine_not_open' => l.errFineNotOpen,
    'too_new' || 'in_arrears' || 'loan_open' || 'over_limit' || 'term_too_long' =>
      loanReasonText(l, error.code),
    'guarantors_needed' => l.errGuarantorsNeeded,
    'invalid_guarantor' => l.errInvalidGuarantor,
    'guarantor_cannot_cover' => l.errGuarantorCannotCover,
    'loan_state' || 'not_replaceable' => l.errLoanState,
    'place_required' => l.errPlaceRequired,
    'too_late' => l.errTooLate,
    'too_early' => l.errTooEarly,
    'code_wrong' => l.errMeetCodeWrong,
    'already_checked_in' => l.errAlreadyCheckedIn,
    'already_sent' => l.errAlreadySent,
    'minutes_empty' => l.errMinutesEmpty,
    'minutes_out' => l.errMinutesOut,
    'proposal_open' => l.errProposalOpen,
    'cooling_off' => l.errCoolingOff,
    'cannot_withdraw' => l.errCannotWithdraw,
    'phone_required' => l.invitePhoneRequired,
    'not_allowed' || 'not_founding' => l.errNotAllowed,
    'file_too_large' => l.errFileTooLarge,
    'amounts_differ' => l.errAmountsDiffer,
    'objection_closed' => l.errObjectionClosed,
    'bad_dates' => l.errBadDates,
    'money_out_off' => l.errMoneyOutOff,
    'use_device_key' => l.errUseDeviceKey,
    'sms_invite_not_allowed' => l.errSmsInviteNotAllowed,
    'already_voted' => l.errAlreadyVoted,
    'vote_closed' => l.errVoteClosed,
    'not_eligible' => l.errNotEligible,
    'other_phone' => l.errOtherPhone,
    'signature_invalid' || 'device_invalid' || 'nonce_invalid' => l.errSignatureInvalid,
    'payload_changed' => l.errPayloadChanged,
    'attestation_untrusted' => l.errKeyNotTrusted,
    'attestation_invalid' || 'key_invalid' || 'key_registered' => l.errAttestationInvalid,
    'turn_in_progress' => l.errTurnInProgress,
    'turn_blocked' => l.errTurnBlocked,
    'rotation_running' => l.errRotationRunning,
    'rotation_complete' => l.errRotationComplete,
    'no_rotation_running' || 'no_rotation' => l.errNoRotationRunning,
    'order_incomplete' => l.errOrderIncomplete,
    'payee_cannot_approve' => l.errPayeeCannotApprove,
    'already_answered' => l.errAlreadyAnswered,
    'not_collecting' => l.errNotCollecting,
    'not_approved' => l.errNotApproved,
    'reason_required' || 'purpose_required' || 'payee_required' || 'explanation_required' =>
      l.errFillIn,
    'not_linkable' || 'not_open' => l.errNotLinkable,
    'typed_lines_do_not_add_up' => l.errTypedDoNotAddUp,
    'typed_lines_incomplete' => l.errTypedIncomplete,
    'typed_line_invalid' => l.errTypedInvalid,
    _ => l.genericError,
  };
}
