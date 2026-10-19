import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../../core/api/problem.dart';
import '../../../core/labels.dart';
import '../../../core/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/problem_text.dart';
import '../data/models.dart';
import '../../../core/api/api_client.dart';
import 'chama_screen.dart';
import 'rule_changes_screen.dart';

/// Every rule setting (schema v1), for the founder during setup. The API checks the whole
/// set (ranges and contradictions); its errors come back with a path and a stable code
/// and are shown next to the setting, in the member's language.
///
/// With [propose], an active chama's official edits a copy of the rules in force and
/// sends it, with a reason, as a rule change for the members' vote (5.10).
class RulesEditorScreen extends ConsumerWidget {
  const RulesEditorScreen({super.key, required this.chamaId, this.propose = false});

  final String chamaId;
  final bool propose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final bundle = ref.watch(chamaBundleProvider(chamaId));
    return bundle.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(appBar: AppBar(),
          body: Padding(padding: const EdgeInsets.all(JiraniSpace.m),
              child: Notice(problemText(l, e), tone: NoticeTone.critical))),
      data: (b) => _Editor(chamaId: chamaId, rules: b.rules.rules, propose: propose),
    );
  }
}

class _Tier {
  _Tier(Json t)
      : upTo = TextEditingController(
            text: t['up_to_cents'] == null ? '' : '${(t['up_to_cents'] as int) ~/ 100}'),
        officials = t['officials'] as int,
        vote = t['member_vote'] as bool;

  final TextEditingController upTo;
  int officials;
  bool vote;
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.chamaId, required this.rules, required this.propose});

  final String chamaId;
  final Json rules;
  final bool propose;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

String _kes(int? cents) => cents == null ? '' : '${cents ~/ 100}';

class _EditorState extends ConsumerState<_Editor> {
  late final Json _r = jsonDecode(jsonEncode(widget.rules)) as Json;
  Json get _c => _r['contributions'] as Json;
  Json get _fine => (_r['fines'] as Json)['late_contribution'] as Json;

  late final _amount = TextEditingController(text: _kes(_c['amount_cents'] as int));
  late final _dueDay = TextEditingController(text: '${_c['due_day']}');
  late final _grace = TextEditingController(text: '${_c['grace_days']}');
  late final _cashDays = TextEditingController(text: '${_c['cash_banking_days'] ?? 3}');
  late List<String> _order = List<String>.from(_c['allocation_order'] as List);

  late bool _fineOn = _fine['enabled'] as bool;
  late final _fineAmount = TextEditingController(text: _kes(_fine['amount_cents'] as int));
  late final _fineCap = TextEditingController(text: _kes(_fine['monthly_cap_cents'] as int?));

  late final Set<String> _roles =
      Set<String>.from((_r['officials'] as Json)['roles'] as List);

  late final List<_Tier> _tiers = [
    for (final t in (_r['approvals'] as Json)['tiers'] as List) _Tier(t as Json),
  ];
  late final _deadline = TextEditingController(
      text: '${(_r['approvals'] as Json)['deadline_hours']}');

  late final _entryFee = TextEditingController(
      text: _kes((_r['membership'] as Json)['entry_fee_cents'] as int));
  late bool _newMemberVote = (_r['membership'] as Json)['new_members_need_vote'] as bool;
  late final _share = TextEditingController(
      text: '${(_r['adoption'] as Json)['members_share_pct']}');
  late final _everyDays = TextEditingController(
      text: '${(_r['statements'] as Json)['every_days']}');
  late String _kycPayer = (_r['kyc'] as Json)['payer'] as String;
  Json get _mt => {'absence_fine_cents': 0, 'late_fine_cents': 0, 'late_after_minutes': 15,
        'apology_excuses': true, 'objection_days': 7, ...?(_r['meetings'] as Json?)};
  late final _absenceFine = TextEditingController(text: _kes(_mt['absence_fine_cents'] as int));
  late final _lateFine = TextEditingController(text: _kes(_mt['late_fine_cents'] as int));
  late final _lateAfter = TextEditingController(text: '${_mt['late_after_minutes']}');
  late final _objectionDays = TextEditingController(text: '${_mt['objection_days']}');
  late bool _apologyExcuses = _mt['apology_excuses'] as bool;
  late String? _rotOrder = (_r['rotation'] as Json?)?['order'] as String?;
  late String? _rotArrears = (_r['rotation'] as Json?)?['arrears'] as String?;

  final _reason = TextEditingController();
  final _key = newIdempotencyKey();
  Map<String, String> _errors = {};
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_amount, _dueDay, _grace, _cashDays, _fineAmount, _fineCap, _deadline,
      _entryFee, _share, _everyDays, _reason, _absenceFine, _lateFine, _lateAfter,
      _objectionDays, for (final t in _tiers) t.upTo]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Whole numbers only; anything else is sent as -1 so the API names the setting.
  int _int(TextEditingController c) => int.tryParse(c.text.trim().replaceAll(',', '')) ?? -1;
  int _cents(TextEditingController c) {
    final v = _int(c);
    return v < 0 ? -1 : Kes.shillings(v).cents;
  }

  Json _collect() => {
        ..._r,
        'contributions': {
          ..._c,
          'amount_cents': _cents(_amount),
          'due_day': _int(_dueDay),
          'grace_days': _int(_grace),
          'cash_banking_days': _int(_cashDays),
          'allocation_order': _order,
        },
        'fines': {
          'late_contribution': {
            'enabled': _fineOn,
            'amount_cents': _fineOn ? _cents(_fineAmount) : 0,
            'monthly_cap_cents': _fineCap.text.trim().isEmpty ? null : _cents(_fineCap),
          },
        },
        'officials': {
          'roles': [for (final r in const ['chair', 'treasurer', 'secretary'])
            if (_roles.contains(r)) r],
        },
        'approvals': {
          'tiers': [
            for (var i = 0; i < _tiers.length; i++)
              {
                'up_to_cents': i == _tiers.length - 1 ? null : _cents(_tiers[i].upTo),
                'officials': _tiers[i].officials,
                'member_vote': _tiers[i].vote,
              },
          ],
          'deadline_hours': _int(_deadline),
        },
        'membership': {
          'entry_fee_cents': _cents(_entryFee),
          'new_members_need_vote': _newMemberVote,
        },
        'adoption': {'members_share_pct': _int(_share)},
        'statements': {'every_days': _int(_everyDays)},
        'kyc': {'payer': _kycPayer},
        if (_rotOrder != null) 'rotation': {'order': _rotOrder, 'arrears': _rotArrears},
        'meetings': {
          'absence_fine_cents': _cents(_absenceFine),
          'late_fine_cents': _cents(_lateFine),
          'late_after_minutes': _int(_lateAfter),
          'apology_excuses': _apologyExcuses,
          'objection_days': _int(_objectionDays),
        },
      };

  String _ruleMessage(AppLocalizations l, String code) => switch (code) {
        'tiers_last_unlimited' => l.ruleTiersLastUnlimited,
        'tiers_only_last_unlimited' => l.ruleTiersOnlyLast,
        'tiers_order' => l.ruleTiersOrder,
        'tiers_officials_order' => l.ruleTiersOfficialsOrder,
        'tiers_too_many_officials' => l.ruleTiersTooMany,
        'fine_needs_amount' => l.ruleFineNeedsAmount,
        'fine_cap_below_fine' => l.ruleFineCapBelow,
        _ => l.ruleOutOfRange,
      };

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
      _errors = {};
    });
    try {
      final repo = ref.read(chamaRepositoryProvider);
      if (widget.propose) {
        final p = await repo.proposeRules(widget.chamaId, _collect(),
            reason: _reason.text.trim(), idempotencyKey: _key);
        ref.invalidate(ruleProposalsProvider(widget.chamaId));
        if (mounted) {
          Navigator.of(context).pushReplacement(MaterialPageRoute(
              builder: (_) => RuleProposalScreen(chamaId: widget.chamaId, proposalId: p.id)));
        }
        return;
      }
      await repo.saveRules(widget.chamaId, _collect());
      ref.invalidate(chamaBundleProvider(widget.chamaId));
      if (mounted) Navigator.of(context).pop(true);
    } on ApiProblem catch (e) {
      final errors = <String, String>{};
      for (final raw in e.extra['errors'] as List? ?? const []) {
        final err = raw as Map;
        errors[err['path'] as String] = _ruleMessage(l, err['code'] as String? ?? '');
      }
      if (mounted) {
        setState(() {
          _errors = errors;
          _error = problemText(l, e);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// The error for a setting, or for anything under it ("approvals/tiers" covers each tier).
  String? _err(String path) => _errors[path];
  List<String> _errsUnder(String prefix) =>
      [for (final e in _errors.entries) if (e.key == prefix) e.value];

  Widget _number(String key, TextEditingController c, String label, String path,
          {String? help}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: JiraniSpace.s),
        child: TextField(
          key: ValueKey(key),
          controller: c,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: label, helperText: help, errorText: _err(path),
              helperMaxLines: 3, errorMaxLines: 3),
        ),
      );

  Widget _section(String title, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(JiraniSpace.m),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: JiraniSpace.s),
            ...children,
          ]),
        ),
      );

  String _allocLabel(AppLocalizations l, String k) => switch (k) {
        'arrears' => l.allocArrears,
        'fines' => l.allocFines,
        _ => l.allocCurrent,
      };

  void _move(int i, int by) => setState(() {
        final list = [..._order];
        final item = list.removeAt(i);
        list.insert(i + by, item);
        _order = list;
      });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final errorBox = Theme.of(context).colorScheme.error;
    Widget errorsFor(String path) => Column(children: [
          for (final m in _errsUnder(path))
            Padding(padding: const EdgeInsets.only(bottom: JiraniSpace.xs),
                child: Text(m, style: TextStyle(color: errorBox))),
        ]);

    return Scaffold(
      appBar: AppBar(title: Text(widget.propose ? l.proposeRuleChange : l.rulesEditorTitle)),
      bottomNavigationBar: ActionBar(child: PrimaryButton(
          label: widget.propose ? l.sendRuleChange : l.saveRules, busy: _busy,
          onPressed: _save)),
      body: ListView(
        padding: const EdgeInsets.all(JiraniSpace.m),
        children: [
          Notice(widget.propose ? l.proposeRuleChangeIntro : l.rulesEditorIntro),
          if (widget.propose)
            Padding(
              padding: const EdgeInsets.only(top: JiraniSpace.s),
              child: TextField(key: const ValueKey('rule-change-reason'), controller: _reason,
                  maxLength: 500, maxLines: 2,
                  decoration: InputDecoration(labelText: l.ruleChangeReason)),
            ),
          if (_error != null) ...[
            const SizedBox(height: JiraniSpace.s),
            Notice(_error!, tone: NoticeTone.critical),
          ],
          const SizedBox(height: JiraniSpace.s),
          _section(l.secContributions, [
            Text(l.frequencyMonthly),
            const SizedBox(height: JiraniSpace.s),
            _number('amount', _amount, l.amountLabel, 'contributions/amount_cents'),
            _number('due_day', _dueDay, l.dueDayLabel, 'contributions/due_day'),
            _number('grace_days', _grace, l.graceLabel, 'contributions/grace_days'),
            _number('cash_days', _cashDays, l.cashBankingDaysLabel,
                'contributions/cash_banking_days'),
            Text(l.allocationTitle, style: Theme.of(context).textTheme.titleSmall),
            for (var i = 0; i < _order.length; i++)
              ListTile(
                key: ValueKey('alloc-${_order[i]}'),
                contentPadding: EdgeInsets.zero,
                leading: Text('${i + 1}.'),
                title: Text(_allocLabel(l, _order[i])),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  IconButton(tooltip: l.moveUp, icon: const Icon(Icons.arrow_upward),
                      onPressed: i == 0 ? null : () => _move(i, -1)),
                  IconButton(tooltip: l.moveDown, icon: const Icon(Icons.arrow_downward),
                      onPressed: i == _order.length - 1 ? null : () => _move(i, 1)),
                ]),
              ),
          ]),
          _section(l.secLateFine, [
            SwitchListTile(
              key: const ValueKey('fine_on'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.lateFineOn),
              value: _fineOn,
              onChanged: (v) => setState(() => _fineOn = v),
            ),
            if (_fineOn) ...[
              _number('fine_amount', _fineAmount, l.fineAmountLabel,
                  'fines/late_contribution/amount_cents'),
              _number('fine_cap', _fineCap, l.fineCapLabel,
                  'fines/late_contribution/monthly_cap_cents'),
            ],
          ]),
          _section(l.secOfficials, [
            Text(l.officialsHelp),
            for (final role in const ['chair', 'treasurer', 'secretary'])
              CheckboxListTile(
                key: ValueKey('role-$role'),
                contentPadding: EdgeInsets.zero,
                title: Text(roleLabel(l, role)),
                value: _roles.contains(role),
                onChanged: (v) => setState(() => v == true ? _roles.add(role) : _roles.remove(role)),
              ),
            errorsFor('officials/roles'),
          ]),
          _section(l.secApprovals, [
            Text(l.approvalsPhase2, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: JiraniSpace.s),
            errorsFor('approvals/tiers'),
            for (var i = 0; i < _tiers.length; i++) _tierCard(l, i),
            if (_tiers.length < 4)
              TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l.addTier),
                onPressed: () => setState(() {
                  final last = _tiers.last;
                  _tiers.insert(_tiers.length - 1, _Tier({
                    'up_to_cents': null, 'officials': last.officials, 'member_vote': false}));
                }),
              ),
            _number('deadline', _deadline, l.deadlineHoursLabel, 'approvals/deadline_hours'),
          ]),
          _section(l.secMembership, [
            _number('entry_fee', _entryFee, l.entryFeeLabel, 'membership/entry_fee_cents'),
            SwitchListTile(
              key: const ValueKey('new_member_vote'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.newMembersVote),
              value: _newMemberVote,
              onChanged: (v) => setState(() => _newMemberVote = v),
            ),
          ]),
          _section(l.secAdoption, [
            _number('share', _share, l.membersSharePct, 'adoption/members_share_pct'),
          ]),
          _section(l.statements, [
            _number('every_days', _everyDays, l.statementEveryDays, 'statements/every_days'),
          ]),
          if (_rotOrder != null)
            _section(l.merryGoRound, [
              Text(l.rotationOrderLabel, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: JiraniSpace.xs),
              SegmentedButton<String>(
                key: const ValueKey('rotation-order'),
                segments: [
                  ButtonSegment(value: 'draw', label: Text(l.orderDraw)),
                  ButtonSegment(value: 'fixed', label: Text(l.orderFixed)),
                ],
                selected: {_rotOrder!},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _rotOrder = s.first),
              ),
              const SizedBox(height: JiraniSpace.s),
              Text(l.arrearsLabel, style: Theme.of(context).textTheme.titleSmall),
              RadioGroup<String>(
                groupValue: _rotArrears,
                onChanged: (v) => setState(() => _rotArrears = v ?? _rotArrears),
                child: Column(children: [
                  RadioListTile(key: const ValueKey('arrears-skip'), value: 'skip',
                      contentPadding: EdgeInsets.zero, title: Text(l.arrearsSkip)),
                  RadioListTile(key: const ValueKey('arrears-deduct'), value: 'deduct',
                      contentPadding: EdgeInsets.zero, title: Text(l.arrearsDeduct)),
                  RadioListTile(key: const ValueKey('arrears-block'), value: 'block',
                      contentPadding: EdgeInsets.zero, title: Text(l.arrearsBlock)),
                ]),
              ),
            ]),
          _section(l.rulesMeetings, [
            _number('absence_fine', _absenceFine, l.rulesAbsenceFine,
                'meetings/absence_fine_cents'),
            _number('late_fine', _lateFine, l.rulesLateFine, 'meetings/late_fine_cents'),
            _number('late_after', _lateAfter, l.rulesLateAfter, 'meetings/late_after_minutes'),
            SwitchListTile(
              key: const ValueKey('apology_excuses'),
              contentPadding: EdgeInsets.zero,
              title: Text(l.rulesApologyExcuses),
              value: _apologyExcuses,
              onChanged: (v) => setState(() => _apologyExcuses = v),
            ),
            _number('objection_days', _objectionDays, l.rulesObjectionDays,
                'meetings/objection_days'),
          ]),
          _section(l.secKyc, [
            SegmentedButton<String>(
              key: const ValueKey('kyc'),
              segments: [
                ButtonSegment(value: 'chama', label: Text(l.kycPayerChama)),
                ButtonSegment(value: 'member', label: Text(l.kycPayerMember)),
              ],
              selected: {_kycPayer},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _kycPayer = s.first),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _tierCard(AppLocalizations l, int i) {
    final t = _tiers[i];
    final last = i == _tiers.length - 1;
    return Card(
      key: ValueKey('tier-$i'),
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(JiraniSpace.s),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (last)
            Text(l.tierAnyAmount, style: Theme.of(context).textTheme.titleSmall)
          else
            _number('tier-$i-upto', t.upTo, l.tierUpTo, 'approvals/tiers/$i/up_to_cents'),
          Row(children: [
            Expanded(child: Text(l.tierOfficials('${t.officials}'))),
            IconButton(
                key: ValueKey('tier-$i-less'),
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: t.officials <= 1 ? null : () => setState(() => t.officials--)),
            IconButton(
                key: ValueKey('tier-$i-more'),
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => setState(() => t.officials++)),
          ]),
          if (_err('approvals/tiers/$i/officials') != null)
            Text(_err('approvals/tiers/$i/officials')!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.tierMemberVote),
            value: t.vote,
            onChanged: (v) => setState(() => t.vote = v),
          ),
          if (!last && _tiers.length > 1)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _tiers.removeAt(i).upTo.dispose()),
                child: Text(l.removeTier),
              ),
            ),
        ]),
      ),
    );
  }
}
