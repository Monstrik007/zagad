enum GamePhase {
  lobby,
  bossChooseWord,
  bossPickExplainer,
  explainerWrites,
  playing,
  endGameConfirm,
  nukeBomb,
  finished,
}

enum GameMode { full, short }

extension GamePhaseLabel on GamePhase {
  String get title {
    switch (this) {
      case GamePhase.lobby:
        return 'Лобби';
      case GamePhase.bossChooseWord:
        return 'Загадка слова';
      case GamePhase.bossPickExplainer:
        return 'Выбор объясняющего';
      case GamePhase.explainerWrites:
        return 'Объяснение';
      case GamePhase.playing:
        return 'Игра';
      case GamePhase.endGameConfirm:
        return 'Подтверждение';
      case GamePhase.nukeBomb:
        return '☢️';
      case GamePhase.finished:
        return 'Итог';
    }
  }
}
