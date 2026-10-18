import 'package:flutter/material.dart';

/// Colour tokens. Placeholder values until the Figma export lands.
abstract final class JiraniColors {
  static const brand = Color(0xFF1B6B4A); // deep green
  static const brandOn = Color(0xFFFFFFFF);
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
  static const double card = 12;
  static const double field = 10;
  static const double button = 12;
}

/// Minimum tap target, from the accessibility guidelines.
const double jiraniMinTapTarget = 48;
