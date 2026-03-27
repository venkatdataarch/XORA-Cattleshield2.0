import 'package:flutter/material.dart';

/// CattleShield color palette — Starbucks-style layout, original green branding.
class AppColors {
  AppColors._();

  // ─── Primary Brand Colors (Original CattleShield Green) ──
  static const Color primary = Color(0xFF104F38);        // CattleShield Green
  static const Color primaryLight = Color(0xFF1B7A5A);   // Lighter Green
  static const Color primaryDark = Color(0xFF0A3525);    // Dark Green

  // ─── Secondary / Accent ─────────────────────────────
  static const Color secondary = Color(0xFF2ECC71);      // Bright Green Accent
  static const Color secondaryLight = Color(0xFFA3E4C1);

  // ─── Mule accent
  static const Color muleAccent = Color(0xFFFF9800);
  static const Color muleAccentLight = Color(0xFFFFB74D);

  // ─── Surface Colors (Clean, minimal) ────────────────
  static const Color background = Color(0xFFF5F7F6);     // Cool off-white
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cream = Color(0xFFF0F5F2);          // Greenish tint cream
  static const Color surfaceLight = Color(0xFFF8FAF9);
  static const Color cardBorder = Color(0xFFE0E8E4);     // Soft green border

  // ─── Status Colors ─────────────────────────────────
  static const Color success = Color(0xFF4CAF50);
  static const Color successLight = Color(0xFFE8F5E9);
  static const Color warning = Color(0xFFFF9800);
  static const Color warningLight = Color(0xFFFFF8E1);
  static const Color error = Color(0xFFF44336);
  static const Color errorLight = Color(0xFFFFEBEE);
  static const Color info = Color(0xFF2196F3);
  static const Color infoLight = Color(0xFFE3F2FD);

  // ─── Text Colors ───────────────────────────────────
  static const Color textPrimary = Color(0xFF1A1C1B);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ─── Divider ───────────────────────────────────────
  static const Color divider = Color(0xFFEEEEEE);

  // ─── Risk categories ───────────────────────────────
  static const Color riskLow = Color(0xFF4CAF50);
  static const Color riskMedium = Color(0xFFFFC107);
  static const Color riskHigh = Color(0xFFFF9800);
  static const Color riskCritical = Color(0xFFF44336);

  // ─── Gradients ─────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF104F38), Color(0xFF1B7A5A)],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF104F38),
      Color(0xFF0E4530),
      Color(0xFF0B3A28),
      Color(0xFF0A3525),
    ],
    stops: [0.0, 0.3, 0.7, 1.0],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2ECC71), Color(0xFFA3E4C1)],
  );

  // ─── Shadows ───────────────────────────────────────
  static List<BoxShadow> get softShadow => [
    BoxShadow(
      color: const Color(0xFF104F38).withValues(alpha: 0.06),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> get cardShadow => [
    BoxShadow(
      color: const Color(0xFF104F38).withValues(alpha: 0.04),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];
}
