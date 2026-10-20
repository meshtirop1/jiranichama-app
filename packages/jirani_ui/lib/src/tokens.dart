import 'package:flutter/material.dart';

/// Colour tokens. The brand green was chosen by the owner on 2026-10-19 (JiraniChama has
/// its own colour, apart from JiraniSoko's orange). The palette is set by hand for light
/// and dark (not generated), so greens stay deep and money reads clearly on both.
abstract final class JiraniColors {
  static const brand = Color(0xFF1B6B4A); // JiraniChama green
  static const brandDeep = Color(0xFF0F4A32);
  static const brandBright = Color(0xFF2E8F65);
  static const brandOn = Color(0xFFFFFFFF);
  static const gold = Color(0xFFC8962E); // accent: money, highlights
  static const good = Color(0xFF1E7A3D);
  static const warning = Color(0xFFB26A00);
  static const critical = Color(0xFFB3261E);
}

/// Spacing on an 8-point grid, with a 4 for tight gaps.
abstract final class JiraniSpace {
  static const double xs = 4;
  static const double s = 8;
  static const double m = 16;
  static const double l = 24;
  static const double xl = 32;
}

abstract final class JiraniRadius {
  static const double card = 20;
  static const double field = 14;
  static const double button = 16;
  static const double chip = 10;
  static const double sheet = 28;
}

/// Minimum tap target, from the accessibility guidelines.
const double jiraniMinTapTarget = 48;

/// The font, bundled with this package (SIL Open Font License, see fonts/OFL.txt).
const String jiraniFontFamily = 'PlusJakartaSans';
const String jiraniFontPackage = 'jirani_ui';

/// How something should read: a status, a notice, an icon's tint.
enum JiraniTone { neutral, brand, good, info, warning, critical }

/// Status colours that Material's scheme does not have: good, info and warning, each
/// with a soft container and the colour to put on it. Read with `JiraniStatus.of`.
@immutable
class JiraniStatus extends ThemeExtension<JiraniStatus> {
  const JiraniStatus({
    required this.good,
    required this.goodContainer,
    required this.onGoodContainer,
    required this.info,
    required this.infoContainer,
    required this.onInfoContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.card,
    required this.heroStart,
    required this.heroEnd,
  });

  final Color good, goodContainer, onGoodContainer;
  final Color info, infoContainer, onInfoContainer;
  final Color warning, warningContainer, onWarningContainer;

  /// The raised surface of cards and fields (white in light, a lifted grey in dark).
  final Color card;

  /// The brand gradient behind headline cards.
  final Color heroStart, heroEnd;

  static const light = JiraniStatus(
    good: Color(0xFF1E7A3D),
    goodContainer: Color(0xFFDDF3E4),
    onGoodContainer: Color(0xFF0D3D1D),
    info: Color(0xFF2C5F8F),
    infoContainer: Color(0xFFE2EDF8),
    onInfoContainer: Color(0xFF12324F),
    warning: Color(0xFF9A5B00),
    warningContainer: Color(0xFFFCEFD6),
    onWarningContainer: Color(0xFF4A2B00),
    card: Color(0xFFFFFFFF),
    heroStart: Color(0xFF1B6B4A),
    heroEnd: Color(0xFF0E4A32),
  );

  static const dark = JiraniStatus(
    good: Color(0xFF7DD99A),
    goodContainer: Color(0xFF173A24),
    onGoodContainer: Color(0xFFC4F2D1),
    info: Color(0xFF9EC6EE),
    infoContainer: Color(0xFF17304A),
    onInfoContainer: Color(0xFFD3E6FA),
    warning: Color(0xFFF2C36B),
    warningContainer: Color(0xFF3D2C0C),
    onWarningContainer: Color(0xFFFFE3B0),
    card: Color(0xFF18221D),
    heroStart: Color(0xFF1D6E4C),
    heroEnd: Color(0xFF0D3B28),
  );

  static JiraniStatus of(BuildContext context) =>
      Theme.of(context).extension<JiraniStatus>() ??
      (Theme.of(context).brightness == Brightness.dark ? dark : light);

  /// The strong colour, the soft container and the colour on the container, for a tone.
  (Color, Color, Color) colors(ColorScheme scheme, JiraniTone tone) => switch (tone) {
        JiraniTone.neutral => (scheme.onSurfaceVariant, scheme.surfaceContainerHigh,
            scheme.onSurface),
        JiraniTone.brand => (scheme.primary, scheme.primaryContainer,
            scheme.onPrimaryContainer),
        JiraniTone.good => (good, goodContainer, onGoodContainer),
        JiraniTone.info => (info, infoContainer, onInfoContainer),
        JiraniTone.warning => (warning, warningContainer, onWarningContainer),
        JiraniTone.critical => (scheme.error, scheme.errorContainer,
            scheme.onErrorContainer),
      };

  @override
  JiraniStatus copyWith({Color? card}) => JiraniStatus(
        good: good, goodContainer: goodContainer, onGoodContainer: onGoodContainer,
        info: info, infoContainer: infoContainer, onInfoContainer: onInfoContainer,
        warning: warning, warningContainer: warningContainer,
        onWarningContainer: onWarningContainer, card: card ?? this.card,
        heroStart: heroStart, heroEnd: heroEnd);

  @override
  JiraniStatus lerp(JiraniStatus? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return JiraniStatus(
      good: c(good, other.good),
      goodContainer: c(goodContainer, other.goodContainer),
      onGoodContainer: c(onGoodContainer, other.onGoodContainer),
      info: c(info, other.info),
      infoContainer: c(infoContainer, other.infoContainer),
      onInfoContainer: c(onInfoContainer, other.onInfoContainer),
      warning: c(warning, other.warning),
      warningContainer: c(warningContainer, other.warningContainer),
      onWarningContainer: c(onWarningContainer, other.onWarningContainer),
      card: c(card, other.card),
      heroStart: c(heroStart, other.heroStart),
      heroEnd: c(heroEnd, other.heroEnd),
    );
  }
}
