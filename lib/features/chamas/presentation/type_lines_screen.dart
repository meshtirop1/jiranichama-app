import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/api/api_client.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';

/// Type in the statement lines the bank's file had but we could not read (5.5). The
/// official copies them from the bank's own copy; the API only accepts them if the whole
/// statement then adds up, and a different official confirms afterwards.
class TypeLinesScreen extends ConsumerStatefulWidget {
  const TypeLinesScreen({super.key, required this.statement});

  final Statement statement;

  @override
  ConsumerState<TypeLinesScreen> createState() => _TypeLinesScreenState();
}

class _Row {
  _Row(UnreadableRow row)
      : date = TextEditingController(),
        amount = TextEditingController(),
        narration = TextEditingController(text: row.likelyNarration),
        reference = TextEditingController(),
        balance = TextEditingController();

  final TextEditingController date, amount, narration, reference, balance;
  bool moneyIn = true;

  void dispose() {
    for (final c in [date, amount, narration, reference, balance]) {
      c.dispose();
    }
  }
}

/// "1,234.50" or "1234" to cents; null when it is not an amount.
int? _cents(String raw) {
  final s = raw.replaceAll(',', '').replaceAll(' ', '').trim();
  if (s.isEmpty) return null;
  final m = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(s);
  if (m == null) return null;
  final part = (m.group(2) ?? '').padRight(2, '0');
  return int.parse(m.group(1)!) * 100 + (part.isEmpty ? 0 : int.parse(part));
}

class _TypeLinesScreenState extends ConsumerState<TypeLinesScreen> {
  late final Map<int, _Row> _rows = {
    for (final u in widget.statement.unreadableLines) u.lineNo: _Row(u),
  };
  final _key = newIdempotencyKey();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final r in _rows.values) {
      r.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(_Row row) async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, firstDate: DateTime(now.year - 2),
        lastDate: now, initialDate: DateTime.tryParse(row.date.text) ?? now);
    if (picked != null) {
      setState(() => row.date.text = picked.toIso8601String().substring(0, 10));
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final lines = <Json>[];
    for (final MapEntry(key: lineNo, value: r) in _rows.entries) {
      final amount = _cents(r.amount.text);
      final date = DateTime.tryParse(r.date.text.trim());
      if (amount == null || amount == 0 || date == null) {
        setState(() => _error = l.errTypedInvalid);
        return;
      }
      lines.add({
        'line_no': lineNo,
        'value_date': r.date.text.trim(),
        'narration': r.narration.text.trim(),
        'reference': r.reference.text.trim(),
        'credit_cents': r.moneyIn ? amount : 0,
        'debit_cents': r.moneyIn ? 0 : amount,
        'balance_cents': _cents(r.balance.text),
      });
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(chamaRepositoryProvider)
          .submitTypedLines(widget.statement.id, lines, idempotencyKey: _key);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l.typeLinesTitle)),
      bottomNavigationBar: ActionBar(
          child: PrimaryButton(label: l.saveTypedLines, busy: _busy, onPressed: _save)),
      body: ListView(
        padding: const EdgeInsets.all(JiraniSpace.m),
        children: [
          Notice(l.typeLinesIntro),
          if (_error != null) ...[
            const SizedBox(height: JiraniSpace.s),
            Notice(_error!, tone: NoticeTone.critical),
          ],
          for (final u in widget.statement.unreadableLines) ...[
            const SizedBox(height: JiraniSpace.m),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(JiraniSpace.m),
                child: _rowForm(l, text, u, _rows[u.lineNo]!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _rowForm(AppLocalizations l, TextTheme text, UnreadableRow u, _Row r) {
    final n = u.lineNo;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(l.lineInFile('$n'), style: text.titleSmall),
      const SizedBox(height: JiraniSpace.xs),
      // What the file had, so the official can find the line on the bank's copy.
      Text(u.cells.where((c) => c.isNotEmpty).join('  |  '),
          style: text.bodySmall?.copyWith(fontFamily: 'monospace')),
      const SizedBox(height: JiraniSpace.s),
      TextField(
        key: ValueKey('date-$n'),
        controller: r.date,
        keyboardType: TextInputType.datetime,
        decoration: InputDecoration(
          labelText: l.dateLabel,
          suffixIcon: IconButton(icon: const Icon(Icons.calendar_today_outlined),
              onPressed: () => _pickDate(r)),
        ),
      ),
      const SizedBox(height: JiraniSpace.s),
      SegmentedButton<bool>(
        key: ValueKey('direction-$n'),
        segments: [
          ButtonSegment(value: true, label: Text(l.moneyIn)),
          ButtonSegment(value: false, label: Text(l.moneyOut)),
        ],
        selected: {r.moneyIn},
        showSelectedIcon: false,
        onSelectionChanged: (s) => setState(() => r.moneyIn = s.first),
      ),
      const SizedBox(height: JiraniSpace.s),
      TextField(key: ValueKey('amount-$n'), controller: r.amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l.amountKesLabel)),
      const SizedBox(height: JiraniSpace.s),
      TextField(key: ValueKey('narration-$n'), controller: r.narration,
          decoration: InputDecoration(labelText: l.descriptionLabel)),
      const SizedBox(height: JiraniSpace.s),
      TextField(key: ValueKey('reference-$n'), controller: r.reference,
          decoration: InputDecoration(labelText: l.referenceOptional)),
      const SizedBox(height: JiraniSpace.s),
      TextField(key: ValueKey('balance-$n'), controller: r.balance,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: l.balanceOptional)),
    ]);
  }
}
