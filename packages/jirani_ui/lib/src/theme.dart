import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tokens.dart';

/// The JiraniChama theme: a hand-set palette (light and dark), Plus Jakarta Sans, flat
/// cards with a hairline border, soft filled fields, and pill-shaped navigation.
abstract final class JiraniTheme {
  /// [highContrast]: stronger text, borders and edges for people who do not see well.
  /// [largeTargets]: taller buttons and rows, for unsteady hands.
  static ThemeData light({bool highContrast = false, bool largeTargets = false}) =>
      _build(Brightness.light, highContrast: highContrast, largeTargets: largeTargets);
  static ThemeData dark({bool highContrast = false, bool largeTargets = false}) =>
      _build(Brightness.dark, highContrast: highContrast, largeTargets: largeTargets);

  /// The same palette pushed to full contrast: grey text becomes full text, hairlines
  /// become real borders, the page is pure white (or black).
  static ColorScheme _contrast(ColorScheme s) {
    final dark = s.brightness == Brightness.dark;
    return s.copyWith(
      primary: dark ? const Color(0xFFA6F5CD) : const Color(0xFF0A4A30),
      onSurfaceVariant: s.onSurface,
      outline: s.onSurface.withValues(alpha: .8),
      outlineVariant: s.onSurface.withValues(alpha: .55),
      surface: dark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      onSurface: dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000),
      error: dark ? const Color(0xFFFFC4BD) : const Color(0xFF8C1D18),
    );
  }

  static const _lightScheme = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF1B6B4A),
    onPrimary: Color(0xFFFFFFFF),
    primaryContainer: Color(0xFFD5EEE1),
    onPrimaryContainer: Color(0xFF0A3B26),
    secondary: Color(0xFF8F6514),
    onSecondary: Color(0xFFFFFFFF),
    secondaryContainer: Color(0xFFFBEBC9),
    onSecondaryContainer: Color(0xFF3A2800),
    tertiary: Color(0xFF2C5F8F),
    onTertiary: Color(0xFFFFFFFF),
    tertiaryContainer: Color(0xFFE2EDF8),
    onTertiaryContainer: Color(0xFF12324F),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFFFCE5E2),
    onErrorContainer: Color(0xFF5C120D),
    surface: Color(0xFFF4F7F5),
    onSurface: Color(0xFF14201A),
    onSurfaceVariant: Color(0xFF5A6A62),
    surfaceContainerLowest: Color(0xFFFFFFFF),
    surfaceContainerLow: Color(0xFFEFF4F1),
    surfaceContainer: Color(0xFFE9F0EC),
    surfaceContainerHigh: Color(0xFFE3EBE6),
    surfaceContainerHighest: Color(0xFFDCE5E0),
    outline: Color(0xFFB9C6BF),
    outlineVariant: Color(0xFFE1E8E4),
    inverseSurface: Color(0xFF243029),
    onInverseSurface: Color(0xFFEDF3EF),
    inversePrimary: Color(0xFF7FD8AB),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    surfaceTint: Color(0x00000000),
  );

  static const _darkScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF74D4A5),
    onPrimary: Color(0xFF00391F),
    primaryContainer: Color(0xFF13513A),
    onPrimaryContainer: Color(0xFFBDF1D6),
    secondary: Color(0xFFE8C27A),
    onSecondary: Color(0xFF3F2D00),
    secondaryContainer: Color(0xFF4D3804),
    onSecondaryContainer: Color(0xFFFFE0A6),
    tertiary: Color(0xFF9EC6EE),
    onTertiary: Color(0xFF0D2E4A),
    tertiaryContainer: Color(0xFF17304A),
    onTertiaryContainer: Color(0xFFD3E6FA),
    error: Color(0xFFFFB0A8),
    onError: Color(0xFF5F1410),
    errorContainer: Color(0xFF4A1612),
    onErrorContainer: Color(0xFFFFDAD5),
    surface: Color(0xFF0D1411),
    onSurface: Color(0xFFE2EAE5),
    onSurfaceVariant: Color(0xFFA2B2AA),
    surfaceContainerLowest: Color(0xFF080D0B),
    surfaceContainerLow: Color(0xFF131C17),
    surfaceContainer: Color(0xFF18221D),
    surfaceContainerHigh: Color(0xFF202B25),
    surfaceContainerHighest: Color(0xFF29352F),
    outline: Color(0xFF4A5A52),
    outlineVariant: Color(0xFF26312B),
    inverseSurface: Color(0xFFE2EAE5),
    onInverseSurface: Color(0xFF1B2520),
    inversePrimary: Color(0xFF1B6B4A),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    surfaceTint: Color(0x00000000),
  );

  static TextTheme _text(ColorScheme s) {
    TextStyle t(double size, FontWeight w, {double h = 1.3, double ls = 0, Color? c}) =>
        TextStyle(
          fontFamily: jiraniFontFamily,
          package: jiraniFontPackage,
          fontSize: size,
          fontWeight: w,
          height: h,
          letterSpacing: ls,
          color: c ?? s.onSurface,
        );
    return TextTheme(
      displayLarge: t(52, FontWeight.w800, h: 1.1, ls: -1.2),
      displayMedium: t(42, FontWeight.w800, h: 1.1, ls: -1),
      displaySmall: t(34, FontWeight.w800, h: 1.15, ls: -0.8),
      headlineLarge: t(30, FontWeight.w800, h: 1.2, ls: -0.6),
      headlineMedium: t(26, FontWeight.w800, h: 1.2, ls: -0.5),
      headlineSmall: t(22, FontWeight.w700, h: 1.25, ls: -0.3),
      titleLarge: t(19, FontWeight.w700, h: 1.3, ls: -0.2),
      titleMedium: t(16, FontWeight.w700, h: 1.35, ls: -0.1),
      titleSmall: t(14.5, FontWeight.w700, h: 1.35),
      bodyLarge: t(16, FontWeight.w500, h: 1.45),
      bodyMedium: t(14.5, FontWeight.w500, h: 1.45),
      bodySmall: t(12.5, FontWeight.w500, h: 1.4, c: s.onSurfaceVariant),
      labelLarge: t(15, FontWeight.w700, h: 1.2, ls: 0.1),
      labelMedium: t(12.5, FontWeight.w600, h: 1.2, ls: 0.1),
      labelSmall: t(11, FontWeight.w700, h: 1.2, ls: 0.6, c: s.onSurfaceVariant),
    );
  }

  static ThemeData _build(Brightness brightness,
      {bool highContrast = false, bool largeTargets = false}) {
    final dark = brightness == Brightness.dark;
    final base = dark ? _darkScheme : _lightScheme;
    final s = highContrast ? _contrast(base) : base;
    final baseStatus = dark ? JiraniStatus.dark : JiraniStatus.light;
    final status = highContrast
        ? baseStatus.copyWith(card: dark ? const Color(0xFF0B0F0D) : const Color(0xFFFFFFFF))
        : baseStatus;
    final tap = jiraniMinTapTarget + (largeTargets ? 12 : 0);
    final text = _text(s);
    final fieldRadius = BorderRadius.circular(JiraniRadius.field);
    final buttonShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JiraniRadius.button));

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: s,
      fontFamily: 'packages/$jiraniFontPackage/$jiraniFontFamily',
      textTheme: text,
      primaryTextTheme: text,
      scaffoldBackgroundColor: s.surface,
      canvasColor: s.surface,
      visualDensity: VisualDensity.standard,
      splashFactory: InkSparkle.splashFactory,
      extensions: [status],
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
      }),
      appBarTheme: AppBarTheme(
        backgroundColor: s.surface,
        foregroundColor: s.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: JiraniSpace.m,
        titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        systemOverlayStyle: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
            .copyWith(statusBarColor: Colors.transparent),
      ),
      cardTheme: CardThemeData(
        color: status.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(vertical: JiraniSpace.xs + 2),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(JiraniRadius.card),
          side: BorderSide(color: s.outlineVariant),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: JiraniSpace.m),
        minVerticalPadding: largeTargets ? 18 : 12,
        horizontalTitleGap: 14,
        iconColor: s.onSurfaceVariant,
        titleTextStyle: text.titleSmall?.copyWith(fontSize: 15),
        subtitleTextStyle: text.bodySmall,
        leadingAndTrailingTextStyle: text.labelLarge,
      ),
      dividerTheme: DividerThemeData(color: s.outlineVariant, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: status.card,
        isDense: false,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        labelStyle: text.bodyMedium?.copyWith(color: s.onSurfaceVariant),
        floatingLabelStyle: text.bodyMedium?.copyWith(color: s.primary,
            fontWeight: FontWeight.w700),
        hintStyle: text.bodyMedium?.copyWith(color: s.onSurfaceVariant.withValues(alpha: .7)),
        helperStyle: text.bodySmall,
        prefixIconColor: s.onSurfaceVariant,
        border: OutlineInputBorder(borderRadius: fieldRadius,
            borderSide: BorderSide(color: s.outlineVariant)),
        enabledBorder: OutlineInputBorder(borderRadius: fieldRadius,
            borderSide: BorderSide(color: dark ? s.outline : s.outlineVariant, width: 1.2)),
        focusedBorder: OutlineInputBorder(borderRadius: fieldRadius,
            borderSide: BorderSide(color: s.primary, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: fieldRadius,
            borderSide: BorderSide(color: s.error, width: 1.2)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: fieldRadius,
            borderSide: BorderSide(color: s.error, width: 2)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: Size.fromHeight(tap + 6),
          shape: buttonShape,
          textStyle: text.labelLarge,
          elevation: 0,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: Size(64, tap + 4),
          shape: buttonShape,
          textStyle: text.labelLarge,
          elevation: 0,
          backgroundColor: s.primaryContainer,
          foregroundColor: s.onPrimaryContainer,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: Size(64, tap + 4),
          shape: buttonShape,
          textStyle: text.labelLarge,
          foregroundColor: dark ? s.primary : s.onSurface,
          backgroundColor: status.card,
          side: BorderSide(color: dark ? s.outline : s.outline, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 20),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: Size(48, tap),
          textStyle: text.labelLarge,
          foregroundColor: s.primary,
          shape: buttonShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: Size.square(tap)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: s.primary,
        foregroundColor: s.onPrimary,
        elevation: 2,
        extendedTextStyle: text.labelLarge,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: Size(0, tap),
          textStyle: text.labelMedium?.copyWith(fontSize: 13.5),
          selectedBackgroundColor: s.primaryContainer,
          selectedForegroundColor: s.onPrimaryContainer,
          backgroundColor: status.card,
          side: BorderSide(color: s.outlineVariant, width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: s.surfaceContainer,
        selectedColor: s.primaryContainer,
        labelStyle: text.labelMedium?.copyWith(color: s.onSurface),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(JiraniRadius.chip)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: s.primary,
        unselectedLabelColor: s.onSurfaceVariant,
        labelStyle: text.labelLarge?.copyWith(fontSize: 14.5),
        unselectedLabelStyle: text.labelLarge?.copyWith(fontSize: 14.5,
            fontWeight: FontWeight.w600),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: s.outlineVariant,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: s.primary, width: 3),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: status.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: s.primaryContainer,
        indicatorShape: const StadiumBorder(),
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
            text.labelMedium?.copyWith(
              color: states.contains(WidgetState.selected) ? s.onSurface : s.onSurfaceVariant,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w800 : FontWeight.w600,
            )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? s.onPrimaryContainer : s.onSurfaceVariant,
              size: 24,
            )),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: s.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: s.outline,
        shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(JiraniRadius.sheet))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: status.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(JiraniRadius.sheet)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: s.inverseSurface,
        contentTextStyle: text.bodyMedium?.copyWith(color: s.onInverseSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: s.primary,
        linearTrackColor: s.primaryContainer,
        circularTrackColor: Colors.transparent,
        linearMinHeight: 4,
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? s.onPrimary : s.outline),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? s.primary : s.surfaceContainerHighest),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? Colors.transparent : s.outline),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: BorderSide(color: s.outline, width: 1.6),
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const Border(),
        collapsedShape: const Border(),
        iconColor: s.primary,
        collapsedIconColor: s.onSurfaceVariant,
        tilePadding: const EdgeInsets.symmetric(horizontal: JiraniSpace.m),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: status.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: text.bodyMedium,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: text.bodyMedium,
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(status.card),
          shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: s.inverseSurface,
            borderRadius: BorderRadius.circular(8)),
        textStyle: text.labelMedium?.copyWith(color: s.onInverseSurface),
      ),
    );
  }
}
