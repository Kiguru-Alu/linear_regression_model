import 'package:flutter/material.dart';

class Palette {
  static const canvas = Color(0xFFF5F7F4);
  static const ink = Color(0xFF0F2731);
  static const muted = Color(0xFF66767C);
  static const line = Color(0xFFDDE3DF);
  static const card = Color(0xFFFFFFFF);
  static const fieldGreen = Color(0xFF3F9A5B);
  static const harvestAmber = Color(0xFFD08A22);
  static const droughtRed = Color(0xFFC0473A);
  static const emptyBar = Color(0xFFE6EBE7);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: 'Geist',
    scaffoldBackgroundColor: Palette.canvas,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Palette.ink,
      primary: Palette.ink,
      surface: Palette.canvas,
      error: Palette.droughtRed,
    ),
  );

  OutlineInputBorder outline(Color color, [double width = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(14),
    borderSide: BorderSide(color: color, width: width),
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: Palette.ink, displayColor: Palette.ink),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Palette.card,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      hintStyle: const TextStyle(color: Color(0xFFA3AFB3), fontSize: 16),
      helperStyle: const TextStyle(color: Palette.muted, fontSize: 13),
      errorStyle: const TextStyle(color: Palette.droughtRed, fontSize: 13),
      border: outline(Palette.line),
      enabledBorder: outline(Palette.line),
      focusedBorder: outline(Palette.ink, 1.5),
      errorBorder: outline(Palette.droughtRed),
      focusedErrorBorder: outline(Palette.droughtRed, 1.5),
    ),
  );
}
