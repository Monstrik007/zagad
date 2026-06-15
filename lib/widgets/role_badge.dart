import 'package:flutter/material.dart';

import '../models/player.dart';
import '../theme/app_theme.dart';

class RoleBadge extends StatelessWidget {
  const RoleBadge({
    super.key,
    required this.role,
    this.compact = false,
    this.alsoExplainer = false,
  });

  final PlayerRole role;
  final bool compact;
  /// Босс одновременно объясняет (короткая игра на 2 игрока).
  final bool alsoExplainer;

  @override
  Widget build(BuildContext context) {
    if (role == PlayerRole.none) return const SizedBox.shrink();

    if (alsoExplainer && role == PlayerRole.boss) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          RoleBadge(role: PlayerRole.boss, compact: compact),
          const SizedBox(width: 6),
          RoleBadge(role: PlayerRole.explainer, compact: compact),
        ],
      );
    }

    final (label, color, icon) = switch (role) {
      PlayerRole.boss => ('Босс', AppColors.boss, Icons.psychology_alt_rounded),
      PlayerRole.explainer =>
        ('Объясняет', AppColors.explainer, Icons.record_voice_over_rounded),
      PlayerRole.guesser => ('Угадывает', AppColors.guesser, Icons.search_rounded),
      PlayerRole.none => ('', Colors.grey, Icons.person),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 14 : 16, color: color),
          if (!compact) ...[
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
