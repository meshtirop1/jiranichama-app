import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../core/locale.dart';
import '../../core/providers.dart';
import '../../l10n/app_localizations.dart';
import '../auth/presentation/problem_text.dart';
import '../chamas/data/models.dart';
import '../home/home_screen.dart';
import '../settings/data/account_repository.dart';

String _lang(BuildContext context) {
  final code = Localizations.localeOf(context).languageCode;
  return code == 'sw' ? 'sw' : 'en';
}

final registrationProvider = FutureProvider.autoDispose
    .family<ChamaRegistration, (String, String)>((ref, args) =>
        ref.watch(accountRepositoryProvider).registration(args.$1, args.$2));

final guideProvider = FutureProvider.autoDispose.family<RegistrationGuide, (String, String)>(
    (ref, args) => ref.watch(accountRepositoryProvider).guide(args.$1, args.$2));

/// Registering a chama with the government, made easy: the way to register in the
/// chama's country (the office, the law, the fee), the papers JiraniChama fills in from
/// what it already knows, the ones the group brings, and a checklist the officials tick
/// off together. Shown as a tab on the home screen and from a chama's overview.
class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key, this.chamaId, this.inTab = false});

  /// Open on this chama. Without it, the member's first chama (or just the guide).
  final String? chamaId;
  final bool inTab;

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  String? _chamaId;
  String? _country;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final chamas = ref.watch(chamaListProvider).value ?? const <Chama>[];
    final picked = _chamaId ?? widget.chamaId ?? (chamas.isEmpty ? null : chamas.first.id);
    final chama = chamas.where((c) => c.id == picked).firstOrNull;
    final body = chama == null
        ? _GuideOnly(country: _country ?? ref.watch(countryProvider),
            onCountry: (c) => setState(() => _country = c))
        : _ChamaRegistration(chama: chama);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.inTab,
        title: Text(l.regTitle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(JiraniSpace.m, JiraniSpace.s, JiraniSpace.m,
            JiraniSpace.xl),
        children: [
          _Hero(),
          const SizedBox(height: JiraniSpace.m),
          if (chamas.length > 1) ...[
            SizedBox(
              height: 44,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final c in chamas)
                  Padding(
                    padding: const EdgeInsets.only(right: JiraniSpace.s),
                    child: ChoiceChip(
                      key: ValueKey('reg-chama-${c.id}'),
                      label: Text(c.name),
                      selected: c.id == picked,
                      onSelected: (_) => setState(() => _chamaId = c.id),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: JiraniSpace.m),
          ],
          body,
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final status = JiraniStatus.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [status.heroStart, status.heroEnd]),
      ),
      child: Row(children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(18)),
          child: const Icon(Icons.workspace_premium_outlined, color: Colors.white, size: 30),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.regHeroTitle, style: text.titleLarge?.copyWith(color: Colors.white)),
            const SizedBox(height: 4),
            Text(l.regHeroBody, style: text.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: .88))),
          ]),
        ),
      ]),
    );
  }
}

/// No chama yet: the guide for a country the person picks, and a way to start one.
class _GuideOnly extends ConsumerStatefulWidget {
  const _GuideOnly({required this.country, required this.onCountry});

  final String country;
  final ValueChanged<String> onCountry;

  @override
  ConsumerState<_GuideOnly> createState() => _GuideOnlyState();
}

class _GuideOnlyState extends ConsumerState<_GuideOnly> {
  String? _route;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final country = widget.country;
    final onCountry = widget.onCountry;
    final guide = ref.watch(guideProvider((country, _lang(context))));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      DropdownButtonFormField<String>(
        key: const ValueKey('reg-country'),
        initialValue: country,
        decoration: InputDecoration(labelText: l.regCountry,
            prefixIcon: const Icon(Icons.public_rounded)),
        items: [
          for (final c in countries)
            DropdownMenuItem(value: c.code, child: Text('${c.flag}  ${c.name}')),
        ],
        onChanged: (c) => c == null ? null : onCountry(c),
      ),
      const SizedBox(height: JiraniSpace.m),
      Notice(l.regNoChama, tone: NoticeTone.info,
          onTap: () => context.push('/create')),
      const SizedBox(height: JiraniSpace.m),
      guide.when(
        loading: () => const Padding(padding: EdgeInsets.all(JiraniSpace.l),
            child: LoadingView()),
        error: (e, _) => Notice(problemText(l, e), tone: NoticeTone.critical),
        data: (g) => _GuideBody(guide: g, route: g.routeOf(_route ?? '').id,
            onRoute: (id) => setState(() => _route = id), state: null),
      ),
    ]);
  }
}

/// A chama's registration: progress, the way chosen, papers, steps, the certificate.
class _ChamaRegistration extends ConsumerStatefulWidget {
  const _ChamaRegistration({required this.chama});

  final Chama chama;

  @override
  ConsumerState<_ChamaRegistration> createState() => _ChamaRegistrationState();
}

class _ChamaRegistrationState extends ConsumerState<_ChamaRegistration> {
  bool _busy = false;

  Future<void> _change(Map<String, Object?> change) async {
    final l = AppLocalizations.of(context);
    final lang = _lang(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await ref.read(accountRepositoryProvider)
          .updateRegistration(widget.chama.id, change, lang);
      ref.invalidate(registrationProvider((widget.chama.id, lang)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(problemText(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final reg = ref.watch(registrationProvider((widget.chama.id, _lang(context))));
    return reg.when(
      skipLoadingOnRefresh: true,
      loading: () => const Padding(padding: EdgeInsets.all(JiraniSpace.l),
          child: LoadingView()),
      error: (e, _) => Notice(problemText(l, e), tone: NoticeTone.critical),
      data: (r) => _GuideBody(
        guide: r.guide,
        route: r.route,
        state: r,
        busy: _busy,
        chama: widget.chama,
        onRoute: r.canEdit ? (id) => _change({'route': id}) : null,
        onTick: r.canEdit ? (item, on) => _change({on ? 'tick' : 'untick': item}) : null,
        onCertificate: r.canEdit ? (no, on) => _change({'certificate_no': no,
            'registered_on': on}) : null,
      ),
    );
  }
}

class _GuideBody extends ConsumerWidget {
  const _GuideBody({
    required this.guide,
    required this.route,
    required this.state,
    required this.onRoute,
    this.onTick,
    this.onCertificate,
    this.busy = false,
    this.chama,
  });

  final RegistrationGuide guide;
  final String route;
  final ChamaRegistration? state;
  final ValueChanged<String>? onRoute;
  final void Function(String item, bool on)? onTick;
  final void Function(String number, String? on)? onCertificate;
  final bool busy;
  final Chama? chama;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final r = guide.routeOf(route);
    final ticked = state?.ticked.toSet() ?? const <String>{};
    final steps = [for (var i = 0; i < r.steps.length; i++) 'step:${r.id}:$i'];
    final total = r.papers.length + steps.length;
    final done = r.papers.where(ticked.contains).length + steps.where(ticked.contains).length;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      if (state != null) ...[
        if (state!.registered)
          Notice(key: const ValueKey('reg-done'),
              l.regRegistered(state!.registeredOn ?? '', state!.certificateNo),
              tone: NoticeTone.good)
        else
          SurfaceCard(
            key: const ValueKey('reg-progress'),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(l.regProgress(done, total), style: text.titleMedium)),
                Text('${total == 0 ? 0 : (done * 100 / total).round()}%',
                    style: text.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary)),
              ]),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(minHeight: 10,
                    backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                    value: total == 0 ? 0 : done / total),
              ),
              const SizedBox(height: 8),
              Text(state!.canEdit ? l.regProgressOfficial : l.regProgressMember,
                  style: text.bodySmall),
            ]),
          ),
        const SizedBox(height: JiraniSpace.m),
      ],
      if (!guide.detailed) ...[
        Notice(l.regShortGuide, tone: NoticeTone.warning),
        const SizedBox(height: JiraniSpace.m),
      ],
      // The ways to register here; the chosen one is open below.
      Text(l.regWays, style: text.titleMedium),
      const SizedBox(height: JiraniSpace.s),
      for (final w in guide.routes)
        Padding(
          padding: const EdgeInsets.only(bottom: JiraniSpace.s),
          child: SurfaceCard(
            key: ValueKey('reg-route-${w.id}'),
            onTap: onRoute == null || w.id == route ? null : () => onRoute!(w.id),
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Icon(w.id == route ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
                  color: w.id == route ? Theme.of(context).colorScheme.primary : null),
              const SizedBox(width: 12),
              Expanded(child: Text(w.title, style: text.titleSmall)),
            ]),
          ),
        ),
      const SizedBox(height: JiraniSpace.s),
      TitledCard(
        icon: Icons.account_balance_outlined,
        title: r.title,
        subtitle: r.who,
        children: [
          _Fact(Icons.place_outlined, l.regWhere, r.office),
          _Fact(Icons.gavel_rounded, l.regLaw, r.law),
          _Fact(Icons.payments_outlined, l.regFee, r.fee),
          _Fact(Icons.schedule_rounded, l.regTime, r.time),
          _Fact(Icons.autorenew_rounded, l.regRenew, r.renew),
        ],
      ),
      TitledCard(
        icon: Icons.folder_copy_outlined,
        title: l.regPapers,
        subtitle: l.regPapersSub,
        children: [
          for (final p in r.papers)
            _PaperRow(
              id: p,
              paper: guide.papers[p] ?? const {},
              ticked: ticked.contains(p),
              chamaId: chama?.id,
              onTick: onTick == null || busy ? null : (on) => onTick!(p, on),
            ),
        ],
      ),
      TitledCard(
        icon: Icons.checklist_rounded,
        title: l.regSteps,
        children: [
          for (var i = 0; i < r.steps.length; i++)
            _StepRow(
              n: i + 1,
              text: r.steps[i],
              ticked: ticked.contains(steps[i]),
              onTick: onTick == null || busy ? null : (on) => onTick!(steps[i], on),
            ),
        ],
      ),
      if (state != null && state!.canEdit)
        _CertificateCard(state: state!, busy: busy, onSave: onCertificate!),
      const SizedBox(height: JiraniSpace.s),
      Notice(guide.disclaimer),
    ]);
  }
}

class _Fact extends StatelessWidget {
  const _Fact(this.icon, this.label, this.value);

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: text.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 2),
            Text(value, style: text.bodyMedium),
          ]),
        ),
      ]),
    );
  }
}

/// One paper: what it is, who makes it, and (for the ones JiraniChama fills) a button
/// that makes the PDF and opens the share sheet to print or send it.
class _PaperRow extends ConsumerStatefulWidget {
  const _PaperRow({required this.id, required this.paper, required this.ticked,
      required this.chamaId, required this.onTick});

  final String id;
  final Map<String, dynamic> paper;
  final bool ticked;
  final String? chamaId;
  final ValueChanged<bool>? onTick;

  @override
  ConsumerState<_PaperRow> createState() => _PaperRowState();
}

class _PaperRowState extends ConsumerState<_PaperRow> {
  bool _busy = false;

  Future<void> _make() async {
    final l = AppLocalizations.of(context);
    final lang = _lang(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final bytes = await ref.read(accountRepositoryProvider)
          .paper(widget.chamaId!, widget.id, lang);
      final saver = ref.read(documentSaverProvider);
      final path = await saver.save('JiraniChama-${widget.id.replaceAll('_', '-')}.pdf', bytes);
      messenger.showSnackBar(SnackBar(content: Text(l.regPaperReady)));
      await saver.share(path, text: '${widget.paper['title'] ?? ''}');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(problemText(l, e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final byApp = widget.paper['made_by'] == 'app';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ToneIcon(byApp ? Icons.auto_awesome_outlined : Icons.badge_outlined,
            tone: widget.ticked ? JiraniTone.good : byApp ? JiraniTone.brand : JiraniTone.info,
            size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${widget.paper['title'] ?? widget.id}', style: text.titleSmall?.copyWith(
                decoration: widget.ticked ? TextDecoration.lineThrough : null)),
            const SizedBox(height: 2),
            Text('${widget.paper['what'] ?? ''}', style: text.bodySmall),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center,
                children: [
              StatusPill(byApp ? l.regWePrepare : l.regYouBring,
                  tone: byApp ? JiraniTone.brand : JiraniTone.info,
                  icon: byApp ? Icons.auto_awesome_rounded : Icons.back_hand_outlined),
              if (byApp && widget.chamaId != null)
                FilledButton.tonalIcon(
                  key: ValueKey('reg-make-${widget.id}'),
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(horizontal: 14)),
                  onPressed: _busy ? null : _make,
                  icon: _busy ? const SizedBox.square(dimension: 16,
                      child: BrandLoader(size: 16))
                      : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: Text(l.regMakePdf),
                ),
            ]),
          ]),
        ),
        if (widget.onTick != null || widget.ticked)
          Checkbox(
            key: ValueKey('reg-tick-${widget.id}'),
            value: widget.ticked,
            onChanged: widget.onTick == null ? null : (v) => widget.onTick!(v ?? false),
          ),
      ]),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.n, required this.text, required this.ticked,
      required this.onTick});

  final int n;
  final String text;
  final bool ticked;
  final ValueChanged<bool>? onTick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: ticked ? JiraniStatus.of(context).good : scheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: ticked
              ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
              : Text('$n', style: t.labelLarge?.copyWith(color: scheme.onPrimaryContainer)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(text, style: t.bodyMedium),
        )),
        if (onTick != null)
          Checkbox(value: ticked, onChanged: (v) => onTick!(v ?? false)),
      ]),
    );
  }
}

class _CertificateCard extends StatefulWidget {
  const _CertificateCard({required this.state, required this.busy, required this.onSave});

  final ChamaRegistration state;
  final bool busy;
  final void Function(String number, String? on) onSave;

  @override
  State<_CertificateCard> createState() => _CertificateCardState();
}

class _CertificateCardState extends State<_CertificateCard> {
  late final _no = TextEditingController(text: widget.state.certificateNo);

  @override
  void dispose() {
    _no.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return TitledCard(
      icon: Icons.verified_outlined,
      tone: JiraniTone.good,
      title: l.regCertificate,
      subtitle: l.regCertificateSub,
      children: [
        TextField(
          key: const ValueKey('reg-cert-no'),
          controller: _no,
          decoration: InputDecoration(labelText: l.regCertificateNo),
        ),
        const SizedBox(height: JiraniSpace.s),
        FilledButton(
          key: const ValueKey('reg-cert-save'),
          onPressed: widget.busy ? null : () => widget.onSave(_no.text.trim(),
              _no.text.trim().isEmpty ? null
                  : DateTime.now().toIso8601String().substring(0, 10)),
          child: Text(l.regCertificateSave),
        ),
      ],
    );
  }
}
