import 'package:flutter/material.dart';

import '../models/game_state.dart';
import '../models/player.dart';
import '../theme/app_theme.dart';
import 'role_badge.dart';

Future<String?> showNukeTargetPickerDialog(
  BuildContext context,
  GameState state,
) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text(
        'Выберите, на кого скинуть ядерную бомбу',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: state.players.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final player = state.players[index];
            final alsoExplainer =
                state.bossIsExplainer && player.id == state.bossId;

            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: AppColors.primary.withValues(alpha: 0.25),
                child: Text(
                  player.name.isNotEmpty
                      ? player.name[0].toUpperCase()
                      : '?',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              title: Text(
                player.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    RoleBadge(
                      role: player.role,
                      compact: true,
                      alsoExplainer: alsoExplainer,
                    ),
                    if (player.role != PlayerRole.none) ...[
                      const SizedBox(width: 8),
                      Text(
                        _roleSubtitle(player, state),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              onTap: () => Navigator.pop(ctx, player.id),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Отмена'),
        ),
      ],
    ),
  );
}

String _roleSubtitle(Player player, GameState state) {
  if (state.bossIsExplainer && player.id == state.bossId) {
    return 'Босс · Объясняющий';
  }
  return player.role.pickerLabel;
}
