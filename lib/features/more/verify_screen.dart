import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../core/labels.dart';
import '../automation/automation_repository.dart';
import '../chamas/presentation/records_tab.dart';

/// Is this genuine? A statement's 10-character check code is checked with JiraniChama; a
/// record's 8-character receipt is looked up in this chama's records on this phone (which
/// the phone has checked itself).
class VerifyScreen extends ConsumerStatefulWidget {
  const VerifyScreen({super.key, this.chamaId});

  final String? chamaId;

  @override
  ConsumerState<VerifyScreen> createState() => _VerifyScreenState();
}

class _VerifyScreenState extends ConsumerState<VerifyScreen> {
  final _code = TextEditingController();
  Widget? _result;
  bool _busy = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// Spaces and dashes never matter. A statement's check code is Crockford Base32, so O,
  /// I and L read as 0, 1 and 1 there; a receipt is plain Base32 and is kept as typed.
  String get _clean => _code.text.toUpperCase().replaceAll(RegExp(r'[\s\-]'), '');

  String _crockford(String c) =>
      c.replaceAll('O', '0').replaceAll('I', '1').replaceAll('L', '1');

  Future<void> _check() async {
    final l = AppLocalizations.of(context);
    final code = _clean;
    final small = Theme.of(context).textTheme.bodySmall;
    setState(() => _busy = true);
    Widget result;
    try {
      if (code.length == 10) {
        final d = await ref.read(automationRepositoryProvider)
            .verifyDocument(_crockford(code));
        final sealed = d['sealed'] == true;
        result = TitledCard(
          key: const ValueKey('verify-result'),
          icon: sealed ? Icons.verified_rounded : Icons.gpp_bad_outlined,
          tone: sealed ? JiraniTone.good : JiraniTone.critical,
          title: sealed ? l.verGenuine : l.verNotGenuine,
          children: [
            InfoRow(l.verChama, Flexible(child: Text('${d['chama_name']}',
                textAlign: TextAlign.end))),
            if (d['member_code'] != null) InfoRow(l.verMember, Text('${d['member_code']}')),
            InfoRow(l.verPeriod, Text('${d['period_from']} – ${d['period_to']}')),
            InfoRow(l.verIssued, Text('${d['issued_at']}'.substring(0, 10))),
            const SizedBox(height: 6),
            Text(l.verFingerprint('${d['fingerprint']}'.substring(0, 16)), style: small),
          ],
        );
      } else if (code.length == 8 && widget.chamaId != null) {
        final items = await ref.read(ledgerItemsProvider(widget.chamaId!).future);
        final hit = items.where((i) => i.receiptCode.toUpperCase() == code).firstOrNull;
        result = hit == null
            ? Notice(l.verReceiptMissing, tone: NoticeTone.warning,
                key: const ValueKey('verify-result'))
            : TitledCard(
                key: const ValueKey('verify-result'),
                icon: Icons.verified_rounded,
                tone: JiraniTone.good,
                title: l.verReceiptFound,
                children: [
                  InfoRow(l.verWhat, Flexible(child: Text(
                      entryLabelOf(l, hit.type, hit.decision), textAlign: TextAlign.end))),
                  if (hit.memberCode != null) InfoRow(l.verMember, Text(hit.memberCode!)),
                  InfoRow(l.verAmount, MoneyText(hit.amount)),
                  InfoRow(l.verRecordNo, Text('#${hit.seq}')),
                ],
              );
      } else {
        result = Notice(code.length == 8 ? l.verReceiptSms : l.verBadCode,
            tone: NoticeTone.warning, key: const ValueKey('verify-result'));
      }
    } catch (_) {
      result = Notice(l.verNotFound, tone: NoticeTone.critical,
          key: const ValueKey('verify-result'));
    }
    if (mounted) {
      setState(() {
        _result = result;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.verTitle)),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        Text(l.verIntro, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: JiraniSpace.m),
        TextField(
          key: const ValueKey('verify-code'),
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(labelText: l.verCodeLabel,
              prefixIcon: const Icon(Icons.qr_code_2_rounded)),
          onSubmitted: (_) => _check(),
        ),
        const SizedBox(height: JiraniSpace.s),
        PrimaryButton(key: const ValueKey('verify-check'), label: l.verCheck, busy: _busy,
            onPressed: _check),
        if (_result != null) ...[
          const SizedBox(height: JiraniSpace.m),
          _result!,
        ],
      ]),
    );
  }
}
