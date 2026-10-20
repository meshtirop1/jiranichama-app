import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// An icon on a soft tinted square: the leading mark of tiles and quick actions.
class ToneIcon extends StatelessWidget {
  const ToneIcon(this.icon, {super.key, this.tone = JiraniTone.brand, this.size = 44});

  final IconData icon;
  final JiraniTone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (strong, soft, _) =
        JiraniStatus.of(context).colors(Theme.of(context).colorScheme, tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: soft,
        borderRadius: BorderRadius.circular(size * .32),
      ),
      child: Icon(icon, size: size * .5, color: strong),
    );
  }
}

/// A plain raised surface: white (light) or lifted grey (dark), hairline border.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(JiraniSpace.m),
    this.onTap,
    this.margin = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: margin,
      child: Material(
        color: JiraniStatus.of(context).card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JiraniRadius.card),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// A small heading above a group of content, with an optional action on the right.
class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.padding});

  final String title;
  final Widget? action;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: padding ??
          const EdgeInsets.only(top: JiraniSpace.l, bottom: JiraniSpace.s, left: 4),
      child: Row(children: [
        Expanded(
          child: Text(title, style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
        ),
        ?action,
      ]),
    );
  }
}

/// A row that leads somewhere: tinted icon, title, a one-line summary, a chevron.
/// An optional [badge] (a count or a short word) draws attention to it.
class NavTile extends StatelessWidget {
  const NavTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.tone = JiraniTone.brand,
    this.badge,
    this.trailing,
    this.margin = const EdgeInsets.only(bottom: JiraniSpace.s),
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final JiraniTone tone;
  final String? badge;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SurfaceCard(
      margin: margin,
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(children: [
        ToneIcon(icon, tone: tone),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: text.titleSmall?.copyWith(fontSize: 15.5)),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: text.bodySmall),
            ],
          ]),
        ),
        if (badge != null) ...[
          const SizedBox(width: JiraniSpace.s),
          StatusPill(badge!, tone: JiraniTone.warning),
        ],
        if (trailing != null) ...[const SizedBox(width: JiraniSpace.s), trailing!],
        if (onTap != null && trailing == null)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Icon(Icons.chevron_right_rounded, color: scheme.onSurfaceVariant),
          ),
      ]),
    );
  }
}

/// A short status word on a soft pill: "Active", "Waiting", "Overdue".
class StatusPill extends StatelessWidget {
  const StatusPill(this.label, {super.key, this.tone = JiraniTone.neutral, this.icon});

  final String label;
  final JiraniTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (strong, soft, onSoft) =
        JiraniStatus.of(context).colors(Theme.of(context).colorScheme, tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: soft, borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: strong),
          const SizedBox(width: 4),
        ],
        Flexible(child: Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: tone == JiraniTone.neutral ? onSoft : strong,
                fontWeight: FontWeight.w700))),
      ]),
    );
  }
}

/// A label on the left and a value on the right, for figures inside a card.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.emphasis = false});

  final String label;
  final Widget value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        Expanded(
          child: Text(label,
              style: emphasis
                  ? text.titleSmall
                  : text.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
        DefaultTextStyle.merge(
          style: (emphasis ? text.titleMedium : text.titleSmall) ?? const TextStyle(),
          child: value,
        ),
      ]),
    );
  }
}

/// The headline card at the top of a screen: brand gradient, a label, a big figure,
/// and whatever sits under it (figures, a link).
class HeroCard extends StatelessWidget {
  const HeroCard({
    super.key,
    required this.label,
    required this.value,
    this.children = const [],
    this.trailing,
  });

  final String label;
  final Widget value;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final status = JiraniStatus.of(context);
    final text = Theme.of(context).textTheme;
    const on = Colors.white;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [status.heroStart, status.heroEnd],
        ),
        boxShadow: [
          BoxShadow(
            color: status.heroEnd.withValues(alpha: .28),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        // Soft rings in the corner: the "pot" the members gather around.
        Positioned(
          right: -40,
          top: -50,
          child: CustomPaint(size: const Size(180, 180), painter: _RingsPainter()),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: DefaultTextStyle.merge(
            style: const TextStyle(color: on),
            child: IconTheme.merge(
              data: const IconThemeData(color: on),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(
                    child: Text(label,
                        style: text.labelLarge?.copyWith(
                            color: on.withValues(alpha: .82), fontWeight: FontWeight.w600)),
                  ),
                  ?trailing,
                ]),
                const SizedBox(height: 6),
                DefaultTextStyle.merge(
                  style: text.displaySmall?.copyWith(color: on) ?? const TextStyle(),
                  child: value,
                ),
                if (children.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(height: 1, color: on.withValues(alpha: .16)),
                  const SizedBox(height: 6),
                  ...children,
                ],
              ]),
            ),
          ),
        ),
      ]),
    );
  }
}

/// A label and a figure inside a [HeroCard].
class HeroFigure extends StatelessWidget {
  const HeroFigure(this.label, this.value, {super.key, this.alert = false});

  final String label;
  final Widget value;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(children: [
        if (alert) ...[
          Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(color: Color(0xFFFFC46B), shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
        ],
        Expanded(
          child: Text(label,
              style: text.bodyMedium?.copyWith(color: Colors.white.withValues(alpha: .8))),
        ),
        DefaultTextStyle.merge(
          style: text.titleSmall?.copyWith(color: Colors.white) ?? const TextStyle(),
          child: value,
        ),
      ]),
    );
  }
}

class _RingsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..color = Colors.white.withValues(alpha: .06);
    for (var r = 30.0; r < size.width / 2 + 40; r += 32) {
      canvas.drawCircle(c, r, p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// One shortcut in a [QuickActions] grid: tinted icon above a short label.
class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = JiraniTone.brand,
    this.badge,
    this.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final JiraniTone tone;
  final String? badge;
  final Key? key;
}

/// Shortcuts laid out three (or four, on wide phones) to a row.
class QuickActions extends StatelessWidget {
  const QuickActions(this.actions, {super.key});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return LayoutBuilder(builder: (context, box) {
      final perRow = box.maxWidth >= 520 ? 4 : 3;
      const gap = 10.0;
      final w = (box.maxWidth - gap * (perRow - 1)) / perRow;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final a in actions)
            SizedBox(
              width: w,
              child: SurfaceCard(
                key: a.key,
                onTap: a.onTap,
                padding: const EdgeInsets.fromLTRB(12, 14, 10, 12),
                child: SizedBox(
                  height: 82,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      ToneIcon(a.icon, tone: a.tone, size: 38),
                      const Spacer(),
                      if (a.badge != null) StatusPill(a.badge!, tone: JiraniTone.warning),
                    ]),
                    const Spacer(),
                    Text(a.label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelMedium?.copyWith(
                            fontSize: 13, fontWeight: FontWeight.w700, height: 1.25)),
                  ]),
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// Initials on a colour picked from the name, so the same person always looks the same.
class Avatar extends StatelessWidget {
  const Avatar(this.name, {super.key, this.size = 42});

  final String name;
  final double size;

  static const _palette = [
    (Color(0xFFD5EEE1), Color(0xFF0F4A32)),
    (Color(0xFFFBEBC9), Color(0xFF6B4A06)),
    (Color(0xFFE2EDF8), Color(0xFF1C4670)),
    (Color(0xFFF6E1EA), Color(0xFF7A2148)),
    (Color(0xFFE8E4F8), Color(0xFF41307F)),
    (Color(0xFFFDE4D6), Color(0xFF8A3A0E)),
  ];

  @override
  Widget build(BuildContext context) {
    // Initials from the words that start with a letter: "Demo Chama 754" is "DC".
    var parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    final words = parts.where((p) => RegExp(r'^\p{L}', unicode: true).hasMatch(p)).toList();
    if (words.isNotEmpty) parts = words;
    final initials = parts.isEmpty
        ? '?'
        : (parts.first[0] + (parts.length > 1 ? parts[1][0] : '')).toUpperCase();
    final i = name.codeUnits.fold(0, (a, b) => (a * 31 + b) & 0x7fffffff) % _palette.length;
    var (bg, fg) = _palette[i];
    if (Theme.of(context).brightness == Brightness.dark) (bg, fg) = (fg, bg);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Text(initials,
            style: TextStyle(
                fontFamily: jiraniFontFamily,
                package: jiraniFontPackage,
                color: fg,
                fontWeight: FontWeight.w800,
                fontSize: math.max(11, size * .36))),
      ),
    );
  }
}

/// What a screen shows when there is nothing yet: an icon, a line, and what to do.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: JiraniSpace.xl, horizontal: JiraniSpace.m),
      child: Column(children: [
        ToneIcon(icon, size: 64),
        const SizedBox(height: JiraniSpace.m),
        Text(title, textAlign: TextAlign.center, style: text.titleMedium),
        if (message != null) ...[
          const SizedBox(height: 6),
          Text(message!, textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
        if (action != null) ...[const SizedBox(height: JiraniSpace.l), action!],
      ]),
    );
  }
}

/// The JiraniChama mark: members (dots) around the pot (ring), on brand green.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final status = JiraniStatus.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .3),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [status.heroStart, status.heroEnd],
        ),
      ),
      child: CustomPaint(painter: _MarkPainter()),
    );
  }
}

class _MarkPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width * .18;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = size.width * .07
          ..color = Colors.white);
    final dot = Paint()..color = const Color(0xFFF2C36B);
    for (var i = 0; i < 6; i++) {
      final a = -math.pi / 2 + i * math.pi / 3;
      canvas.drawCircle(
          c + Offset(math.cos(a), math.sin(a)) * size.width * .32, size.width * .055, dot);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A card with a heading row (an optional tinted icon, a title, a line under it and
/// something on the right), then its content: figures, a form, a list.
class TitledCard extends StatelessWidget {
  const TitledCard({
    super.key,
    required this.title,
    required this.children,
    this.icon,
    this.tone = JiraniTone.brand,
    this.subtitle,
    this.trailing,
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  final String title;
  final List<Widget> children;
  final IconData? icon;
  final JiraniTone tone;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SurfaceCard(
      margin: margin,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          if (icon != null) ...[ToneIcon(icon!, tone: tone, size: 38), const SizedBox(width: 12)],
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: text.titleMedium),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: text.bodySmall),
              ],
            ]),
          ),
          ?trailing,
        ]),
        if (children.isNotEmpty) const SizedBox(height: 10),
        ...children,
      ]),
    );
  }
}

/// A small label and figure side by side ("Arrears KES 1,000"), tinted when it matters.
class FigureChip extends StatelessWidget {
  const FigureChip(this.label, this.value, {super.key, this.tone = JiraniTone.neutral});

  final String label;
  final String value;
  final JiraniTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final (strong, soft, _) = JiraniStatus.of(context).colors(scheme, tone);
    final neutral = tone == JiraniTone.neutral;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: neutral ? scheme.surfaceContainerLow : soft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text.rich(TextSpan(children: [
        TextSpan(text: '$label ', style: text.labelMedium?.copyWith(
            color: neutral ? scheme.onSurfaceVariant : strong, fontWeight: FontWeight.w500)),
        TextSpan(text: value, style: text.labelMedium?.copyWith(
            color: neutral ? scheme.onSurface : strong, fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()])),
      ])),
    );
  }
}
