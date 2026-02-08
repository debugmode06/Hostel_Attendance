import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary gradient colors (iOS Violet/Indigo)
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryLight = Color(0xFFA29BFE);
  static const Color primaryDark = Color(0xFF5F4FB9);

  // Status colors
  static const Color success = Color(0xFF27AE60);
  static const Color success2 = Color(0xFF2ECC71);
  static const Color error = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);

  // Neutral colors
  static const Color background = Color(0xFFF6F7FB);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFF9FAFB);
  static const Color border = Color(0xFFE5E7EB);
  static const Color text = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);

  // Glassmorphism
  static Color glassDark = Colors.black.withValues(alpha: 0.2);
  static Color glassLight = Colors.white.withValues(alpha: 0.1);
}
