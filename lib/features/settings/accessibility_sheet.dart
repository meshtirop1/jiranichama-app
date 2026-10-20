import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jirani_ui/jirani_ui.dart';

import '../../core/prefs.dart';
import '../../l10n/app_localizations.dart';

/// The "Easy to read" button: on the home screen, the sign-in screen and inside every
/// chama, so an older member (or anyone who does not see well) can make the app readable
/// without first finding the settings.
class AccessibilityButton extends ConsumerWidget {
  const AccessibilityButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final changed = !ref.watch(a11yProvider).isDefault;
    return IconButton(
      key: const ValueKey('a11y-button'),
      tooltip: l.a11yTitle,
      icon: Badge(
        isLabelVisible: changed,
        smallSize: 8,
        child: const Icon(Icons.accessibility_new_rounded),
      ),
      onPressed: () => showAccessibilitySheet(context),
    );
  }
}

Future<void> showAccessibilitySheet(BuildContext context) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => const AccessibilitySheet(),
    );

class AccessibilitySheet extends ConsumerWidget {
  const AccessibilitySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final a = ref.watch(a11yProvider);
    final ctl = ref.read(a11yProvider.notifier);
    final text = Theme.of(context).textTheme;
    final steps = A11ySettings.textSteps;
    var at = steps.indexWhere((s) => (s - a.textScale).abs() < .01);
    if (at < 0) at = 1;

    Widget toggle(String key, IconData icon, String title, String sub, bool value,
            ValueChanged<bool> onChanged) =>
        SwitchListTile(
          key: ValueKey(key),
          secondary: Icon(icon),
          title: Text(title),
          subtitle: Text(sub),
          value: value,
          onChanged: onChanged,
        );

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .85,
      maxChildSize: .95,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(JiraniSpace.m, 0, JiraniSpace.m, JiraniSpace.xl),
        children: [
          Row(children: [
            const ToneIcon(Icons.accessibility_new_rounded, size: 44),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.a11yTitle, style: text.titleLarge),
              Text(l.a11yIntro, style: text.bodySmall),
            ])),
          ]),
          const SizedBox(height: JiraniSpace.m),
          // A live sample, so the member sees the change before leaving the sheet.
          SurfaceCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.a11ySampleTitle, style: text.titleMedium),
              const SizedBox(height: 4),
              Text(l.a11ySampleBody, style: text.bodyMedium),
            ]),
          ),
          const SizedBox(height: JiraniSpace.m),
          Text(l.a11yTextSize, style: text.titleSmall),
          const SizedBox(height: JiraniSpace.s),
          Row(children: [
            IconButton.filledTonal(
              key: const ValueKey('a11y-smaller'),
              tooltip: l.a11ySmaller,
              iconSize: 20,
              onPressed: at == 0 ? null : () => ctl.set(a.copyWith(textScale: steps[at - 1])),
              icon: const Icon(Icons.text_decrease_rounded),
            ),
            Expanded(
              child: Slider(
                key: const ValueKey('a11y-slider'),
                value: at.toDouble(),
                min: 0,
                max: (steps.length - 1).toDouble(),
                divisions: steps.length - 1,
                label: '${(steps[at] * 100).round()}%',
                onChanged: (v) => ctl.set(a.copyWith(textScale: steps[v.round()])),
              ),
            ),
            IconButton.filledTonal(
              key: const ValueKey('a11y-bigger'),
              tooltip: l.a11yBigger,
              iconSize: 28,
              onPressed: at == steps.length - 1 ? null
                  : () => ctl.set(a.copyWith(textScale: steps[at + 1])),
              icon: const Icon(Icons.text_increase_rounded),
            ),
          ]),
          Center(child: Text('${(steps[at] * 100).round()}%', style: text.labelLarge)),
          const SizedBox(height: JiraniSpace.s),
          toggle('a11y-bold', Icons.format_bold_rounded, l.a11yBold, l.a11yBoldSub, a.bold,
              (v) => ctl.set(a.copyWith(bold: v))),
          toggle('a11y-contrast', Icons.contrast_rounded, l.a11yContrast, l.a11yContrastSub,
              a.highContrast, (v) => ctl.set(a.copyWith(highContrast: v))),
          toggle('a11y-large', Icons.touch_app_outlined, l.a11yLarge, l.a11yLargeSub,
              a.largeTargets, (v) => ctl.set(a.copyWith(largeTargets: v))),
          toggle('a11y-calm', Icons.motion_photos_off_outlined, l.a11yCalm, l.a11yCalmSub,
              a.reduceMotion, (v) => ctl.set(a.copyWith(reduceMotion: v))),
          const SizedBox(height: JiraniSpace.m),
          Text(l.a11yTheme, style: text.titleSmall),
          const SizedBox(height: JiraniSpace.s),
          SegmentedButton<ThemeMode>(
            key: const ValueKey('a11y-theme'),
            segments: [
              ButtonSegment(value: ThemeMode.system, label: Text(l.a11yThemeSystem),
                  icon: const Icon(Icons.phone_android_rounded)),
              ButtonSegment(value: ThemeMode.light, label: Text(l.a11yThemeLight),
                  icon: const Icon(Icons.light_mode_outlined)),
              ButtonSegment(value: ThemeMode.dark, label: Text(l.a11yThemeDark),
                  icon: const Icon(Icons.dark_mode_outlined)),
            ],
            selected: {a.themeMode},
            onSelectionChanged: (s) => ctl.set(a.copyWith(themeMode: s.first)),
          ),
          const SizedBox(height: JiraniSpace.m),
          Notice(l.a11yReader),
          const SizedBox(height: JiraniSpace.m),
          OutlinedButton.icon(
            key: const ValueKey('a11y-reset'),
            onPressed: a.isDefault ? null : ctl.reset,
            icon: const Icon(Icons.restart_alt_rounded),
            label: Text(l.a11yReset),
          ),
          const SizedBox(height: JiraniSpace.s),
          FilledButton(onPressed: () => Navigator.of(context).pop(), child: Text(l.a11yDone)),
          SizedBox(height: MediaQuery.paddingOf(context).bottom),
        ],
      ),
    );
  }
}
