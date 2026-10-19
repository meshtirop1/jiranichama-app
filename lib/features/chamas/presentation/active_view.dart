import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/labels.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';
import 'chama_screen.dart';
import 'cash_screen.dart';
import 'fines_screen.dart';
import 'loans_screen.dart';
import 'meetings_screen.dart';
import 'money_out_screen.dart';
import 'vote_screen.dart';
import 'records_tab.dart';
import 'rule_changes_screen.dart';
import 'widgets/rule_book_list.dart';

final reconciliationProvider = FutureProvider.autoDispose.family<Reconciliation, String>(
    (ref, id) => ref.watch(chamaRepositoryProvider).reconciliation(id));

final positionProvider = FutureProvider.autoDispose.family<Position, String>(
    (ref, membershipId) => ref.watch(chamaRepositoryProvider).position(membershipId));

/// An active chama: overview, records (checked on the phone), members and rules.
class ActiveView extends StatelessWidget {
  const ActiveView({super.key, required this.bundle, required this.onChanged});

  final ChamaBundle bundle;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final lang = Localizations.localeOf(context).languageCode;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(bundle.chama.name),
          bottom: TabBar(isScrollable: true, tabs: [
            Tab(text: l.tabOverview),
            Tab(text: l.tabRecords),
            Tab(text: l.tabMembers),
            Tab(text: l.tabRules),
          ]),
        ),
        body: TabBarView(children: [
          _Overview(bundle: bundle),
          RecordsTab(bundle: bundle),
          ListView(children: [
            if (bundle.chama.iAmOfficial)
              Padding(
                padding: const EdgeInsets.all(JiraniSpace.m),
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: Text(l.inviteMember),
                  onPressed: () => showModalBottomSheet<void>(
                      context: context, isScrollControlled: true,
                      builder: (_) => _InviteSheet(chamaId: bundle.chama.id)),
                ),
              ),
            for (final m in bundle.members)
              ListTile(title: Text(m.name),
                  subtitle: Text('${roleLabel(l, m.role)} · ${m.memberCode}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                      '/chamas/${bundle.chama.id}/members/${m.id}/statement')),
          ]),
          ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
            RuleChangesSection(chamaId: bundle.chama.id, official: bundle.chama.iAmOfficial),
            RuleBookList(bundle.rules.clauses(lang)),
          ]),
        ]),
      ),
    );
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({required this.bundle});

  final ChamaBundle bundle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final chama = bundle.chama;
    final me = bundle.me;
    final account = chama.bankAccount;

    Widget row(String label, Widget value) => Padding(
          padding: const EdgeInsets.symmetric(vertical: JiraniSpace.xs),
          child: Row(children: [Expanded(child: Text(label)), value]),
        );

    return ListView(
      padding: const EdgeInsets.all(JiraniSpace.m),
      children: [
        if (me != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(JiraniSpace.m),
              child: ref.watch(positionProvider(me.id)).when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Notice(problemText(l, e), tone: NoticeTone.critical),
                    data: (p) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l.myPosition, style: text.titleMedium),
                        const SizedBox(height: JiraniSpace.s),
                        row(l.contributed, MoneyText(p.contributed)),
                        if (p.opening.cents > 0)
                          row(l.openingSavings, MoneyText(p.opening)),
                        if (p.pendingCash.cents > 0)
                          row(l.pendingCash, MoneyText(p.pendingCash)),
                        row(l.arrears, MoneyText(p.arrears)),
                        row(l.finesOwed, MoneyText(p.fines)),
                        if (p.credit.cents > 0) row(l.creditLabel, MoneyText(p.credit)),
                        if (p.nextDuePeriod != null) ...[
                          const SizedBox(height: JiraniSpace.s),
                          Text(l.nextDue(p.nextDue.format(), p.nextDuePeriod!)),
                        ],
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton(
                            onPressed: () => context.push(
                                '/chamas/${chama.id}/members/${me.id}/statement'),
                            child: Text(l.seeMyStatement),
                          ),
                        ),
                      ],
                    ),
                  ),
            ),
          ),
        if (account != null && chama.myMemberCode != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(JiraniSpace.m),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(l.howToPay, style: text.titleMedium),
                const SizedBox(height: JiraniSpace.s),
                Text(l.payWithCode(bankNames[account.bank] ?? account.bank, account.last4,
                    chama.myMemberCode!)),
                if (account.paybill.isNotEmpty) ...[
                  const SizedBox(height: JiraniSpace.xs),
                  Text(l.payPaybill(account.paybill, chama.myMemberCode!)),
                ],
              ]),
            ),
          ),
        _BankCheck(chamaId: chama.id, myRole: chama.myRole),
        _OpenVotes(chamaId: chama.id),
        FinesCard(chamaId: chama.id),
        MeetingsCard(chamaId: chama.id),
        if (chama.loansOn) LoansCard(chamaId: chama.id),
        _CashToConfirm(chamaId: chama.id, myId: me?.id),
        _MoneyOutNotices(chamaId: chama.id, moneyOut: chama.mode == 'money_out'),
        if (chama.mode == 'records_only') ...[
          const SizedBox(height: JiraniSpace.s),
          Notice(l.recordsOnlyNote),
        ],
        const SizedBox(height: JiraniSpace.m),
        if (bundle.rules.rules['rotation'] != null) ...[
          OutlinedButton.icon(
            icon: const Icon(Icons.autorenew),
            label: Text(l.merryGoRound),
            onPressed: () => context.push('/chamas/${chama.id}/rotation'),
          ),
          const SizedBox(height: JiraniSpace.s),
        ],
        OutlinedButton.icon(
          icon: const Icon(Icons.outbox_outlined),
          label: Text(l.moneyOut),
          onPressed: () => context.push('/chamas/${chama.id}/money-out'),
        ),
        const SizedBox(height: JiraniSpace.s),
        OutlinedButton.icon(
          icon: const Icon(Icons.summarize_outlined),
          label: Text(l.chamaStatement),
          onPressed: () => context.push('/chamas/${chama.id}/statement'),
        ),
        const SizedBox(height: JiraniSpace.s),
        OutlinedButton.icon(
          icon: const Icon(Icons.payments_outlined),
          label: Text(l.cashAtMeetings),
          onPressed: () => context.push('/chamas/${chama.id}/cash'),
        ),
        const SizedBox(height: JiraniSpace.s),
        OutlinedButton.icon(
          icon: const Icon(Icons.menu_book_outlined),
          label: Text(l.openingBalances),
          onPressed: () => context.push('/chamas/${chama.id}/opening'),
        ),
        if (chama.iAmOfficial || chama.myRole == 'auditor') ...[
          const SizedBox(height: JiraniSpace.m),
          OutlinedButton.icon(
            icon: const Icon(Icons.description_outlined),
            label: Text(l.statements),
            onPressed: () => context.push('/chamas/${chama.id}/statements'),
          ),
          const SizedBox(height: JiraniSpace.s),
          OutlinedButton.icon(
            icon: const Icon(Icons.help_outline),
            label: Text(l.unmatched),
            onPressed: () => context.push('/chamas/${chama.id}/unmatched'),
          ),
        ],
      ],
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
      child: InkWell(
        onTap: () => context.push('/chamas/$chamaId/cash'),
        child: Notice(l.cashToConfirm(mine), tone: NoticeTone.warning),
      ),
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
          child: InkWell(
            onTap: () => context.push('/chamas/$chamaId/money-out'),
            child: Notice(l.unapprovedAlert(d.amount.format(), d.valueDate),
                tone: NoticeTone.critical),
          ),
        ),
      if (waiting > 0)
        Padding(
          padding: const EdgeInsets.only(top: JiraniSpace.s),
          child: InkWell(
            onTap: () => context.push('/chamas/$chamaId/money-out'),
            child: Notice(l.waitingYourApproval('$waiting'), tone: NoticeTone.warning),
          ),
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
        tone = NoticeTone.info;
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
      padding: const EdgeInsets.only(top: JiraniSpace.s),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (overdue != null) ...[overdue, const SizedBox(height: JiraniSpace.s)],
        Notice(headline, tone: tone),
        for (final line in lines)
          Padding(padding: const EdgeInsets.only(top: JiraniSpace.xs),
              child: Text(line, style: text.bodySmall)),
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
          child: InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => VoteScreen(chamaId: chamaId, voteId: v.id))),
            child: Notice(l.voteWaiting(v.question), tone: NoticeTone.warning),
          ),
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
