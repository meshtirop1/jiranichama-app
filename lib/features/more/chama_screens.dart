import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../core/labels.dart';
import '../../l10n/app_localizations.dart';
import '../chamas/data/models.dart';
import '../chamas/presentation/chama_screen.dart';
import '../chamas/presentation/governance_screen.dart';
import '../chamas/presentation/mandate_screen.dart';
import '../chamas/presentation/records_tab.dart';

/// The chama's own details in one place: what it is, its bank, where statements go, its
/// officials, the rule book in force, and whether it is registered.
class ChamaProfileScreen extends ConsumerWidget {
  const ChamaProfileScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final bundle = ref.watch(chamaBundleProvider(chamaId)).value;
    if (bundle == null) return Scaffold(appBar: AppBar(), body: const LoadingView());
    final c = bundle.chama;
    final account = c.bankAccount;
    final officials = bundle.members.where((m) => officialRoles.contains(m.role)).toList();
    final founded = c.json['activated_at'] as String?;
    return Scaffold(
      appBar: AppBar(title: Text(l.cpTitle)),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        SurfaceCard(
          child: Row(children: [
            Avatar(c.name, size: 64),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(c.name, style: text.titleLarge),
              const SizedBox(height: 4),
              Text([typeLabel(l, c.type), c.country, c.currency].join(' · '),
                  style: text.bodyMedium),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: [
                StatusPill(c.mode == 'money_out' ? l.cpMoneyOut : l.cpRecordsOnly,
                    tone: JiraniTone.info),
                StatusPill(c.registered ? l.cpRegistered : l.cpNotRegistered,
                    tone: c.registered ? JiraniTone.good : JiraniTone.warning),
              ]),
            ])),
          ]),
        ),
        const SizedBox(height: JiraniSpace.s),
        TitledCard(
          icon: Icons.info_outline_rounded,
          tone: JiraniTone.neutral,
          title: l.cpDetails,
          children: [
            InfoRow(l.cpMembers, Text('${bundle.members.length}')),
            if (bundle.rules.versionNo != null)
              InfoRow(l.cpRuleVersion, Text('v${bundle.rules.versionNo}')),
            if (founded != null) InfoRow(l.cpActiveSince, Text(founded.substring(0, 10))),
            if (c.myMemberCode != null) InfoRow(l.cpMyCode, Text(c.myMemberCode!)),
          ],
        ),
        if (account != null) ...[
          const SizedBox(height: JiraniSpace.s),
          TitledCard(
            key: const ValueKey('cp-bank'),
            icon: Icons.account_balance_rounded,
            tone: JiraniTone.info,
            title: l.cpBank,
            children: [
              InfoRow(l.cpBankName, Text(bankNames[account.bank] ?? account.bank)),
              InfoRow(l.cpAccount, Flexible(child: Text(
                  '${account.accountName} ••••${account.last4}', textAlign: TextAlign.end))),
              if (account.paybill.isNotEmpty) InfoRow(l.cpPaybill, Text(account.paybill)),
              if (account.till.isNotEmpty) InfoRow(l.cpTill, Text(account.till)),
              InfoRow(l.cpMandate, Text(c.mandateSafe ? l.cpMandateOk : l.cpMandateMissing)),
              Align(alignment: Alignment.centerLeft, child: TextButton(
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => MandateScreen(chama: c))),
                  child: Text(l.cpSeeMandate))),
            ],
          ),
        ],
        if (c.statementInbox != null) ...[
          const SizedBox(height: JiraniSpace.s),
          TitledCard(
            icon: Icons.mark_email_read_outlined,
            tone: JiraniTone.info,
            title: l.cpInbox,
            subtitle: l.cpInboxBody,
            children: [
              Row(children: [
                Expanded(child: SelectableText(c.statementInbox!, style: text.titleSmall)),
                IconButton(
                  key: const ValueKey('copy-inbox'),
                  tooltip: l.cpCopy,
                  icon: const Icon(Icons.copy_rounded),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: c.statementInbox!));
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l.copied(c.statementInbox!))));
                  },
                ),
              ]),
            ],
          ),
        ],
        const SizedBox(height: JiraniSpace.s),
        TitledCard(
          icon: Icons.badge_outlined,
          tone: JiraniTone.brand,
          title: l.cpOfficials,
          children: [
            for (final o in officials)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Avatar(o.name, size: 36),
                title: Text(o.name),
                subtitle: Text(o.memberCode),
                trailing: StatusPill(roleLabel(l, o.role), tone: JiraniTone.brand),
              ),
          ],
        ),
      ]),
    );
  }
}

/// One record, fully: what it is, the amounts, who and when, its receipt (to copy), its
/// place in the chain and fingerprint, whether this phone checked it, what the rules
/// decided, and the way to dispute it.
class RecordDetailScreen extends ConsumerWidget {
  const RecordDetailScreen({super.key, required this.chamaId, required this.item});

  final String chamaId;
  final LedgerItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final i = item;
    final flow = flowOf(i.type);
    final chain = ref.watch(chainCheckProvider(chamaId)).value;
    final checked = chain != null && chain.ok && i.seq <= chain.entries;
    final at = i.document['at'] as String?;
    final decision = i.decision.entries
        .where((e) => e.value != null && e.value is! Map && e.value is! List)
        .toList();
    Widget mono(String s) => SelectableText(s, style: text.bodySmall
        ?.copyWith(fontFamily: 'monospace'));
    return Scaffold(
      appBar: AppBar(title: Text(l.rdTitle('${i.seq}'))),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        SurfaceCard(
          child: Row(children: [
            flow == MoneyFlow.other
                ? const ToneIcon(Icons.receipt_long_outlined, size: 52)
                : FlowArrow(flow, size: 52),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(entryLabelOf(l, i.type, i.decision), style: text.titleLarge),
              if (i.amount.cents != 0)
                MoneyText(i.amount.cents < 0 ? -i.amount : i.amount,
                    style: text.headlineSmall),
            ])),
          ]),
        ),
        const SizedBox(height: JiraniSpace.s),
        Notice(key: const ValueKey('rd-checked'),
            checked ? l.rdChecked : l.rdNotChecked,
            tone: checked ? NoticeTone.good : NoticeTone.info),
        const SizedBox(height: JiraniSpace.s),
        TitledCard(
          icon: Icons.info_outline_rounded,
          tone: JiraniTone.neutral,
          title: l.rdWhat,
          children: [
            if (i.memberCode != null) InfoRow(l.verMember, Text(i.memberCode!)),
            if (i.period != null) InfoRow(l.rdPeriod, Text(i.period!)),
            if (at != null) InfoRow(l.rdWhen, Text(at.substring(0, 16).replaceFirst('T', ' '))),
            InfoRow(l.verRecordNo, Text('#${i.seq}')),
            Row(children: [
              Expanded(child: InfoRow(l.rdReceipt, Text(i.receiptCode))),
              IconButton(
                key: const ValueKey('copy-receipt'),
                tooltip: l.cpCopy,
                icon: const Icon(Icons.copy_rounded, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: i.receiptCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l.copied(i.receiptCode))));
                },
              ),
            ]),
            Text(l.rdReceiptHint(i.receiptCode), style: text.bodySmall),
          ],
        ),
        if (decision.isNotEmpty) ...[
          const SizedBox(height: JiraniSpace.s),
          TitledCard(
            icon: Icons.rule_rounded,
            tone: JiraniTone.info,
            title: l.rdDecided,
            children: [
              for (final e in decision)
                InfoRow(e.key.replaceAll('_', ' '), Flexible(child: Text('${e.value}',
                    textAlign: TextAlign.end, maxLines: 3, overflow: TextOverflow.ellipsis))),
            ],
          ),
        ],
        const SizedBox(height: JiraniSpace.s),
        TitledCard(
          icon: Icons.link_rounded,
          tone: JiraniTone.good,
          title: l.rdChain,
          subtitle: l.rdChainBody,
          children: [
            Text(l.rdFingerprint, style: text.labelLarge),
            mono(i.hash),
            const SizedBox(height: 8),
            Text(l.rdPrevious, style: text.labelLarge),
            mono('${i.document['prev_hash'] ?? ''}'),
            const SizedBox(height: 8),
            Text(i.signature == null ? l.rdUnsigned : l.rdSigned, style: text.bodySmall),
          ],
        ),
        const SizedBox(height: JiraniSpace.m),
        OutlinedButton.icon(
          key: const ValueKey('rd-dispute'),
          icon: const Icon(Icons.report_gmailerrorred_outlined),
          label: Text(l.rdDispute),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => RaiseDisputeScreen(chamaId: chamaId, subjectType: 'entry',
                  subjectId: i.id))),
        ),
      ]),
    );
  }
}
