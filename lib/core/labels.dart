// The member's words for codes the API uses.

import '../features/chamas/data/models.dart';
import '../l10n/app_localizations.dart';

String roleLabel(AppLocalizations l, String role) => switch (role) {
      'chair' => l.roleChair,
      'treasurer' => l.roleTreasurer,
      'secretary' => l.roleSecretary,
      'auditor' => l.roleAuditor,
      'signatory' => l.roleSignatory,
      _ => l.roleMember,
    };

String typeLabel(AppLocalizations l, String type) => switch (type) {
      'merry_go_round' => l.typeMerryGoRound,
      'table_banking' => l.typeTableBanking,
      'welfare' => l.typeWelfare,
      _ => l.typeInvestmentClub,
    };

String stateLabel(AppLocalizations l, ChamaState s) => switch (s) {
      ChamaState.setup => l.stateSetup,
      ChamaState.awaitingOfficials => l.stateAwaitingOfficials,
      ChamaState.awaitingAdoption => l.stateAwaitingAdoption,
      ChamaState.active => l.stateActive,
      ChamaState.suspended => l.stateSuspended,
      ChamaState.closed => l.stateClosed,
      ChamaState.expired => l.stateExpired,
    };

String entryLabel(AppLocalizations l, String type) => switch (type) {
      'contribution' => l.entryContribution,
      'fine_raised' => l.entryFineRaised,
      'fine_paid' => l.entryFinePaid,
      'reversal' || 'correction' => l.entryReversal,
      'membership' => l.entryMembership,
      'rule_version_adopted' => l.entryRulesAdopted,
      _ => l.entryOther,
    };

String statementStateLabel(AppLocalizations l, String state) => switch (state) {
      'awaiting_confirmation' => l.statementAwaiting,
      'accepted' => l.statementAccepted,
      'needs_parser' => l.statementNeedsParser,
      'held_mail_check' => l.statementHeld,
      _ => l.statementRejected,
    };

/// Bank names are proper nouns and are not translated.
const bankNames = {
  'equity': 'Equity Bank',
  'kcb': 'KCB Bank',
  'coop': 'Co-operative Bank',
  'ncba': 'NCBA',
  'absa': 'Absa Bank Kenya',
  'stanbic': 'Stanbic Bank',
  'family': 'Family Bank',
  'other': 'Other bank',
};
