import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/labels.dart';
import '../../../core/providers.dart';
import '../../../core/tours.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/prefs.dart';
import '../../auth/presentation/problem_text.dart';
import '../../registration/registration_screen.dart';
import '../../settings/accessibility_sheet.dart';
import '../data/models.dart';
import 'chama_screen.dart';
import 'cash_screen.dart';
import 'fines_screen.dart';
import 'governance_screen.dart';
import 'growth_screen.dart';
import 'loans_screen.dart';
import 'mandate_screen.dart';
import 'meetings_screen.dart';
import 'money_out_screen.dart';
import 'vote_screen.dart';
import 'records_tab.dart';
import 'rule_changes_screen.dart';
import 'widgets/rule_book_list.dart';

final reconciliationProvider = FutureProvider.autoDispose.family<Reconciliation, String>(
    (ref, id) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).reconciliation(id);
});

final positionProvider = FutureProvider.autoDispose.family<Position, String>(
    (ref, membershipId) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).position(membershipId);
});

/// An active chama: overview, records (checked on the phone), members and rules, one
/// at a time behind a bottom navigation bar.
class ActiveView extends ConsumerStatefulWidget {
  const ActiveView({super.key, required this.bundle, required this.onChanged});

  final ChamaBundle bundle;
  final VoidCallback onChanged;

  @override
  ConsumerState<ActiveView> createState() => _ActiveViewState();
}

/// The parts of the chama screens a guided tour points at.
class ChamaTourKeys {
  final position = GlobalKey();
  final pay = GlobalKey();
  final shortcuts = GlobalKey();
  final more = GlobalKey();
  final nav = GlobalKey();
  final chain = GlobalKey();
  final records = GlobalKey();
  final members = GlobalKey();
  final invite = GlobalKey();
  final rules = GlobalKey();
  final ruleChange = GlobalKey();
}

class _ActiveViewState extends ConsumerState<ActiveView> {
  int _tab = 0;
  final _keys = ChamaTourKeys();

  static const _tours = ['chama-overview', 'chama-records', 'chama-members', 'chama-rules'];

  /// What the tour says on each tab, pointing at its parts.
  List<TourStep> _steps(int tab) {
    final l = AppLocalizations.of(context);
    final k = _keys;
    final official = widget.bundle.chama.iAmOfficial;
    return switch (tab) {
      0 => [
          TourStep(icon: Icons.waving_hand_outlined, title: l.tourWelcomeTitle,
              body: l.tourWelcomeBody),
          TourStep(target: k.position, icon: Icons.account_balance_wallet_outlined,
              title: l.tourPositionTitle, body: l.tourPositionBody),
          TourStep(target: k.pay, icon: Icons.account_balance_rounded, tone: JiraniTone.info,
              title: l.tourPayTitle, body: l.tourPayBody),
          TourStep(target: k.shortcuts, icon: Icons.apps_rounded, title: l.tourShortcutsTitle,
              body: l.tourShortcutsBody),
          TourStep(target: k.more, icon: Icons.event_available_outlined,
              tone: JiraniTone.warning, title: l.tourMoreTitle, body: l.tourMoreBody),
          TourStep(target: k.nav, icon: Icons.swipe_rounded, title: l.tourNavTitle,
              body: l.tourNavBody),
        ],
      1 => [
          TourStep(target: k.chain, icon: Icons.verified_outlined, tone: JiraniTone.good,
              title: l.tourRecordsCheckTitle, body: l.tourRecordsCheckBody),
          TourStep(target: k.records, icon: Icons.receipt_long_outlined,
              title: l.tourRecordsListTitle, body: l.tourRecordsListBody),
        ],
      2 => [
          TourStep(target: k.members, icon: Icons.groups_2_outlined,
              title: l.tourMembersTitle, body: l.tourMembersBody),
          if (official)
            TourStep(target: k.invite, icon: Icons.person_add_alt_1_rounded,
                tone: JiraniTone.warning, title: l.tourInviteTitle, body: l.tourInviteBody),
        ],
      _ => [
          TourStep(target: k.rules, icon: Icons.menu_book_outlined, title: l.tourRulesTitle,
              body: l.tourRulesBody),
          TourStep(target: k.ruleChange, icon: Icons.how_to_vote_outlined,
              tone: JiraniTone.info, title: l.tourRuleChangeTitle,
              body: l.tourRuleChangeBody),
        ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    final bundle = widget.bundle;
    final chama = bundle.chama;
    final text = Theme.of(context).textTheme;
    final tab = _tab;
    // Records load and are checked first, so their tour waits a little longer.
    showTourOnce(context, ref, _tours[tab], () => _steps(tab),
        settle: Duration(milliseconds: tab == 1 ? 1800 : 700));
    return Scaffold(
      appBar: AppBar(
        actions: [const AccessibilityButton(), TourButton(steps: () => _steps(_tab)),
          const SizedBox(width: 4)],
        titleSpacing: 0,
        title: Row(children: [
          Avatar(chama.name, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(chama.name, overflow: TextOverflow.ellipsis),
              Text([typeLabel(l, chama.type), if (chama.myRole != null)
                  roleLabel(l, chama.myRole!)].join(' · '), style: text.bodySmall),
            ]),
          ),
        ]),
      ),
      body: switch (_tab) {
        0 => _Overview(bundle: bundle, tourKeys: _keys),
        1 => RecordsTab(bundle: bundle, chainKey: _keys.chain, listKey: _keys.records),
        2 => _MembersTab(bundle: bundle, tourKeys: _keys),
        _ => ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
            KeyedSubtree(key: _keys.ruleChange,
                child: RuleChangesSection(chamaId: chama.id, official: chama.iAmOfficial)),
            KeyedSubtree(key: _keys.rules, child: RuleBookList(bundle.rules.clauses(lang))),
          ]),
      },
      bottomNavigationBar: DecoratedBox(
        key: _keys.nav,
        decoration: BoxDecoration(border: Border(
            top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant))),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            NavigationDestination(icon: const Icon(Icons.space_dashboard_outlined),
                selectedIcon: const Icon(Icons.space_dashboard_rounded),
                label: l.tabOverview),
            NavigationDestination(icon: const Icon(Icons.receipt_long_outlined),
                selectedIcon: const Icon(Icons.receipt_long_rounded),
                label: l.tabRecords),
            NavigationDestination(icon: const Icon(Icons.groups_2_outlined),
                selectedIcon: const Icon(Icons.groups_2_rounded),
                label: l.tabMembers),
            NavigationDestination(icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book_rounded),
                label: l.tabRules),
          ],
        ),
      ),
    );
  }
}

class _MembersTab extends StatelessWidget {
  const _MembersTab({required this.bundle, required this.tourKeys});

  final ChamaBundle bundle;
  final ChamaTourKeys tourKeys;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final members = bundle.members;
    return ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
      Row(children: [
        Expanded(child: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(l.membersCount(members.length), style: text.titleLarge),
        )),
        if (bundle.chama.iAmOfficial)
          FilledButton.tonalIcon(
            key: tourKeys.invite,
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
            label: Text(l.inviteMember),
            onPressed: () => showModalBottomSheet<void>(
                context: context, isScrollControlled: true,
                builder: (_) => _InviteSheet(chamaId: bundle.chama.id)),
          ),
      ]),
      const SizedBox(height: JiraniSpace.m),
      SurfaceCard(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (final (i, m) in members.indexed) ...[
            if (i > 0) const Divider(indent: 72),
            ListTile(
              key: i == 0 ? tourKeys.members : null,
              leading: Avatar(m.name),
              title: Row(children: [
                Flexible(child: Text(m.name, overflow: TextOverflow.ellipsis)),
                if (m.idChecked) ...[
                  const SizedBox(width: 6),
                  Tooltip(
                    message: l.kycVerified,
                    child: Icon(Icons.verified_rounded, size: 18,
                        key: ValueKey('id-checked-${m.id}'),
                        color: JiraniStatus.of(context).good),
                  ),
                ],
              ]),
              subtitle: Text(m.memberCode),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                StatusPill(roleLabel(l, m.role),
                    tone: officialRoles.contains(m.role)
                        ? JiraniTone.brand : JiraniTone.neutral),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded),
              ]),
              onTap: () => context.push(
                  '/chamas/${bundle.chama.id}/members/${m.id}/statement'),
            ),
          ],
        ]),
      ),
    ]);
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.bundle, required this.tourKeys});

  final ChamaBundle bundle;
  final ChamaTourKeys tourKeys;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final chama = bundle.chama;
    final me = bundle.me;
    final account = chama.bankAccount;
    final white = text.titleSmall?.copyWith(color: Colors.white);

    return ListView(
      padding: const EdgeInsets.fromLTRB(JiraniSpace.m, JiraniSpace.s, JiraniSpace.m,
          JiraniSpace.xl),
      children: [
        if (me != null)
          KeyedSubtree(key: tourKeys.position, child: ref.watch(positionProvider(me.id)).when(
                loading: () => const SizedBox(
                    height: 180, child: LoadingView()),
                error: (e, _) => Notice(problemText(l, e), tone: NoticeTone.critical),
                data: (p) => HeroCard(
                  label: l.myPosition,
                  value: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    MoneyText(p.contributed,
                        style: text.displaySmall?.copyWith(color: Colors.white)),
                    Text(l.contributed, style: text.bodyMedium
                        ?.copyWith(color: Colors.white.withValues(alpha: .75))),
                  ]),
                  children: [
                    if (p.opening.cents > 0)
                      HeroFigure(l.openingSavings, MoneyText(p.opening, style: white)),
                    if (p.pendingCash.cents > 0)
                      HeroFigure(l.pendingCash, MoneyText(p.pendingCash, style: white)),
                    HeroFigure(l.arrears, MoneyText(p.arrears, style: white),
                        alert: p.arrears.cents > 0),
                    HeroFigure(l.finesOwed, MoneyText(p.fines, style: white),
                        alert: p.fines.cents > 0),
                    if (p.credit.cents > 0)
                      HeroFigure(l.creditLabel, MoneyText(p.credit, style: white)),
                    if (p.finesStopped)
                      Container(
                        key: const ValueKey('fines-stopped'),
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFC46B).withValues(alpha: .18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          const Icon(Icons.pan_tool_alt_outlined, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(l.finesStoppedNote,
                              style: text.bodyMedium?.copyWith(color: Colors.white))),
                        ]),
                      ),
                    if (p.nextDuePeriod != null)
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          const Icon(Icons.event_rounded, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(l.nextDue(p.nextDue.format(), p.nextDuePeriod!),
                              style: text.bodyMedium?.copyWith(color: Colors.white))),
                        ]),
                      ),
                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 4)),
                        onPressed: () => context.push(
                            '/chamas/${chama.id}/members/${me.id}/statement'),
                        icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                        iconAlignment: IconAlignment.end,
                        label: Text(l.seeMyStatement),
                      ),
                    ),
                  ],
                ),
              )),
        _DeathReported(chamaId: chama.id),
        _RegistrationNudge(chama: chama),
        if (chama.state == ChamaState.active && !chama.mandateSafe)
          Padding(
            padding: const EdgeInsets.only(top: JiraniSpace.m),
            child: Notice(key: const ValueKey('mandate-warning'), l.mandateOverview,
                tone: NoticeTone.warning,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => MandateScreen(chama: chama)))),
          ),
        _BankCheck(chamaId: chama.id, myRole: chama.myRole),
        _OpenVotes(chamaId: chama.id),
        _CashToConfirm(chamaId: chama.id, myId: me?.id),
        _MoneyOutNotices(chamaId: chama.id, moneyOut: chama.mode == 'money_out'),
        if (chama.mode == 'records_only') ...[
          const SizedBox(height: JiraniSpace.s),
          Notice(l.recordsOnlyNote),
        ],
        if (account != null && chama.myMemberCode != null) ...[
          const SizedBox(height: JiraniSpace.m),
          SurfaceCard(
            key: tourKeys.pay,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                const ToneIcon(Icons.account_balance_rounded, tone: JiraniTone.info, size: 38),
                const SizedBox(width: 12),
                Expanded(child: Text(l.howToPay, style: text.titleMedium)),
              ]),
              const SizedBox(height: 12),
              Text(l.payWithCode(bankNames[account.bank] ?? account.bank, account.last4,
                  chama.myMemberCode!), style: text.bodyMedium),
              if (account.paybill.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Icon(Icons.phone_android_rounded, size: 18, color: scheme.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l.payPaybill(account.paybill, chama.myMemberCode!),
                        style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                  ]),
                ),
              ],
            ]),
          ),
        ],
        SectionHeader(l.sectionShortcuts),
        QuickActions(key: tourKeys.shortcuts, [
          if (bundle.rules.rules['rotation'] != null)
            QuickAction(icon: Icons.autorenew_rounded, label: l.merryGoRound,
                tone: JiraniTone.warning,
                onTap: () => context.push('/chamas/${chama.id}/rotation')),
          QuickAction(icon: Icons.north_east_rounded, label: l.moneyOut,
              onTap: () => context.push('/chamas/${chama.id}/money-out')),
          QuickAction(icon: Icons.summarize_outlined, label: l.chamaStatement,
              tone: JiraniTone.info,
              onTap: () => context.push('/chamas/${chama.id}/statement')),
          QuickAction(icon: Icons.payments_outlined, label: l.cashAtMeetings,
              tone: JiraniTone.good,
              onTap: () => context.push('/chamas/${chama.id}/cash')),
          QuickAction(icon: Icons.history_edu_outlined, label: l.openingBalances,
              tone: JiraniTone.neutral,
              onTap: () => context.push('/chamas/${chama.id}/opening')),
          if (chama.iAmOfficial || chama.myRole == 'auditor') ...[
            QuickAction(icon: Icons.description_outlined, label: l.statements,
                tone: JiraniTone.info,
                onTap: () => context.push('/chamas/${chama.id}/statements')),
            QuickAction(icon: Icons.manage_search_rounded, label: l.unmatched,
                tone: JiraniTone.warning,
                onTap: () => context.push('/chamas/${chama.id}/unmatched')),
          ],
        ]),
        // Where to go for the rest: fines, running the chama, meetings, loans.
        SectionHeader(l.sectionMore),
        KeyedSubtree(key: tourKeys.more, child: FinesCard(chamaId: chama.id)),
        GovernanceCard(chama: chama),
        GrowthCard(chama: chama),
        MeetingsCard(chamaId: chama.id),
        if (chama.loansOn) LoansCard(chamaId: chama.id),
      ],
    );
  }
}

final _nudgeSnoozedProvider = FutureProvider.autoDispose.family<bool, String>((ref, id) async {
  final raw = await ref.watch(prefsStoreProvider).read('reg_snooze_$id');
  final until = raw == null ? null : DateTime.tryParse(raw);
  return until != null && DateTime.now().isBefore(until);
});

/// Now and then (every two weeks, until the chama has its certificate) the overview
/// reminds the members to register the chama, and offers the papers ready-made.
class _RegistrationNudge extends ConsumerWidget {
  const _RegistrationNudge({required this.chama});

  final Chama chama;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (chama.registered || chama.state != ChamaState.active) return const SizedBox.shrink();
    final snoozed = ref.watch(_nudgeSnoozedProvider(chama.id));
    if (snoozed.value != false) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: JiraniSpace.m),
      child: SurfaceCard(
        key: const ValueKey('reg-nudge'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const ToneIcon(Icons.workspace_premium_outlined, tone: JiraniTone.info, size: 40),
            const SizedBox(width: 12),
            Expanded(child: Text(l.regNudgeTitle, style: text.titleSmall)),
          ]),
          const SizedBox(height: 8),
          Text(l.regNudgeBody, style: text.bodySmall),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 4, children: [
            FilledButton.tonal(
              key: const ValueKey('reg-nudge-open'),
              style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RegistrationScreen(chamaId: chama.id))),
              child: Text(l.regNudgeOpen),
            ),
            TextButton(
              key: const ValueKey('reg-nudge-later'),
              onPressed: () async {
                await ref.read(prefsStoreProvider).write('reg_snooze_${chama.id}',
                    DateTime.now().add(const Duration(days: 14)).toIso8601String());
                ref.invalidate(_nudgeSnoozedProvider(chama.id));
              },
              child: Text(l.regNudgeLater),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// A member someone has reported as dead sees it first, and can say it is not true. They
/// are not locked out while the report waits (protection plan 2026-10-20).
class _DeathReported extends ConsumerWidget {
  const _DeathReported({required this.chamaId});

  final String chamaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mine = (ref.watch(exitsProvider(chamaId)).value ?? const <ExitInfo>[])
        .where((e) => e.mine && e.isDeathReport).firstOrNull;
    if (mine == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: JiraniSpace.m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Notice(l.deathReportedMe(mine.reportedBy), tone: NoticeTone.critical),
        const SizedBox(height: JiraniSpace.s),
        FilledButton(
          key: const ValueKey('i-am-alive'),
          style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError),
          onPressed: () async {
            await ref.read(chamaRepositoryProvider).cancelExit(mine.id);
            ref.invalidate(exitsProvider(chamaId));
          },
          child: Text(l.deathIAmAlive),
        ),
      ]),
    );
  }
}

/// Tells a member that cash the treasurer recorded for them is waiting for their
/// confirmation, so it is not left unconfirmed.
class _CashToConfirm extends ConsumerWidget {
  const _CashToConfirm({required this.chamaId, required this.myId});

  final String chamaId;
  final String? myId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final mine = ref.watch(cashProvider(chamaId)).value
            ?.where((r) => r.state == 'recorded' && r.membershipId == myId)
            .length ??
        0;
    if (mine == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: JiraniSpace.s),
      child: Notice(l.cashToConfirm(mine), tone: NoticeTone.warning,
          onTap: () => context.push('/chamas/$chamaId/cash')),
    );
  }
}

/// Money that left the bank without approval (every member), and payments waiting for
/// this official's approval.
class _MoneyOutNotices extends ConsumerWidget {
  const _MoneyOutNotices({required this.chamaId, required this.moneyOut});

  final String chamaId;
  final bool moneyOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!moneyOut) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final open = (ref.watch(unapprovedProvider(chamaId)).value ?? const [])
        .where((d) => d.open).toList();
    final waiting = (ref.watch(proposalsProvider(chamaId)).value ?? const [])
        .where((p) => p.canAnswer).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final d in open)
        Padding(
          padding: const EdgeInsets.only(top: JiraniSpace.s),
          child: Notice(l.unapprovedAlert(d.amount.format(), d.valueDate),
              tone: NoticeTone.critical,
              onTap: () => context.push('/chamas/$chamaId/money-out')),
        ),
      if (waiting > 0)
        Padding(
          padding: const EdgeInsets.only(top: JiraniSpace.s),
          child: Notice(l.waitingYourApproval('$waiting'), tone: NoticeTone.warning,
              onTap: () => context.push('/chamas/$chamaId/money-out')),
        ),
    ]);
  }
}

/// Every morning the bank is checked against the records (5.5). Every member sees the
/// same answer: a match, a gap (and what it is made of), or a breach.
class _BankCheck extends ConsumerWidget {
  const _BankCheck({required this.chamaId, required this.myRole});

  final String chamaId;
  final String? myRole;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final r = ref.watch(reconciliationProvider(chamaId)).value;
    if (r == null) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    final lines = <String>[];
    final String headline;
    final NoticeTone tone;
    switch (r.status) {
      case 'match':
        headline = l.recMatch(r.checkedOn ?? '');
        tone = NoticeTone.good;
      case 'open' || 'breach':
        final amount = Kes(r.gap.cents.abs()).format();
        headline = r.status == 'breach'
            ? l.recBreach(amount, '${r.daysOpen}')
            : l.recGap(amount, r.gapOpenedOn ?? '');
        tone = r.status == 'breach' ? NoticeTone.critical : NoticeTone.warning;
        if (r.unmatched.cents != 0) lines.add(l.recUnmatched(r.unmatched.format()));
        if (r.unexplained.cents != 0) {
          lines.add(l.recUnexplained(Kes(r.unexplained.cents.abs()).format()));
        }
        if (r.status == 'open') lines.add(l.recBreachSoon('${r.breachAfterDays}'));
      default:
        headline = l.recNoStatement;
        tone = NoticeTone.info;
    }
    // An overdue bank statement: the treasurer first, then every official, then everyone.
    final level = r.statementLevel;
    final official = officialRoles.contains(myRole);
    final Widget? overdue = level >= 3
        ? Notice(l.statementNotCheckedSince(r.statementCheckedTo ?? l.sinceGoingLive),
            tone: NoticeTone.critical)
        : (level == 2 && official) || (level == 1 && myRole == 'treasurer')
            ? Notice(l.statementOverdue('${r.statementDaysOverdue}'), tone: NoticeTone.warning)
            : null;
    return Padding(
      padding: const EdgeInsets.only(top: JiraniSpace.m),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (overdue != null) ...[overdue, const SizedBox(height: JiraniSpace.s)],
        Notice(headline, tone: tone),
        for (final line in lines)
          Padding(padding: const EdgeInsets.only(top: JiraniSpace.xs),
              child: Text(line, style: text.bodySmall)),
        if (r.fromBankApi)
          Padding(
            padding: const EdgeInsets.only(top: JiraniSpace.xs),
            child: Text(l.recFromBankApi, key: const ValueKey('rec-bank-api'),
                style: text.bodySmall),
          ),
        if (r.bank != null && r.records != null && r.status != 'match')
          Padding(
            padding: const EdgeInsets.only(top: JiraniSpace.xs),
            child: Text(l.recBankRecords(r.bank!.format(), r.records!.format()),
                style: text.bodySmall),
          ),
      ]),
    );
  }
}

/// Votes this member can still cast, so nobody misses one.
class _OpenVotes extends ConsumerWidget {
  const _OpenVotes({required this.chamaId});

  final String chamaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final open = (ref.watch(votesProvider(chamaId)).value ?? const [])
        .where((v) => v.iCanVote).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final v in open)
        Padding(
          padding: const EdgeInsets.only(top: JiraniSpace.s),
          child: Notice(l.voteWaiting(v.question), tone: NoticeTone.warning,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => VoteScreen(chamaId: chamaId, voteId: v.id)))),
        ),
    ]);
  }
}

/// Invite a member to an active chama: a code to share with someone who has the app, or
/// an SMS for someone without a smartphone, who replies YES with the code (5.2a).
class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet({required this.chamaId});

  final String chamaId;

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final _phone = TextEditingController();
  bool _bySms = false;
  String _language = 'en';
  String? _result;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final inv = await ref.read(chamaRepositoryProvider).invite(widget.chamaId,
          role: 'member', phone: _phone.text.trim(), bySms: _bySms, language: _language);
      setState(() => _result = _bySms ? l.inviteSmsSent(inv.phoneHint.isEmpty ? _phone.text.trim() : inv.phoneHint)
          : l.inviteCodeToShare(inv.code));
    } catch (e) {
      setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(left: JiraniSpace.m, right: JiraniSpace.m, top: JiraniSpace.m,
          bottom: MediaQuery.of(context).viewInsets.bottom + JiraniSpace.m),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.inviteMember, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: JiraniSpace.s),
        TextField(key: const ValueKey('invite-member-phone'), controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: l.invitePhoneLabel)),
        SwitchListTile(
          key: const ValueKey('invite-by-sms'),
          contentPadding: EdgeInsets.zero,
          title: Text(l.inviteBySms),
          subtitle: Text(l.inviteBySmsHelp),
          value: _bySms,
          onChanged: (v) => setState(() => _bySms = v),
        ),
        if (_bySms)
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'en', label: Text('English')),
              ButtonSegment(value: 'sw', label: Text('Kiswahili')),
            ],
            selected: {_language},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _language = s.first),
          ),
        if (_error != null) ...[
          const SizedBox(height: JiraniSpace.s),
          Notice(_error!, tone: NoticeTone.critical),
        ],
        if (_result != null) ...[
          const SizedBox(height: JiraniSpace.s),
          Notice(_result!),
        ],
        const SizedBox(height: JiraniSpace.m),
        PrimaryButton(label: _bySms ? l.sendSmsInvite : l.createInviteCode, busy: _busy,
            onPressed: _send),
      ]),
    );
  }
}
