import 'package:flutter/material.dart';

abstract final class ParkColors {
  static const navy = Color(0xFF10233E);
  static const ink = Color(0xFF13243B);
  static const blue = Color(0xFF315FEA);
  static const teal = Color(0xFF17B29A);
  static const muted = Color(0xFF738197);
  static const light = Color(0xFFF5F7FB);
  static const line = Color(0xFFE8EDF4);
  static const paleBlue = Color(0xFFEAF0FF);
  static const paleGreen = Color(0xFFE8F8F2);
  static const green = Color(0xFF108D6D);
}

ThemeData parkTheme({bool dark = false}) => ThemeData(
  useMaterial3: true,
  fontFamily: 'Inter',
  brightness: dark ? Brightness.dark : Brightness.light,
  scaffoldBackgroundColor: dark ? const Color(0xFF101824) : ParkColors.light,
  colorScheme: ColorScheme.fromSeed(
    seedColor: ParkColors.blue,
    brightness: dark ? Brightness.dark : Brightness.light,
    primary: ParkColors.blue,
  ),
  textTheme: TextTheme(
    bodyMedium: TextStyle(
      color: dark ? Colors.white : ParkColors.ink,
      fontSize: 14,
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: dark ? const Color(0xFF1C293A) : ParkColors.light,
    hintStyle: const TextStyle(color: Color(0xFF9CA9BC), fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: ParkColors.line),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: ParkColors.line),
    ),
  ),
);
