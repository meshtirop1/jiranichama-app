import 'package:flutter/material.dart';
import 'package:jirani_ui/jirani_ui.dart';

/// The shared frame of the sign-in screens: a brand header (big on the first screen,
/// compact after it), a title and a line under it, then the form.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.children,
    this.subtitle,
    this.hero,
    this.actions = const [],
    this.icon = Icons.lock_outline_rounded,
  });

  final String title;
  final String? subtitle;

  /// The welcome block on the first screen (brand, name, promise). Others show [icon].
  final Widget? hero;
  final List<Widget> actions;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(actions: actions),
      body: SafeArea(
        top: false,
        // Not lazy: a short form, and every message under it must exist to be read out.
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(JiraniSpace.l, 0, JiraniSpace.l, JiraniSpace.l),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (hero != null) hero! else ...[
              const SizedBox(height: JiraniSpace.s),
              Align(alignment: Alignment.centerLeft, child: ToneIcon(icon, size: 56)),
            ],
            const SizedBox(height: JiraniSpace.l),
            Text(title, style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
            if (subtitle != null) ...[
              const SizedBox(height: JiraniSpace.s),
              Text(subtitle!, style: text.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: JiraniSpace.l),
            ...children,
          ]),
        ),
      ),
    );
  }
}

/// The welcome block: the mark, the name, and the three promises.
class AuthHero extends StatelessWidget {
  const AuthHero({super.key, required this.appName, required this.tagline});

  final String appName;
  final String tagline;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final status = JiraniStatus.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [status.heroStart, status.heroEnd],
        ),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(22),
          ),
          child: const BrandMark(size: 58),
        ),
        const SizedBox(height: JiraniSpace.l),
        Text(appName,
            style: text.headlineLarge?.copyWith(color: Colors.white, fontSize: 32)),
        const SizedBox(height: JiraniSpace.s),
        Text(tagline,
            style: text.bodyLarge?.copyWith(color: Colors.white.withValues(alpha: .85))),
      ]),
    );
  }
}
