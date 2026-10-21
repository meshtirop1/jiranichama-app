import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../l10n/app_localizations.dart';
import '../auth/presentation/problem_text.dart';
import 'automation_repository.dart';
import 'models.dart';

/// What the member should pay now (months behind, fines and the month falling due), and,
/// where the chama's own paybill allows it, Pay now: the M-Pesa PIN prompt on their phone.
class PayNowCard extends ConsumerWidget {
  const PayNowCard({super.key, required this.chamaId, this.onPaid});

  final String chamaId;
  final VoidCallback? onPaid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final info = ref.watch(payInfoProvider(chamaId)).value;
    if (info == null || info.total.cents <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: JiraniSpace.m),
      child: SurfaceCard(
        key: const ValueKey('pay-now-card'),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            const ToneIcon(Icons.event_rounded, tone: JiraniTone.warning, size: 38),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.payDueNow, style: text.bodyMedium),
              MoneyText(info.total, style: text.titleLarge),
            ])),
          ]),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (info.arrears.cents > 0) FigureChip(l.arrears, info.arrears.format()),
            if (info.fines.cents > 0) FigureChip(l.finesOwed, info.fines.format()),
            if (info.current.cents > 0)
              FigureChip(info.dueOn == null ? l.payThisMonth : l.payDueOn(info.dueOn!),
                  info.current.format()),
          ]),
          if (info.payNow) ...[
            const SizedBox(height: 12),
            PrimaryButton(
              key: const ValueKey('pay-now'),
              label: l.payNowButton(info.total.format()),
              onPressed: () async {
                final paid = await showModalBottomSheet<bool>(
                    context: context, isScrollControlled: true, isDismissible: false,
                    builder: (_) => _PayNowSheet(chamaId: chamaId, amount: info.total.cents));
                ref.invalidate(payInfoProvider(chamaId));
                if (paid == true) onPaid?.call();
              },
            ),
          ],
        ]),
      ),
    );
  }
}

/// Sends the prompt, then waits for Safaricom's answer (up to two minutes).
class _PayNowSheet extends ConsumerStatefulWidget {
  const _PayNowSheet({required this.chamaId, required this.amount});

  final String chamaId;
  final int amount;

  @override
  ConsumerState<_PayNowSheet> createState() => _PayNowSheetState();
}

class _PayNowSheetState extends ConsumerState<_PayNowSheet> {
  PayRequest? _req;
  String? _error;
  Timer? _timer;
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    _send();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    final repo = ref.read(automationRepositoryProvider);
    try {
      final req = await repo.payNow(widget.chamaId, amountCents: widget.amount);
      if (!mounted) return;
      setState(() => _req = req);
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _check());
    } catch (e) {
      if (mounted) setState(() => _error = problemText(AppLocalizations.of(context), e));
    }
  }

  Future<void> _check() async {
    final req = _req;
    if (req == null) return;
    _ticks++;
    try {
      final now = await ref.read(automationRepositoryProvider).payStatus(req.id);
      if (!mounted) return;
      setState(() => _req = now);
      if (now.state != 'sent' || _ticks >= 40) _timer?.cancel();
    } catch (_) {
      if (_ticks >= 40) _timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final req = _req;
    final done = _error != null || (req != null && req.state != 'sent') || _ticks >= 40;
    final (String msg, NoticeTone tone) = switch (req?.state) {
      _ when _error != null => (_error!, NoticeTone.critical),
      null => (l.paySending, NoticeTone.info),
      'paid' => (l.payPaid(req!.receipt), NoticeTone.good),
      'failed' || 'refused' => (l.payFailed, NoticeTone.warning),
      _ when _ticks >= 40 => (l.payNoAnswer, NoticeTone.warning),
      _ => (l.payCheckPhone(req!.phoneHint), NoticeTone.info),
    };
    return Padding(
      padding: const EdgeInsets.all(JiraniSpace.m),
      child: Column(mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text(l.payNowTitle, style: text.titleLarge),
        const SizedBox(height: JiraniSpace.m),
        if (!done) const Center(child: BrandLoader(size: 64)),
        if (!done) const SizedBox(height: JiraniSpace.m),
        Notice(msg, tone: tone),
        const SizedBox(height: JiraniSpace.m),
        if (done)
          PrimaryButton(key: const ValueKey('pay-now-done'), label: l.payClose,
              onPressed: () => Navigator.of(context).pop(req?.state == 'paid')),
      ]),
    );
  }
}

/// "Should payments from that number always count for you?" (smart matching): asked
/// once, after the treasurer counted a payment from someone else's phone for this member.
class PayerLinkQuestion extends ConsumerStatefulWidget {
  const PayerLinkQuestion({super.key, required this.chamaId, required this.myId});

  final String chamaId;
  final String? myId;

  @override
  ConsumerState<PayerLinkQuestion> createState() => _PayerLinkQuestionState();
}

class _PayerLinkQuestionState extends ConsumerState<PayerLinkQuestion> {
  bool _busy = false;

  Future<void> _answer(PayerLink link, bool yes) async {
    final l = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(automationRepositoryProvider).answerPayerLink(link.id, yes: yes);
      ref.invalidate(payerLinksProvider(widget.chamaId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(problemText(l, e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final links = (ref.watch(payerLinksProvider(widget.chamaId)).value ?? const [])
        .where((x) => x.state == 'suggested' && x.membershipId == widget.myId).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final link in links)
        Padding(
          padding: const EdgeInsets.only(top: JiraniSpace.s),
          child: TitledCard(
            key: ValueKey('payer-${link.id}'),
            icon: Icons.phone_android_rounded,
            tone: JiraniTone.info,
            title: l.payerTitle,
            subtitle: link.fromAmount == null ? l.payerBody
                : l.payerBodyAmount(link.fromAmount!.format()),
            children: [
              Row(children: [
                Expanded(child: OutlinedButton(
                    key: ValueKey('payer-no-${link.id}'),
                    onPressed: _busy ? null : () => _answer(link, false),
                    child: Text(l.payerNo))),
                const SizedBox(width: 8),
                Expanded(child: FilledButton(
                    key: ValueKey('payer-yes-${link.id}'),
                    onPressed: _busy ? null : () => _answer(link, true),
                    child: Text(l.payerYes))),
              ]),
            ],
          ),
        ),
    ]);
  }
}
