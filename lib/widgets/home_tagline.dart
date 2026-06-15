import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Подзаголовок на главном экране — без подчёркивания и декораций ввода.
class HomeTagline extends StatelessWidget {
  const HomeTagline({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Угадывайте слова вместе с друзьями',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(
            fontSize: 17,
            fontWeight: FontWeight.w500,
            height: 1.45,
            color: AppColors.textPrimary.withValues(alpha: 0.85),
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.wifi_rounded,
                size: 18,
                color: AppColors.accent.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 8),
              Text(
                'Локальная Wi‑Fi сеть',
                style: GoogleFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
