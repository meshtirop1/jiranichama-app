import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/labels.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';
import 'chama_screen.dart';
import 'cash_screen.dart';
import 'money_out_screen.dart';
import 'records_tab.dart';
import 'widgets/rule_book_list.dart';

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
            for (final m in bundle.members)
              ListTile(title: Text(m.name),
                  subtitle: Text('${roleLabel(l, m.role)} · ${m.memberCode}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(
                      '/chamas/${bundle.chama.id}/members/${m.id}/statement')),
          ]),
          ListView(padding: const EdgeInsets.all(JiraniSpace.m),
              children: [RuleBookList(bundle.rules.clauses(lang))]),
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
        _CashToConfirm(chamaId: chama.id, myId: me?.id),
        _MoneyOutNotices(chamaId: chama.id, moneyOut: chama.mode == 'money_out'),
        if (chama.mode == 'records_only') ...[
          const SizedBox(height: JiraniSpace.s),
          Notice(l.recordsOnlyNote),
        ],
        const SizedBox(height: JiraniSpace.m),
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
