import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game/game_controller.dart';
import '../models/game_phase.dart';
import '../models/game_state.dart';
import 'nuke_target_picker_dialog.dart';

bool showsPlayerNameInAppBar(GameState state) {
  final name = state.localPlayer?.name.trim();
  if (name == null || name.isEmpty) return false;
  return switch (state.phase) {
    GamePhase.bossChooseWord => true,
    GamePhase.bossPickExplainer => true,
    GamePhase.explainerWrites => true,
    GamePhase.playing => true,
    GamePhase.endGameConfirm => true,
    _ => false,
  };
}

class EasterEggAppBarTitle extends StatefulWidget {
  const EasterEggAppBarTitle({
    super.key,
    required this.state,
    required this.fallbackTitle,
  });

  final GameState state;
  final String fallbackTitle;

  @override
  State<EasterEggAppBarTitle> createState() => _EasterEggAppBarTitleState();
}

class _EasterEggAppBarTitleState extends State<EasterEggAppBarTitle> {
  static const _requiredTaps = 7;
  static const _maxGap = Duration(milliseconds: 750);

  int _tapCount = 0;
  DateTime? _lastTapAt;

  String get _title {
    if (showsPlayerNameInAppBar(widget.state)) {
      return widget.state.localPlayer!.name.trim();
    }
    return widget.fallbackTitle;
  }

  bool get _easterEggEnabled => showsPlayerNameInAppBar(widget.state);

  void _onTap() {
    if (!_easterEggEnabled) return;

    final now = DateTime.now();
    if (_lastTapAt != null && now.difference(_lastTapAt!) > _maxGap) {
      _tapCount = 0;
    }
    _lastTapAt = now;
    _tapCount++;

    if (_tapCount < _requiredTaps) return;
    _tapCount = 0;
    _lastTapAt = null;
    _openNukePicker();
  }

  Future<void> _openNukePicker() async {
    final ctrl = context.read<GameController>();
    final targetId = await showNukeTargetPickerDialog(context, ctrl.state);
    if (!mounted || targetId == null) return;
    ctrl.dropNukeBomb(targetId);
  }

  @override
  Widget build(BuildContext context) {
    final title = Text(_title);

    if (!_easterEggEnabled) return title;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: title,
    );
  }
}
