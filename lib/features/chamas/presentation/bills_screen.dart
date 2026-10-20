import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';

final billsProvider = FutureProvider.autoDispose.family<Json, String>(
    (ref, chamaId) => ref.watch(chamaRepositoryProvider).bills(chamaId));

/// What the chama pays JiraniChama (owner decisions 2026-10-20): about USD 0.10 per active
/// member a month, free for the first three months and for five members or fewer. Every
/// member sees it, like every other payment.
class BillsScreen extends ConsumerWidget {
  const BillsScreen({super.key, required this.chama});

  final Chama chama;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final data = ref.watch(billsProvider(chama.id));
    return Scaffold(
      appBar: AppBar(title: Text(l.billTitle)),
      body: data.when(
        loading: () => const LoadingView(),
        error: (e, _) => ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
          Notice(problemText(l, e), tone: NoticeTone.critical),
        ]),
        data: (d) {
          final now = d['this_month'] as Json;
          final pricing = d['pricing'] as Json;
          final bills = [for (final b in d['bills'] as List) b as Json];
          final payTo = d['pay_to'] as Json? ?? const {};
          String money(Object? c) => Kes((c as num?)?.toInt() ?? 0).format();
          final free = '${now['free_reason']}';
          return ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
            HeroCard(
              label: l.billThisMonth('${now['period']}'),
              value: Text(money(now['total_cents']), key: const ValueKey('bill-now'),
                  style: text.displaySmall?.copyWith(color: Colors.white)),
              children: [
                Text(l.billLine('${now['active_members']}', money(now['price_per_member_cents'])),
                    style: text.bodyMedium?.copyWith(color: Colors.white70)),
                if (free.isNotEmpty) ...[
                  const SizedBox(height: JiraniSpace.s),
                  StatusPill(free == 'trial' ? l.billFreeTrial : l.billFreeSmall,
                      tone: JiraniTone.good, icon: Icons.celebration_outlined),
                ],
              ],
            ),
            const SizedBox(height: JiraniSpace.m),
            Notice(l.billHow('${pricing['free_up_to_members']}', '${pricing['free_months']}')),
            const SizedBox(height: JiraniSpace.s),
            Notice(
                '${payTo['paybill'] ?? ''}'.isEmpty
                    ? l.billPayLater
                    : l.billPayTo('${payTo['account_prefix']}'
                        '${chama.json['member_code_prefix'] ?? ''}', '${payTo['paybill']}'),
                tone: NoticeTone.info),
            const SizedBox(height: JiraniSpace.m),
            TitledCard(
              icon: Icons.receipt_long_outlined,
              title: l.billPast,
              children: [
                if (bills.isEmpty) Text(l.billNone, style: text.bodySmall),
                for (final b in bills)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${b['period']}'),
                    subtitle: Text(l.billLine('${b['active_members']}',
                        money(b['price_per_member_cents']))),
                    trailing: Column(mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(money(b['total_cents']), style: text.titleSmall),
                      const SizedBox(height: 4),
                      StatusPill(switch ('${b['state']}') {
                        'paid' => l.billPaid,
                        'free' => l.billFree,
                        'waived' => l.billWaived,
                        _ => l.billDue('${b['due_on']}'),
                      }, tone: switch ('${b['state']}') {
                        'open' => JiraniTone.warning,
                        _ => JiraniTone.good,
                      }),
                    ]),
                  ),
              ],
            ),
          ]);
        },
      ),
    );
  }
}
