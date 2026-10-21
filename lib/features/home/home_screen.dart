import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../core/labels.dart';
import '../../core/providers.dart';
import '../../core/tours.dart';
import '../../l10n/app_localizations.dart';
import '../auth/application/session.dart';
import '../auth/presentation/problem_text.dart';
import '../chamas/data/models.dart';
import '../registration/registration_screen.dart';
import '../settings/accessibility_sheet.dart';
import '../settings/settings_screen.dart';

final chamaListProvider = FutureProvider.autoDispose<List<Chama>>(
    (ref) {
  ref.cacheFor(const Duration(minutes: 5));
  return ref.watch(chamaRepositoryProvider).list();
});

/// The app's home: three tabs at the bottom. My chamas; registering a chama with the
/// government; and settings (profile, ID check, "Easy to read").
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  /// A tab is built the first time it is opened, then kept (its scroll and loads stay).
  final _opened = <int>{0};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    const tabs = [ChamasTab(), RegistrationScreen(inTab: true), SettingsScreen()];
    return Scaffold(
      body: IndexedStack(index: _tab, children: [
        // A hidden tab keeps its place but not its animations: no loader spinning
        // off-screen, so no frames drawn for nothing (battery, Android vitals).
        for (var i = 0; i < tabs.length; i++)
          TickerMode(enabled: i == _tab,
              child: _opened.contains(i) ? tabs[i] : const SizedBox.shrink()),
      ]),
      bottomNavigationBar: NavigationBar(
        key: const ValueKey('home-nav'),
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() {
          _tab = i;
          _opened.add(i);
        }),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.groups_2_outlined),
              selectedIcon: const Icon(Icons.groups_2_rounded), label: l.tabChamas),
          NavigationDestination(icon: const Icon(Icons.workspace_premium_outlined),
              selectedIcon: const Icon(Icons.workspace_premium_rounded),
              label: l.tabRegister),
          NavigationDestination(icon: const Icon(Icons.settings_outlined),
              selectedIcon: const Icon(Icons.settings_rounded), label: l.tabSettings),
        ],
      ),
    );
  }
}

/// The member's chamas, and the way into creating or joining one.
class ChamasTab extends ConsumerStatefulWidget {
  const ChamasTab({super.key});

  @override
  ConsumerState<ChamasTab> createState() => _ChamasTabState();
}

class _ChamasTabState extends ConsumerState<ChamasTab> {
  final _chamaKey = GlobalKey();
  final _createKey = GlobalKey();
  final _joinKey = GlobalKey();

  List<TourStep> _steps() {
    final l = AppLocalizations.of(context);
    return [
      TourStep(target: _chamaKey, icon: Icons.groups_2_outlined, title: l.tourHomeChamaTitle,
          body: l.tourHomeChamaBody),
      TourStep(target: _createKey, icon: Icons.add_rounded, title: l.tourHomeCreateTitle,
          body: l.tourHomeCreateBody),
      TourStep(target: _joinKey, icon: Icons.group_add_outlined, tone: JiraniTone.info,
          title: l.tourHomeJoinTitle, body: l.tourHomeJoinBody),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final chamas = ref.watch(chamaListProvider);
    if (chamas.hasValue) showTourOnce(context, ref, 'home', _steps);
    final text = Theme.of(context).textTheme;
    Future<void> go(String path) async {
      await context.push(path);
      ref.invalidate(chamaListProvider);
    }

    return Scaffold(
      appBar: AppBar(
        titleSpacing: JiraniSpace.m,
        title: Row(children: [
          const BrandMark(size: 34),
          const SizedBox(width: 10),
          Flexible(child: Text(l.appName, overflow: TextOverflow.ellipsis)),
        ]),
        actions: [
          const AccessibilityButton(),
          TourButton(steps: _steps),
          IconButton(
            tooltip: l.signOut,
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => ref.read(sessionProvider.notifier).signOut(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(chamaListProvider.future),
        child: chamas.when(
          loading: () => const LoadingView(),
          error: (e, _) => ListView(padding: const EdgeInsets.all(JiraniSpace.l), children: [
            Notice(problemText(l, e), tone: NoticeTone.critical),
            TextButton(onPressed: () => ref.invalidate(chamaListProvider), child: Text(l.retry)),
          ]),
          data: (list) => ListView(
            padding: const EdgeInsets.fromLTRB(JiraniSpace.m, JiraniSpace.s, JiraniSpace.m,
                JiraniSpace.xl),
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: JiraniSpace.m),
                child: Text(l.homeTitle, style: text.headlineMedium),
              ),
              if (list.isEmpty)
                SurfaceCard(key: _chamaKey, child: EmptyState(icon: Icons.groups_2_outlined,
                    title: l.homeEmptyTitle, message: l.homeEmpty)),
              for (final (i, c) in list.indexed)
                KeyedSubtree(key: i == 0 ? _chamaKey : null,
                    child: _ChamaTile(chama: c, onTap: () => go('/chamas/${c.id}'))),
              const SizedBox(height: JiraniSpace.l),
              Row(children: [
                Expanded(
                  child: _StartCard(
                    key: _createKey,
                    icon: Icons.add_rounded,
                    label: l.createChama,
                    primary: true,
                    onTap: () => go('/create'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StartCard(
                    key: _joinKey,
                    icon: Icons.group_add_outlined,
                    label: l.joinChama,
                    onTap: () => go('/join'),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// One chama: its initials, name, type, my role, and its state as a pill.
class _ChamaTile extends StatelessWidget {
  const _ChamaTile({required this.chama, required this.onTap});

  final Chama chama;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final active = chama.state == ChamaState.active;
    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 10),
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Avatar(chama.name, size: 50),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(chama.name, style: text.titleMedium),
            const SizedBox(height: 3),
            Text([
              typeLabel(l, chama.type),
              if (chama.myRole != null) roleLabel(l, chama.myRole!),
            ].join(' · '), style: text.bodySmall),
            const SizedBox(height: 8),
            StatusPill(stateLabel(l, chama.state),
                tone: active ? JiraniTone.good : JiraniTone.warning,
                icon: active ? Icons.check_circle_rounded : Icons.timelapse_rounded),
          ]),
        ),
        Icon(Icons.chevron_right_rounded,
            color: Theme.of(context).colorScheme.onSurfaceVariant),
      ]),
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final fg = primary ? scheme.onPrimary : scheme.onSurface;
    return Material(
      color: primary ? scheme.primary : JiraniStatus.of(context).card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JiraniRadius.card),
        side: primary ? BorderSide.none : BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primary ? Colors.white.withValues(alpha: .18) : scheme.primaryContainer,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: primary ? fg : scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 14),
            Text(label, style: text.titleSmall?.copyWith(color: fg)),
          ]),
        ),
      ),
    );
  }
}
