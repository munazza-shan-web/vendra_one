import 'package:flutter/material.dart';

/// Central source of truth for the VendraOne POS brand palette.
/// Update these values to change the app's branded colors consistently.
class AppColors {
  AppColors._();

  // Client-provided brand colors.
  static const royalBlue = Color(0xFF123B8B);
  static const actionBlue = Color(0xFF2563EB);
  static const softBlue = Color(0xFFEAF1FF);
  static const white = Color(0xFFFFFFFF);
  static const background = Color(0xFFF5F7FA);
  static const darkText = Color(0xFF1E293B);

  // Semantic aliases used throughout the app.
  static const navy = royalBlue;
  static const blue = actionBlue;
  static const violet = actionBlue;
  static const surface = white;
  static const text = darkText;
  static const slate = Color(0xFF64748B);
  static const border = Color(0xFFDCE5F2);
  static const success = Color(0xFF16A34A);
  static const warning = Color(0xFFF59E0B);
  static const danger = Color(0xFFDC2626);
}
