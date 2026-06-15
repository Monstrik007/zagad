import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../game/game_controller.dart';
import '../theme/app_theme.dart';

/// Мини-баннер: попытка переподключения к хосту.
class ConnectionStatusBanner extends StatelessWidget {
  const ConnectionStatusBanner({super.key, required this.ctrl});

  final GameController ctrl;

  @override
  Widget build(BuildContext context) {
    if (ctrl.isHost || !ctrl.isReconnecting) {
      return const SizedBox.shrink();
    }

    return Material(
      color: AppColors.accentWarm.withValues(alpha: 0.18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.accentWarm,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Попытка переподключения… (${ctrl.reconnectAttempt})',
                style: GoogleFonts.manrope(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accentWarm,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
