import 'package:flutter/material.dart';

abstract final class AppColors {
  static const paper = Color(0xFFFFFBF3);
  static const ink = Color(0xFF293F39);
  static const muted = Color(0xFF637368);
  static const green = Color(0xFF467A5B);
  static const lime = Color(0xFFDAEC9C);
  static const peach = Color(0xFFF5B997);
  static const lavender = Color(0xFFE0DAF6);
  static const blue = Color(0xFFD7EBF3);
  static const yellow = Color(0xFFF8DC82);
  static const line = Color(0xFFE5E9DE);
}

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'Nunito',
  scaffoldBackgroundColor: AppColors.paper,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.green,
    surface: AppColors.paper,
  ),
  textTheme: const TextTheme(
    displaySmall: TextStyle(
      fontSize: 36,
      fontWeight: FontWeight.w900,
      height: 1.12,
      color: AppColors.ink,
    ),
    headlineLarge: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w900,
      height: 1.15,
      color: AppColors.ink,
    ),
    headlineMedium: TextStyle(
      fontSize: 25,
      fontWeight: FontWeight.w900,
      color: AppColors.ink,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w800,
      color: AppColors.ink,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: AppColors.ink,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
      height: 1.45,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
      height: 1.4,
    ),
    labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(48, 54),
      backgroundColor: AppColors.green,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
      textStyle: const TextStyle(
        fontFamily: 'Nunito',
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    ),
  ),
  iconButtonTheme: IconButtonThemeData(
    style: IconButton.styleFrom(
      minimumSize: const Size(48, 48),
      foregroundColor: AppColors.ink,
    ),
  ),
  snackBarTheme: SnackBarThemeData(
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.paper,
    foregroundColor: AppColors.ink,
    elevation: 0,
    centerTitle: true,
  ),
);
