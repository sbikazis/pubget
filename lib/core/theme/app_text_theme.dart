import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextTheme {
  AppTextTheme._();


  //  LIGHT TEXT THEME


  static TextTheme lightTextTheme = const TextTheme(

    // DISPLAY (Hero / Branding)

    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.2,
      color: AppColors.textPrimaryLight,
    ),


    // HEADLINES (Page Titles)

    headlineLarge: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      height: 1.3,
      color: AppColors.textPrimaryLight,
    ),

    headlineMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: AppColors.textPrimaryLight,
    ),


    // BODY (Messages / Content)

    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: AppColors.textPrimaryLight,
    ),

    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: AppColors.textSecondaryLight,
    ),


    // LABELS (Buttons / Small UI)

    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      height: 1.2,
      color: AppColors.textPrimaryLight,
    ),

    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.2,
      color: AppColors.textSecondaryLight,
    ),
  );


  //  DARK TEXT THEME


  static TextTheme darkTextTheme = const TextTheme(
    displayLarge: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.5,
      height: 1.2,
      color: AppColors.textPrimaryDark,
    ),

    headlineLarge: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      height: 1.3,
      color: AppColors.textPrimaryDark,
    ),

    headlineMedium: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      height: 1.3,
      color: AppColors.textPrimaryDark,
    ),

    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      height: 1.5,
      color: AppColors.textPrimaryDark,
    ),

    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 1.5,
      color: AppColors.textSecondaryDark,
    ),

    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      height: 1.2,
      color: AppColors.textPrimaryDark,
    ),

    labelMedium: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.5,
      height: 1.2,
      color: AppColors.textSecondaryDark,
    ),
  );
}