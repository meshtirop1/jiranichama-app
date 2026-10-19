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
import 'widgets/rule_book_list.dart';

/// Setup (5.1): bank account, the main rules, invites, then send the rules for
/// confirmation. Only the founder changes anything; others see the rules and wait.
class SetupView extends ConsumerStatefulWidget {
  const SetupView({super.key, required this.bundle, required this.onChanged});

  final ChamaBundle bundle;
  final VoidCallback onChanged;

  @override
  ConsumerState<SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends ConsumerState<SetupView> {
  // Bank account
  late String _bank = widget.bundle.chama.bankAccount?.bank ?? 'equity';
  late final _accountName =
      TextEditingController(text: widget.bundle.chama.bankAccount?.accountName ?? '');
  final _accountNo = TextEditingController();
  late final _paybill = TextEditingController(text: widget.bundle.chama.bankAccount?.paybill ?? '');
  late String _route = widget.bundle.chama.bankAccount?.statementRoute ?? 'bank_email';

  // Main rules
  late Json _rules = widget.bundle.rules.rules;
  late final _amount = TextEditingController(text: _shillings(_contrib['amount_cents'] as int));
  late final _dueDay = TextEditingController(text: '${_contrib['due_day']}');
  late final _grace = TextEditingController(text: '${_contrib['grace_days']}');
  late final _fine = TextEditingController(text: _shillings(_lateFine['amount_cents'] as int));

  // Invites
  String _inviteRole = 'treasurer';
  final _invitePhone = TextEditingController();
  Invite? _lastInvite;

  String? _error;
  String? _info;
  bool _busy = false;

  Json get _contrib => _rules['contributions'] as Json;
  Json get _lateFine => (_rules['fines'] as Json)['late_contribution'] as Json;
  static String _shillings(int cents) => (cents ~/ 100).toString();

  @override
  void didUpdateWidget(covariant SetupView old) {
    super.didUpdateWidget(old);
    // The full rules editor may have changed the main settings shown here.
    if (!identical(old.bundle.rules.rules, widget.bundle.rules.rules)) {
      _rules = widget.bundle.rules.rules;
      _amount.text = _shillings(_contrib['amount_cents'] as int);
      _dueDay.text = '${_contrib['due_day']}';
      _grace.text = '${_contrib['grace_days']}';
      _fine.text = _shillings(_lateFine['amount_cents'] as int);
    }
  }

  Future<void> _editAll() async {
    final saved = await context.push<bool>('/chamas/$_id/rules/edit');
    if (saved == true && mounted) {
      setState(() => _info = AppLocalizations.of(context).rulesSaved);
      widget.onChanged();
    }
  }

  @override
  void dispose() {
    for (final c in [_accountName, _accountNo, _paybill, _amount, _dueDay, _grace, _fine,
      _invitePhone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, {String? done}) async {
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
      if (mounted) setState(() => _info = done);
    } catch (e) {
      if (mounted) setState(() => _error = problemText(AppLocalizations.of(context), e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _id => widget.bundle.chama.id;

  Future<void> _saveBank() => _run(() async {
        await ref.read(chamaRepositoryProvider).setBankAccount(_id,
            bank: _bank, accountName: _accountName.text.trim(),
            accountNo: _accountNo.text.trim(), paybill: _paybill.text.trim(),
            statementRoute: _route);
        widget.onChanged();
      });

  Future<void> _saveRules(String done) => _run(() async {
        int whole(TextEditingController c) => int.tryParse(c.text.trim()) ?? -1;
        final rules = Map<String, dynamic>.from(_rules);
        rules['contributions'] = {
          ..._contrib,
          'amount_cents': Kes.shillings(whole(_amount)).cents,
          'due_day': whole(_dueDay),
          'grace_days': whole(_grace),
        };
        final fine = whole(_fine);
        rules['fines'] = {
          'late_contribution': {..._lateFine, 'enabled': fine > 0,
            'amount_cents': Kes.shillings(fine < 0 ? 0 : fine).cents},
        };
        await ref.read(chamaRepositoryProvider).saveRules(_id, rules);
        widget.onChanged();
      }, done: done);

  Future<void> _invite() => _run(() async {
        final inv = await ref.read(chamaRepositoryProvider)
            .invite(_id, role: _inviteRole, phone: _invitePhone.text.trim());
        _invitePhone.clear();
        setState(() => _lastInvite = inv);
      });

  Future<void> _submit() => _run(() async {
        await ref.read(chamaRepositoryProvider).submit(_id);
        widget.onChanged();
      });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final chama = widget.bundle.chama;
    final text = Theme.of(context).textTheme;
    final lang = Localizations.localeOf(context).languageCode;
    final account = chama.bankAccount;
    final founder = chama.iAmFounder;

    Widget section(String title, List<Widget> children) => Card(
          child: Padding(
            padding: const EdgeInsets.all(JiraniSpace.m),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(title, style: text.titleMedium),
              const SizedBox(height: JiraniSpace.m),
              ...children,
            ]),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(chama.name)),
      bottomNavigationBar: founder && chama.state == ChamaState.setup
          ? ActionBar(child: PrimaryButton(label: l.submitRules, busy: _busy, onPressed: _submit))
          : null,
      body: ListView(
        padding: const EdgeInsets.all(JiraniSpace.m),
        children: [
          Notice(!founder
              ? l.waitingFounder
              : chama.state == ChamaState.awaitingOfficials
                  ? l.waitingOfficials
                  : l.setupIntro),
          if (_error != null) ...[
            const SizedBox(height: JiraniSpace.s),
            Notice(_error!, tone: NoticeTone.critical),
          ],
          if (_info != null) ...[
            const SizedBox(height: JiraniSpace.s),
            Notice(_info!),
          ],
          const SizedBox(height: JiraniSpace.s),
          if (founder && chama.state == ChamaState.setup)
            section(l.bankSection, [
              if (account != null) ...[
                Text(l.bankSaved(bankNames[account.bank] ?? account.bank, account.last4)),
                const SizedBox(height: JiraniSpace.m),
              ],
              DropdownButtonFormField<String>(
                initialValue: _bank,
                decoration: InputDecoration(labelText: l.bankLabel),
                items: [
                  for (final e in bankNames.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setState(() => _bank = v ?? _bank),
              ),
              const SizedBox(height: JiraniSpace.s),
              TextField(controller: _accountName,
                  decoration: InputDecoration(labelText: l.accountNameLabel)),
              const SizedBox(height: JiraniSpace.s),
              TextField(controller: _accountNo, keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.accountNoLabel)),
              const SizedBox(height: JiraniSpace.s),
              TextField(controller: _paybill, keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.paybillLabel)),
              const SizedBox(height: JiraniSpace.s),
              Text(l.statementRouteLabel, style: text.labelLarge),
              RadioGroup<String>(
                groupValue: _route,
                onChanged: (v) => setState(() => _route = v ?? _route),
                child: Column(children: [
                  RadioListTile(value: 'bank_email', title: Text(l.routeBankEmail)),
                  RadioListTile(value: 'upload', title: Text(l.routeUpload)),
                ]),
              ),
              if (_route == 'bank_email' && chama.statementInbox != null)
                Notice(l.inboxExplain(chama.statementInbox!)),
              const SizedBox(height: JiraniSpace.m),
              PrimaryButton(label: l.saveBank, busy: _busy, onPressed: _saveBank),
            ]),
          if (founder && chama.state == ChamaState.setup)
            section(l.rulesSection, [
              TextField(controller: _amount, keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.amountLabel)),
              const SizedBox(height: JiraniSpace.s),
              TextField(controller: _dueDay, keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.dueDayLabel)),
              const SizedBox(height: JiraniSpace.s),
              TextField(controller: _grace, keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.graceLabel)),
              const SizedBox(height: JiraniSpace.s),
              TextField(controller: _fine, keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: l.lateFineLabel)),
              const SizedBox(height: JiraniSpace.m),
              PrimaryButton(label: l.saveRules, busy: _busy,
                  onPressed: () => _saveRules(l.rulesSaved)),
              const SizedBox(height: JiraniSpace.s),
              OutlinedButton.icon(icon: const Icon(Icons.tune), label: Text(l.editAllRules),
                  onPressed: _busy ? null : _editAll),
            ]),
          section(l.tabRules, [RuleBookList(widget.bundle.rules.clauses(lang))]),
          if (founder)
            section(l.inviteSection, [
              DropdownButtonFormField<String>(
                key: const ValueKey('invite-role'),
                initialValue: _inviteRole,
                decoration: InputDecoration(labelText: l.inviteRoleLabel),
                items: [
                  for (final r in ['chair', 'treasurer', 'secretary', 'member'])
                    DropdownMenuItem(value: r, child: Text(roleLabel(l, r))),
                ],
                onChanged: (v) => setState(() => _inviteRole = v ?? _inviteRole),
              ),
              const SizedBox(height: JiraniSpace.s),
              TextField(key: const ValueKey('invite-phone'), controller: _invitePhone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: l.invitePhoneLabel,
                      hintText: l.phoneHint)),
              if (_lastInvite != null) ...[
                const SizedBox(height: JiraniSpace.m),
                Notice(l.inviteCreated(_lastInvite!.code)),
              ],
              const SizedBox(height: JiraniSpace.m),
              OutlinedButton(onPressed: _busy ? null : _invite, child: Text(l.sendInvite)),
            ]),
          section(l.tabMembers, [
            for (final m in widget.bundle.members)
              ListTile(contentPadding: EdgeInsets.zero, title: Text(m.name),
                  subtitle: Text('${roleLabel(l, m.role)} · ${m.memberCode}')),
          ]),
          if (founder && chama.state == ChamaState.setup) ...[
            const SizedBox(height: JiraniSpace.m),
            Text(l.submitHelp, style: text.bodySmall),
          ],
        ],
      ),
    );
  }
}
