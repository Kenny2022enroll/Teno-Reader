import 'package:flutter/material.dart';

/// HIG-inspired color tokens.
///
/// iOS/macOS flat hierarchy is expressed through layered surfaces with
/// subtle tinted backgrounds and thin, high-contrast separators.
class AppPalette {
  AppPalette._();

  // MARK: - Light

  static const Color lightBackground = Color(0xFFF2F2F7);
  static const Color lightSecondaryBackground = Color(0xFFFFFFFF);
  static const Color lightTertiaryBackground = Color(0xFFF8F8FA);

  static const Color lightLabel = Color(0xFF1C1C1E);
  static const Color lightSecondaryLabel = Color(0xFF3C3C43);
  static const Color lightTertiaryLabel = Color(0xFF606067);
  static const Color lightQuaternaryLabel = Color(0xFFAEAEB2);

  static const Color lightSeparator = Color(0xFFC6C6C8);
  static const Color lightOpaqueSeparator = Color(0xFFA0A0A5);

  static const Color lightBlue = Color(0xFF0A84FF);
  static const Color lightGreen = Color(0xFF30D158);
  static const Color lightRed = Color(0xFFFF453A);
  static const Color lightOrange = Color(0xFFFF9F0A);
  static const Color lightPurple = Color(0xFFBF5AF2);
  static const Color lightYellow = Color(0xFFFFD60A);
  static const Color lightTeal = Color(0xFF64D2FF);

  // MARK: - Dark (True Tone inspired)

  static const Color darkBackground = Color(0xFF000000);
  static const Color darkSecondaryBackground = Color(0xFF1C1C1E);
  static const Color darkTertiaryBackground = Color(0xFF2C2C2E);

  static const Color darkLabel = Color(0xFFFFFFFF);
  static const Color darkSecondaryLabel = Color(0xFFEBEBF5);
  static const Color darkTertiaryLabel = Color(0xFF8E8E93);
  static const Color darkQuaternaryLabel = Color(0xFF48484A);

  static const Color darkSeparator = Color(0xFF38383A);
  static const Color darkOpaqueSeparator = Color(0xFF545458);

  // MARK: - Reading

  static const Color sepiaBackground = Color(0xFFF4EBC8);
  static const Color sepiaText = Color(0xFF5B4636);

  static const Color pureBlack = Color(0xFF000000);
  static const Color pureWhite = Color(0xFFFFFFFF);

  // MARK: - Highlight

  static const Color highlightYellow = Color(0xFFFFF1A8);
  static const Color highlightGreen = Color(0xFFCCF5D4);
  static const Color highlightBlue = Color(0xFFC7E3FF);
  static const Color highlightPink = Color(0xFFFFD6E3);
  static const Color darkHighlightYellow = Color(0x4DFFD60A);
  static const Color darkHighlightGreen = Color(0x4D30D158);
  static const Color darkHighlightBlue = Color(0x4D0A84FF);
  static const Color darkHighlightPink = Color(0x4DFF375F);
}
