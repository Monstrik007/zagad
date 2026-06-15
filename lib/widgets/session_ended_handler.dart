import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/game_controller.dart';
import '../theme/app_theme.dart';
import 'primary_button.dart';

/// Показывает диалог и возвращает на главный экран при завершении сессии.
class SessionEndedHandler extends StatefulWidget {
  const SessionEndedHandler({super.key, required this.child});

  final Widget child;

  @override
  State<SessionEndedHandler> createState() => _SessionEndedHandlerState();
}

class _SessionEndedHandlerState extends State<SessionEndedHandler> {
  String? _shownMessage;

  void _checkSession(BuildContext context, GameController ctrl) {
    final message = ctrl.sessionEndedMessage;
    if (message == null || message == _shownMessage) return;
    _shownMessage = message;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!context.mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Сессия завершена'),
          content: Text(message),
          actions: [
            PrimaryButton(
              label: 'На главную',
              icon: Icons.home_rounded,
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
      if (!context.mounted) return;
      ctrl.clearSessionEnded();
      Navigator.of(context).popUntil((r) => r.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<GameController>(
      builder: (context, ctrl, _) {
        _checkSession(context, ctrl);
        return widget.child;
      },
    );
  }
}
