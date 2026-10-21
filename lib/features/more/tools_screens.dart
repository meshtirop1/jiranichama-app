import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_ui/jirani_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/labels.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../auth/presentation/problem_text.dart';
import '../automation/automation_repository.dart';
import '../automation/motions.dart';
import '../automation/shareout_screen.dart';
import '../chamas/data/models.dart';
import '../chamas/presentation/active_view.dart';
import '../chamas/presentation/bills_screen.dart';
import '../chamas/presentation/chama_screen.dart';
import '../chamas/presentation/fines_screen.dart';
import '../chamas/presentation/governance_screen.dart';
import '../chamas/presentation/growth_screen.dart';
import '../chamas/presentation/loans_screen.dart';
import '../chamas/presentation/mandate_screen.dart';
import '../chamas/presentation/meetings_screen.dart';
import '../chamas/presentation/records_tab.dart';
import '../chamas/presentation/support_screen.dart';
import '../chamas/presentation/vote_screen.dart';
import 'chama_screens.dart';
import 'insight_screens.dart';
import 'member_screens.dart';
import 'trust_screen.dart';
import 'verify_screen.dart';

/// Inviting someone: a code to share (with its QR, for a phone next to yours) or an SMS
/// for someone without a smartphone, who replies YES with the code.
class InviteScreen extends ConsumerStatefulWidget {
  const InviteScreen({super.key, required this.chamaId, required this.chamaName});

  final String chamaId;
  final String chamaName;

  @override
  ConsumerState<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends ConsumerState<InviteScreen> {
  final _phone = TextEditingController();
  bool _bySms = false;
  String _language = 'en';
  Invite? _invite;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _make() async {
    final l = AppLocalizations.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final inv = await ref.read(chamaRepositoryProvider).invite(widget.chamaId,
          role: 'member', phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
          bySms: _bySms, language: _language);
      setState(() => _invite = inv);
    } catch (e) {
      setState(() => _error = problemText(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final inv = _invite;
    final message = inv == null ? '' : l.invShareText(widget.chamaName, inv.code);
    return Scaffold(
      appBar: AppBar(title: Text(l.inviteMember)),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        if (inv == null) ...[
          Text(l.invIntro, style: text.bodyLarge),
          const SizedBox(height: JiraniSpace.m),
          TextField(key: const ValueKey('invite-member-phone'), controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: l.invPhoneOptional)),
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
          const SizedBox(height: JiraniSpace.m),
          PrimaryButton(key: const ValueKey('inv-make'),
              label: _bySms ? l.sendSmsInvite : l.createInviteCode, busy: _busy,
              onPressed: _make),
        ] else ...[
          if (_bySms)
            Notice(l.inviteSmsSent(inv.phoneHint.isEmpty ? _phone.text.trim() : inv.phoneHint),
                tone: NoticeTone.good),
          SurfaceCard(
            key: const ValueKey('inv-code'),
            child: Column(children: [
              Text(l.invCodeIs, style: text.bodyMedium),
              const SizedBox(height: 6),
              SelectableText(inv.code, style: text.displaySmall?.copyWith(letterSpacing: 6)),
              const SizedBox(height: JiraniSpace.s),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(data: inv.code, size: 200),
              ),
              const SizedBox(height: JiraniSpace.s),
              Text(l.invQrHint, style: text.bodySmall, textAlign: TextAlign.center),
            ]),
          ),
          const SizedBox(height: JiraniSpace.m),
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              key: const ValueKey('inv-copy'),
              icon: const Icon(Icons.copy_rounded),
              label: Text(l.cpCopy),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: message));
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text(l.copied(inv.code))));
              },
            )),
            const SizedBox(width: 8),
            Expanded(child: FilledButton.icon(
              key: const ValueKey('inv-share'),
              icon: const Icon(Icons.share_rounded),
              label: Text(l.invShare),
              onPressed: () => ref.read(textSharerProvider)(message),
            )),
          ]),
          const SizedBox(height: JiraniSpace.s),
          TextButton(onPressed: () => setState(() => _invite = null),
              child: Text(l.invAnother)),
        ],
      ]),
    );
  }
}

/// Find a member or a record in this chama: by name, member code, receipt or amount.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bundle = ref.watch(chamaBundleProvider(widget.chamaId)).value;
    final items = ref.watch(ledgerItemsProvider(widget.chamaId)).value ?? const <LedgerItem>[];
    final q = _q.trim().toLowerCase();
    final members = q.isEmpty || bundle == null ? const <Member>[] : bundle.members.where((m) =>
        m.name.toLowerCase().contains(q) || m.memberCode.toLowerCase().contains(q)).toList();
    final records = q.length < 2 ? const <LedgerItem>[] : items.reversed.where((i) =>
        i.receiptCode.toLowerCase().contains(q) ||
        (i.memberCode ?? '').toLowerCase().contains(q) ||
        entryLabelOf(l, i.type, i.decision).toLowerCase().contains(q) ||
        i.amount.format().toLowerCase().contains(q)).take(30).toList();
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const ValueKey('search-field'),
          autofocus: true,
          decoration: InputDecoration(hintText: l.searchHint, border: InputBorder.none,
              filled: false),
          onChanged: (v) => setState(() => _q = v),
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        if (q.isEmpty) Notice(l.searchIntro),
        if (q.isNotEmpty && members.isEmpty && records.isEmpty)
          SurfaceCard(child: EmptyState(icon: Icons.search_off_rounded, title: l.searchNone)),
        if (members.isNotEmpty) SectionHeader(l.tabMembers),
        for (final m in members)
          ListTile(
            key: ValueKey('search-member-${m.id}'),
            leading: Avatar(m.name, size: 38),
            title: Text(m.name),
            subtitle: Text('${m.memberCode} · ${roleLabel(l, m.role)}'),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) =>
                MemberProfileScreen(chamaId: widget.chamaId, membershipId: m.id))),
          ),
        if (records.isNotEmpty) SectionHeader(l.tabRecords),
        for (final i in records)
          ListTile(
            key: ValueKey('search-record-${i.seq}'),
            leading: flowOf(i.type) == MoneyFlow.other
                ? const Icon(Icons.receipt_long_outlined) : FlowArrow(flowOf(i.type), size: 34),
            title: Text(entryLabelOf(l, i.type, i.decision)),
            subtitle: Text([if (i.memberCode != null) i.memberCode!, l.receipt(i.receiptCode)]
                .join(' · ')),
            trailing: i.amount.cents == 0 ? null
                : MoneyText(i.amount.cents < 0 ? -i.amount : i.amount),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => RecordDetailScreen(chamaId: widget.chamaId, item: i))),
          ),
      ]),
    );
  }
}

/// Phones that pay for members (smart matching): a member sees their own, officials see
/// every one, and either can end one.
class PayerLinksScreen extends ConsumerWidget {
  const PayerLinksScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final links = ref.watch(payerLinksProvider(chamaId));
    return Scaffold(
      appBar: AppBar(title: Text(l.plTitle)),
      body: links.when(
        loading: () => const LoadingView(),
        error: (e, _) => Padding(padding: const EdgeInsets.all(JiraniSpace.m),
            child: Notice(problemText(l, e), tone: NoticeTone.critical)),
        data: (list) => ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
          Notice(l.plIntro),
          const SizedBox(height: JiraniSpace.s),
          if (list.isEmpty)
            SurfaceCard(child: EmptyState(icon: Icons.phone_android_rounded, title: l.plNone)),
          for (final x in list)
            SurfaceCard(
              key: ValueKey('pl-${x.id}'),
              margin: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                const ToneIcon(Icons.phone_android_rounded, tone: JiraniTone.info, size: 40),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(x.name, style: Theme.of(context).textTheme.titleSmall),
                  Text(switch (x.state) {
                    'confirmed' => l.plConfirmed,
                    'suggested' => l.plWaiting,
                    'declined' => l.plDeclined,
                    _ => l.plEnded,
                  }, style: Theme.of(context).textTheme.bodySmall),
                ])),
                if (x.state == 'confirmed' || x.state == 'suggested')
                  TextButton(
                    key: ValueKey('pl-end-${x.id}'),
                    onPressed: () async {
                      await ref.read(automationRepositoryProvider).endPayerLink(x.id);
                      ref.invalidate(payerLinksProvider(chamaId));
                    },
                    child: Text(l.plEnd)),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// What is coming in this chama, soonest first: my next payment, meetings, votes
/// closing, JiraniChama's bill and the next bank statement.
class WhatsComingScreen extends ConsumerWidget {
  const WhatsComingScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final pay = ref.watch(payInfoProvider(chamaId)).value;
    final meetings = ref.watch(meetingsProvider(chamaId)).value ?? const <Meeting>[];
    final votes = ref.watch(votesProvider(chamaId)).value ?? const <VoteInfo>[];
    final bills = ref.watch(billsProvider(chamaId)).value;
    final recon = ref.watch(reconciliationProvider(chamaId)).value;
    final now = DateTime.now().toIso8601String();
    final events = <({String when, IconData icon, JiraniTone tone, String title,
        String? detail, VoidCallback? onTap})>[
      if (pay != null && pay.dueOn != null && pay.total.cents > 0)
        (when: pay.dueOn!, icon: Icons.payments_outlined, tone: JiraniTone.warning,
         title: l.wcPay(pay.total.format()), detail: pay.howText, onTap: null),
      for (final m in meetings.where((m) => m.state == 'scheduled' &&
          m.startsAt.compareTo(now) > 0))
        (when: m.startsAt, icon: Icons.groups_2_outlined, tone: JiraniTone.info,
         title: l.wcMeeting(m.title), detail: m.place.isEmpty ? null : m.place,
         onTap: () => Navigator.of(context).push(MaterialPageRoute(
             builder: (_) => MeetingsScreen(chamaId: chamaId)))),
      for (final v in votes.where((v) => v.state == 'open'))
        (when: v.closesAt, icon: Icons.how_to_vote_outlined,
         tone: v.iCanVote ? JiraniTone.warning : JiraniTone.neutral,
         title: l.wcVote(v.question), detail: v.iCanVote ? l.vlYourTurn : null,
         onTap: () => Navigator.of(context).push(MaterialPageRoute(
             builder: (_) => VoteScreen(chamaId: chamaId, voteId: v.id)))),
      for (final b in ((bills?['bills'] as List?) ?? const [])
          .where((b) => (b as Map)['state'] == 'open'))
        (when: (b as Map)['due_on'] as String, icon: Icons.receipt_outlined,
         tone: JiraniTone.neutral,
         title: l.wcBill(Kes(b['total_cents'] as int).format()), detail: null, onTap: null),
      if (recon != null && recon.json['statement'] is Map &&
          (recon.json['statement'] as Map)['due_on'] != null)
        (when: (recon.json['statement'] as Map)['due_on'] as String,
         icon: Icons.description_outlined, tone: JiraniTone.info,
         title: l.wcStatement, detail: null, onTap: null),
    ]..sort((a, b) => a.when.compareTo(b.when));
    return Scaffold(
      appBar: AppBar(title: Text(l.wcTitle)),
      body: ListView(padding: const EdgeInsets.all(JiraniSpace.m), children: [
        if (events.isEmpty)
          SurfaceCard(child: EmptyState(icon: Icons.event_available_outlined, title: l.wcNone)),
        for (final e in events)
          SurfaceCard(
            margin: const EdgeInsets.only(bottom: 8),
            onTap: e.onTap,
            child: Row(children: [
              SizedBox(width: 56, child: Column(children: [
                Text(e.when.substring(8, 10), style: text.headlineSmall),
                Text(e.when.substring(5, 7) == '' ? '' : _month(e.when, context),
                    style: text.labelSmall),
              ])),
              const SizedBox(width: 8),
              ToneIcon(e.icon, tone: e.tone, size: 38),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(e.title, style: text.titleSmall),
                if (e.detail != null) Text(e.detail!, style: text.bodySmall),
              ])),
            ]),
          ),
      ]),
    );
  }

  static String _month(String iso, BuildContext context) {
    final m = int.tryParse(iso.substring(5, 7)) ?? 1;
    const en = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov',
        'Dec'];
    const sw = ['Jan', 'Feb', 'Mac', 'Apr', 'Mei', 'Jun', 'Jul', 'Ago', 'Sep', 'Okt', 'Nov',
        'Des'];
    return (Localizations.localeOf(context).languageCode == 'sw' ? sw : en)[m - 1];
  }
}

/// Everything in the chama, in one place, grouped: money, people and decisions, records
/// and trust, the chama itself.
class ChamaMenuScreen extends ConsumerWidget {
  const ChamaMenuScreen({super.key, required this.chamaId});

  final String chamaId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final bundle = ref.watch(chamaBundleProvider(chamaId)).value;
    if (bundle == null) return Scaffold(appBar: AppBar(), body: const LoadingView());
    final c = bundle.chama;
    final me = bundle.me;
    void push(Widget w) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => w));
    Widget tile(String key, IconData icon, String title, VoidCallback onTap,
            {JiraniTone tone = JiraniTone.neutral, String? subtitle}) =>
        NavTile(key: ValueKey('menu-$key'), icon: icon, tone: tone, title: title,
            subtitle: subtitle, onTap: onTap);
    return Scaffold(
      appBar: AppBar(title: Text(l.menuTitle)),
      body: ListView(key: const ValueKey('menu-list'),
          padding: const EdgeInsets.all(JiraniSpace.m), children: [
        SectionHeader(l.menuMoney),
        if (me != null) ...[
          tile('payments', Icons.receipt_long_outlined, l.payHistTitle,
              () => push(MyPaymentsScreen(chamaId: chamaId, membershipId: me.id)),
              tone: JiraniTone.good),
          tile('calendar', Icons.calendar_month_outlined, l.calTitle,
              () => push(ContributionCalendarScreen(chamaId: chamaId, membershipId: me.id)),
              tone: JiraniTone.good),
        ],
        tile('coming', Icons.event_note_outlined, l.wcTitle,
            () => push(WhatsComingScreen(chamaId: chamaId)), tone: JiraniTone.warning),
        tile('fines', Icons.gavel_rounded, l.finesTitle,
            () => push(FinesScreen(chamaId: chamaId)), tone: JiraniTone.warning),
        tile('money-out', Icons.north_east_rounded, l.moneyOut,
            () => context.push('/chamas/$chamaId/money-out')),
        tile('cash', Icons.payments_outlined, l.cashAtMeetings,
            () => context.push('/chamas/$chamaId/cash')),
        tile('shareout', Icons.savings_outlined, l.shrTitle,
            () => push(ShareOutScreen(chamaId: chamaId)), tone: JiraniTone.good),
        if (c.loansOn)
          tile('loans', Icons.handshake_outlined, l.loansTitle,
              () => push(LoansScreen(chamaId: chamaId))),
        tile('payers', Icons.phone_android_rounded, l.plTitle,
            () => push(PayerLinksScreen(chamaId: chamaId))),
        tile('bills', Icons.receipt_outlined, l.menuBills,
            () => push(BillsScreen(chama: c))),
        SectionHeader(l.menuPeople),
        tile('votes', Icons.how_to_vote_outlined, l.vlTitle,
            () => push(VotesScreen(chamaId: chamaId)), tone: JiraniTone.info),
        tile('motions', Icons.record_voice_over_outlined, l.motTitle,
            () => push(MotionsScreen(chamaId: chamaId)), tone: JiraniTone.info),
        tile('meetings', Icons.groups_2_outlined, l.meetingsTitle,
            () => push(MeetingsScreen(chamaId: chamaId)), tone: JiraniTone.info),
        tile('governance', Icons.account_tree_outlined, l.govTitle,
            () => push(GovernanceScreen(chama: c))),
        if (c.iAmOfficial)
          tile('invite', Icons.person_add_alt_1_rounded, l.inviteMember,
              () => push(InviteScreen(chamaId: chamaId, chamaName: c.name)),
              tone: JiraniTone.brand),
        SectionHeader(l.menuRecords),
        tile('search', Icons.search_rounded, l.searchTitle,
            () => push(SearchScreen(chamaId: chamaId))),
        tile('reports', Icons.insights_rounded, l.repTitle,
            () => push(ReportsScreen(chamaId: chamaId)), tone: JiraniTone.good),
        tile('bank-check', Icons.fact_check_outlined, l.bcTitle,
            () => push(BankCheckScreen(chamaId: chamaId)), tone: JiraniTone.info),
        tile('statement', Icons.summarize_outlined, l.chamaStatement,
            () => context.push('/chamas/$chamaId/statement')),
        tile('verify', Icons.qr_code_2_rounded, l.verTitle,
            () => push(VerifyScreen(chamaId: chamaId))),
        tile('trust', Icons.shield_outlined, l.trustTitle,
            () => push(TrustScreen(chamaId: chamaId)), tone: JiraniTone.good),
        if (c.iAmOfficial || c.myRole == 'auditor') ...[
          tile('statements', Icons.description_outlined, l.statements,
              () => context.push('/chamas/$chamaId/statements')),
          tile('unmatched', Icons.manage_search_rounded, l.unmatched,
              () => context.push('/chamas/$chamaId/unmatched'), tone: JiraniTone.warning),
        ],
        SectionHeader(l.menuChama),
        tile('profile', Icons.info_outline_rounded, l.cpTitle,
            () => push(ChamaProfileScreen(chamaId: chamaId))),
        tile('mandate', Icons.draw_outlined, l.mandateTitle,
            () => push(MandateScreen(chama: c))),
        tile('growth', Icons.trending_up_rounded, l.growthTitle,
            () => push(GrowthScreen(chama: c))),
        tile('support', Icons.support_agent_outlined, l.supportTitle,
            () => push(SupportScreen(chama: c))),
      ]),
    );
  }
}
